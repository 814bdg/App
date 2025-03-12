//
//  Server.swift
//  feather
//
//  Created by samara on 22.08.2024.
//  Copyright © 2024 Lakr Aream. All Rights Reserved.
//  ORIGINALLY LICENSED UNDER GPL-3.0, MODIFIED FOR USE FOR FEATHER
//

import Foundation
import Vapor
import NIOSSL
import NIOTLS

struct AppData: Codable {
    public var id: String
    public var version: Int
    public var name: String
}

class Installer: Identifiable, ObservableObject {
    let id: UUID
    let app: Application
    var package: URL
    let port: Int
    let metadata: AppData
    
    enum Status {
        case ready
        case sendingManifest
        case sendingPayload
        case completed(Result<Void, Error>)
        case broken(Error)
    }
    
    @Published var status: Status = .ready
    
    var needsShutdown = false
    
    init(path packagePath: URL?, metadata: AppData) throws {
        self.id = UUID()
        self.metadata = metadata
        self.package = packagePath ?? URL(fileURLWithPath: "")
        self.port = Int.random(in: 4000...8000)
        self.app = try Self.setupApp(port: port)
        
        app.get("*") { [weak self] req -> EventLoopFuture<Response> in
            guard let self else { return req.eventLoop.makeFailedFuture(Abort(.badGateway)) }
            
            switch req.url.path {
            case "/ping":
                return req.eventLoop.makeSucceededFuture(Response(status: .ok, body: .init(string: "pong")))
            case "/", "/index.html":
                return req.eventLoop.makeSucceededFuture(Response(status: .ok, headers: [
                    "Content-Type": "text/html",
                ], body: .init(string: indexHtml)))
            case plistEndpoint.path:
                DispatchQueue.main.async { self.status = .sendingManifest }
                return req.eventLoop.makeSucceededFuture(Response(status: .ok, headers: [
                    "Content-Type": "text/xml",
                ], body: .init(data: installManifestData)))
            case displayImageSmallEndpoint.path, displayImageLargeEndpoint.path:
                DispatchQueue.main.async { self.status = .sendingManifest }
                let imageData = req.url.path == displayImageSmallEndpoint.path ? displayImageSmallData : displayImageLargeData
                return req.eventLoop.makeSucceededFuture(Response(status: .ok, headers: [
                    "Content-Type": "image/png",
                ], body: .init(data: imageData)))
            case payloadEndpoint.path:
                DispatchQueue.main.async { self.status = .sendingPayload }
                return req.fileio.asyncStreamFile(at: self.package.path).flatMap { result in
                    DispatchQueue.main.async { self.status = .completed(result) }
                    return req.eventLoop.makeSucceededFuture(Response(status: .ok))
                }
            default:
                return req.eventLoop.makeSucceededFuture(Response(status: .notFound))
            }
        }
        
        app.get("i") { req -> EventLoopFuture<Response> in
            let testurl = "itms-services://?action=download-manifest&url=" + ("\(Preferences.onlinePath ?? Preferences.defaultInstallPath)/genPlist?bundleid=\(metadata.id)&name=\(metadata.name)&version=\(metadata.name)&fetchurl=\(self.payloadEndpoint.absoluteString)".addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "")
            
            let html = """
            <script type="text/javascript">window.location="\(testurl)"</script>
            """
            
            var headers = HTTPHeaders()
            headers.add(name: .contentType, value: "text/html")
            
            return req.eventLoop.makeSucceededFuture(Response(status: .ok, headers: headers, body: .init(string: html)))
        }

        try app.server.start()
        needsShutdown = true
        Debug.shared.log(message: "Server started: Port \(port) for \(Self.sni)")
    }
    
    deinit {
        shutdownServer()
    }

    func shutdownServer() {
        Debug.shared.log(message: "Server is shutting down!")
        if needsShutdown {
            needsShutdown = false
            app.server.shutdownGracefully()
            app.shutdown()
        }
    }
}

extension Installer {
    private static let env: Environment = {
        var env = try! Environment.detect()
        try! LoggingSystem.bootstrap(from: &env)
        return env
    }()

    static func setupApp(port: Int) throws -> Application {
        let app = try Application.make(.env)

        app.threadPool = .init(numberOfThreads: 1)
        
        if !Preferences.userSelectedServer {
            app.http.server.configuration.tlsConfiguration = try Self.setupTLS()
        }
        app.http.server.configuration.hostname = Self.sni
        Debug.shared.log(message: Self.sni)
        app.http.server.configuration.tcpNoDelay = true

        app.http.server.configuration.address = .hostname("0.0.0.0", port: port)
        app.http.server.configuration.port = port

        app.routes.defaultMaxBodySize = "128mb"
        app.routes.caseInsensitive = false

        return app
    }
}	    
