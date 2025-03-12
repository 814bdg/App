//
//  TabbarController.swift
//  feather
//
//  Created by samara on 5/17/24.
//  Copyright (c) 2024 Samara M (khcrysalis)
//

import SwiftUI

struct TabbarView: View {
    @State private var selectedTab: Tab = {
        guard let storedValue = UserDefaults.standard.string(forKey: "selectedTab"),
              let tab = Tab(rawValue: storedValue) else {
            return .sources // Fallback to a default tab if invalid or not found
        }
        return tab
    }()
    
    // Enum defining the tabs with associated data
    enum Tab: String, CaseIterable {
        case sources
        case library
        case settings
        
        var title: String {
            switch self {
            case .sources: return String.localized("TAB_SOURCES")
            case .library: return String.localized("TAB_LIBRARY")
            case .settings: return String.localized("TAB_SETTINGS")
            }
        }
        
        var systemImage: String {
            switch self {
            case .sources:
                if #available(iOS 16.0, *) {
                    return "globe.desk.fill"
                } else {
                    return "books.vertical.fill"
                }
            case .library: return "square.grid.2x2.fill"
            case .settings: return "gearshape.2.fill"
            }
        }
        
        var viewControllerType: UIViewController.Type {
            switch self {
            case .sources: return SourcesViewController.self
            case .library: return LibraryViewController.self
            case .settings: return SettingsViewController.self
            }
        }
        
        var accessibilityHint: String {
            switch self {
            case .sources: return String.localized("TAB_SOURCES_HINT")
            case .library: return String.localized("TAB_LIBRARY_HINT")
            case .settings: return String.localized("TAB_SETTINGS_HINT")
            }
        }
        
        // Example badge logic (adjust as needed)
        var badgeCount: Int {
            switch self {
            case .library: return 3 // Example: 3 updates in library
            default: return 0
            }
        }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(Tab.allCases, id: \.rawValue) { tab in
                NavigationViewController(tab.viewControllerType, title: tab.title)
                    .edgesIgnoringSafeArea(.all)
                    .tabItem {
                        Label(
                            title: { Text(tab.title) },
                            icon: { Image(systemName: tab.systemImage) }
                        )
                        .accessibilityLabel(tab.title)
                        .accessibilityHint(tab.accessibilityHint)
                    }
                    .badge(tab.badgeCount) // Badge support
                    .tag(tab)
            }
        }
        .onChange(of: selectedTab) { newTab in
            UserDefaults.standard.set(newTab.rawValue, forKey: "selectedTab")
        }
        .accentColor(.systemBlue) // Custom tint color for tab bar
        .tabViewStyle(DefaultTabViewStyle())
        .background(Color(.systemBackground)) // Custom background for tab bar
    }
}

struct NavigationViewController<Content: UIViewController>: UIViewControllerRepresentable {
    let content: Content.Type
    let title: String
    
    init(_ content: Content.Type, title: String) {
        self.content = content
        self.title = title
    }
    
    func makeUIViewController(context: Context) -> UINavigationController {
        let viewController = content.init()
        viewController.navigationItem.title = title
        viewController.navigationController?.navigationBar.prefersLargeTitles = true
        
        let navigationController = UINavigationController(rootViewController: viewController)
        // Customize navigation bar appearance if needed
        navigationController.navigationBar.tintColor = .systemBlue
        return navigationController
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // Optimize to avoid unnecessary updates
        if uiViewController.topViewController?.navigationItem.title != title {
            uiViewController.topViewController?.navigationItem.title = title
        }
    }
}

// Preview for SwiftUI
struct TabbarView_Previews: PreviewProvider {
    static var previews: some View {
        TabbarView()
            .preferredColorScheme(.light) // Preview in light mode
    }
}

// Placeholder UIViewController subclasses for compilation
class SourcesViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }
}

class LibraryViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }
}

class SettingsViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }
}