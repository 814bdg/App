import SwiftUI
import UIKit

enum JSONValidationStatus {
    case notStarted
    case notValidJSON
    case validJSON
}

struct RepoViewController: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var repoName: String = ""
    @State private var validationStatus: JSONValidationStatus = .notStarted
    @State private var debounceWorkItem: DispatchWorkItem?
    @State private var isVerifying: Bool = false
    @State private var isSyncing: Bool = false
    @State var sources: [Source]?
    
    private let debounceDelay: TimeInterval = 1.2
    
    private var footerText: String {
        switch validationStatus {
        case .notStarted:
            return String.localized("SOURCES_VIEW_ADD_SOURCES_FOOTER_NOTSTARTED")
        case .notValidJSON:
            return String.localized("SOURCES_VIEW_ADD_SOURCES_FOOTER_NOTVALIDJSON")
        case .validJSON:
            return String.localized("SOURCES_VIEW_ADD_SOURCES_FOOTER_VALID")
        }
    }
    
    private var footerTextColor: Color {
        switch validationStatus {
        case .notStarted:
            return .gray
        case .notValidJSON:
            return .red
        case .validJSON:
            return .green
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                // Input Section
                Section(footer: Text(footerText).foregroundColor(footerTextColor)) {
                    RepoInputView(repoName: $repoName, onCommit: validateJSON)
                }
                
                // Action Section
                Section {
                    HStack {
                        Button(action: pasteFromClipboard) {
                            HStack {
                                Image(systemName: "doc.on.clipboard")
                                Text(String.localized("SOURCES_VIEW_ADD_SOURCES_ALERT_BUTTON_IMPORT_REPO"))
                            }
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        
                        Button(action: exportToClipboard) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text(String.localized("SOURCES_VIEW_ADD_SOURCES_ALERT_BUTTON_EXPORT_REPO"))
                            }
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                } footer: {
                    Text("Supports importing from KravaSign and ESign")
                }
                
                // Status/Add Button Section
                Section {
                    if isVerifying || isSyncing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else if validationStatus == .validJSON {
                        Button(action: addRepo) {
                            HStack {
                                Image(systemName: "plus")
                                Text(String.localized("ADD"))
                            }
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                } header: {
                    Text("Status")
                }
            }
            .navigationTitle(String.localized("SOURCES_VIEW_ADD_SOURCES_ALERT_TITLE"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !isSyncing {
                        Button(action: dismissView) {
                            Text(String.localized("DISMISS"))
                                .font(.system(size: 17, weight: .bold, design: .default))
                        }
                    }
                }
            }
        }
    }
    
    private func dismissView() {
        presentationMode.wrappedValue.dismiss()
    }
    
    private func addRepo() {
        CoreDataManager.shared.getSourceData(urlString: repoName) { error in
            if let error = error {
                Debug.shared.log(message: "SourcesViewController.sourcesAddButtonTapped: \(error)", type: .critical)
            } else {
                NotificationCenter.default.post(name: Notification.Name("sfetch"), object: nil)
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    private func pasteFromClipboard() {
        let pasteboard = UIPasteboard.general
        if let clipboardText = pasteboard.string {
            Debug.shared.log(message: "Pasted from clipboard")
            self.decodeRepositories(text: clipboardText)
        }
    }
    
    private func exportToClipboard() {
        Debug.shared.showSuccessAlert(with: String.localized("SOURCES_VIEW_ADD_SOURCES_ALERT_BUTTON_EXPORT_REPO_ACTION_SUCCESS"), subtitle: "")
        UIPasteboard.general.string = self.sources?.map{ $0.sourceURL!.absoluteString }.joined(separator: "\n")
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Helper Methods
extension RepoViewController {
    private func debounceRequest() {
        isVerifying = true
        debounceWorkItem?.cancel()
        debounceWorkItem = DispatchWorkItem { [weak self] in
            self?.validateJSON()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceDelay, execute: debounceWorkItem!)
    }
    
    private func validateJSON() {
        guard let url = URL(string: repoName), url.scheme == "https" else {
            validationStatus = .notValidJSON
            isVerifying = false
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                self?.handleValidationError("Error fetching data: \(error.localizedDescription)")
            } else if let data = data {
                do {
                    let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                    if let dict = jsonObject as? [String: Any], let identifier = dict["identifier"] as? String, !identifier.isEmpty {
                        self?.handleValidationSuccess()
                    } else {
                        self?.handleValidationError("JSON is not in expected format")
                    }
                } catch {
                    self?.handleValidationError("JSON parsing error: \(error.localizedDescription)")
                }
            }
            self?.isVerifying = false
        }
        task.resume()
    }
    
    private func handleValidationSuccess() {
        DispatchQueue.main.async { [weak self] in
            self?.validationStatus = .validJSON
        }
    }
    
    private func handleValidationError(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.validationStatus = .notValidJSON
            Debug.shared.log(message: message, type: .error)
        }
    }
}

// MARK: - Repository Decoding
extension RepoViewController {
    func decodeRepositories(text: String) {
        isSyncing = true
        let isBase64 = isValidBase64String(text)
        let repoLinks: [String]
        Debug.shared.log(message: "Trying to add repositories...")
        
        if text.hasPrefix("source[") {
            let decryptor = EsignDecryptor(input: text)
            
            guard let decodedString = decryptor.decrypt(key: esign_key, keyLength: esign_key_len) else {
                Debug.shared.log(message: "Failed to decode esign code")
                return
            }
            
            repoLinks = decodedString.split(separator: "\n").map(String.init)
        } else if isBase64 {
            guard let decodedString = decodeBase64String(text) else {
                Debug.shared.log(message: "Failed to decode base64 string")
                return
            }
            
            if decodedString.contains("[K$]") {
                repoLinks = decodedString.components(separatedBy: "[K$]")
            } else if decodedString.contains("[M$]") {
                repoLinks = decodedString.components(separatedBy: "[M$]")
            } else {
                Debug.shared.log(message: "Is this a valid Kravasign code?", type: .error)
                return
            }
        } else {
            repoLinks = text.components(separatedBy: "\n")
        }
        
        DispatchQueue(label: "import").async { [weak self] in
            var success = 0
            for str in repoLinks where str.starts(with: "http") {
                let sem = DispatchSemaphore(value: 0)
                CoreDataManager.shared.getSourceData(urlString: str) { error in
                    if error == nil {
                        success += 1
                    }
                    sem.signal()
                }
                sem.wait()
            }
            DispatchQueue.main.async {
                Debug.shared.log(message: "Successfully imported \(success) repos", type: .success)
                self?.presentationMode.wrappedValue.dismiss()
                NotificationCenter.default.post(name: Notification.Name("sfetch"), object: nil)
            }
        }
    }
    
    private func isValidBase64String(_ string: String) -> Bool {
        Data(base64Encoded: string) != nil
    }
    
    private func decodeBase64String(_ base64String: String) -> String? {
        guard let data = Data(base64Encoded: base64String) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// Custom Input View
struct RepoInputView: View {
    @Binding var repoName: String
    var onCommit: () -> Void
    
    var body: some View {
        TextField("Enter repo URL", text: $repoName, onCommit: onCommit)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .padding()
            .onChange(of: repoName) { _ in onCommit() }
    }
}