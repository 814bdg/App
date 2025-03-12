//
//  SigningsOptionViewController.swift
//  feather
//
//  Created by samara on 26.10.2024.
//

import CoreData
import UIKit
import Combine

struct TogglesOption {
    let title: String
    let footer: String?
    var binding: Bool
}

enum ToggleOption: Int, CaseIterable {
    case removePlugins, forceFileSharing, removeSupportedDevices, removeURLScheme, forceProMotion, forceGameMode, forceFullScreen, forceiTunesFileSharing, forceLocalizations, removeProvisioning, removeWatchPlaceholder
    
    var keyPath: WritableKeyPath<SigningOptions, Bool> {
        switch self {
        case .removePlugins: return \.removePlugins
        case .forceFileSharing: return \.forceFileSharing
        case .removeSupportedDevices: return \.removeSupportedDevices
        case .removeURLScheme: return \.removeURLScheme
        case .forceProMotion: return \.forceProMotion
        case .forceGameMode: return \.forceGameMode
        case .forceFullScreen: return \.forceForceFullScreen
        case .forceiTunesFileSharing: return \.forceiTunesFileSharing
        case .forceLocalizations: return \.forceTryToLocalize
        case .removeProvisioning: return \.removeProvisioningFile
        case .removeWatchPlaceholder: return \.removeWatchPlaceHolder
        }
    }
    
    var localizedTitleKey: String {
        return "APP_SIGNING_INPUT_VIEW_CONTROLLER_\(self.name)"
    }
    
    private var name: String {
        switch self {
        case .removePlugins: return "REMOVE_PLUGINS"
        case .forceFileSharing: return "REMOVE_ALLOW_BROWSING_DOCUMENTS"
        // ... other cases
        }
    }
}

class SigningsOptionViewController: UITableViewController {
    
    private var application: NSManagedObject?
    private var appsViewController: LibraryViewController?
    var signingDataWrapper: SigningDataWrapper
    private lazy var toggleOptions = Self.createToggleOptions(signingDataWrapper: signingDataWrapper)
    
    private var cancellables: Set<AnyCancellable> = []
    
    init(signingDataWrapper: SigningDataWrapper, application: NSManagedObject? = nil, appsViewController: LibraryViewController? = nil) {
        self.signingDataWrapper = signingDataWrapper
        self.application = application
        self.appsViewController = appsViewController
        super.init(style: .insetGrouped)
        
        NotificationCenter.default.addObserver(self, selector: #selector(save), name: Notification.Name("saveOptions"), object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: Notification.Name("saveOptions"), object: nil)
    }
    
    @objc func save() {
        self.saveOptions()
    }
    
    func saveOptions() {
        UserDefaults.standard.signingOptions = signingDataWrapper.signingOptions
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupNavigation()
    }
    
    fileprivate func setupViews() {
        tableView.register(SigningsOptionCell.self, forCellReuseIdentifier: "SigningsOptionCell")
    }

    fileprivate func setupNavigation() {
        self.navigationItem.largeTitleDisplayMode = .never
        self.title = NSLocalizedString("APP_SIGNING_VIEW_CONTROLLER_CELL_SIGNING_OPTIONS_TITLE", comment: "Title for signing options")
    }
    
    func toggleOptionsSwitches(_ sender: UISwitch) {
        guard let option = ToggleOption(rawValue: sender.tag - 4) else { return }
        signingDataWrapper.signingOptions[keyPath: option.keyPath] = sender.isOn
        Debug.shared.log(message: "Toggle switch for \(option) set to: \(sender.isOn)")
        
        animateToggleSwitch(sender)
        
        if option == .removePlugins && !sender.isOn {
            signingDataWrapper.signingOptions.dynamicProtection = false
            updateDynamicProtectionSwitch(enabled: false, isOn: false)
        } else if option == .removePlugins && sender.isOn {
            updateDynamicProtectionSwitch(enabled: true)
        }
        
        saveOptions()
    }
    
    private func animateToggleSwitch(_ switchView: UISwitch) {
        // Scale up the switch for visual feedback
        let scaleUp = UIViewPropertyAnimator(duration: 0.15, curve: .easeInOut) {
            switchView.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        }
        
        // Scale down back to original size
        let scaleDown = UIViewPropertyAnimator(duration: 0.15, curve: .easeInOut) {
            switchView.transform = .identity
        }
        
        // Color change for the switch thumb
        let colorChange = UIViewPropertyAnimator(duration: 0.15, curve: .easeInOut) {
            switchView.thumbTintColor = switchView.isOn ? UIColor.systemGreen : UIColor.systemRed
        }
        
        // Combine animations for a more dynamic effect
        scaleUp.addCompletion { _ in
            scaleDown.startAnimation()
            colorChange.startAnimation()
        }
        
        scaleUp.startAnimation()
        
        // Add a slight bounce effect for an even more engaging feel
        let bounce = UIViewPropertyAnimator(duration: 0.1, dampingRatio: 0.5) {
            switchView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        }
        
        bounce.addCompletion { _ in
            let bounceBack = UIViewPropertyAnimator(duration: 0.1, dampingRatio: 0.5) {
                switchView.transform = .identity
            }
            bounceBack.startAnimation()
        }
        
        bounce.startAnimation(afterDelay: 0.3) // Start the bounce after the main animation completes
    }
    
    private func updateDynamicProtectionSwitch(enabled: Bool, isOn: Bool = false) {
        guard let dynamicCell = tableView.cellForRow(at: IndexPath(row: 1, section: 1)),
              let dynamicSwitch = dynamicCell.accessoryView as? UISwitch else { return }
        dynamicSwitch.isEnabled = enabled
        dynamicSwitch.isOn = isOn
        animateToggleSwitch(dynamicSwitch) // Animate this switch as well
    }
}

extension SigningsOptionViewController {
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2 + toggleOptions.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 2
        case 1: return 6
        default: return 1
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch [indexPath.section, indexPath.row] {
        case [0, 0]:
            return setupIdentifierCell(title: "SETTINGS_VIEW_CONTROLLER_CELL_CHANGE_ID")
        case [0, 1]:
            return setupIdentifierCell(title: "SETTINGS_VIEW_CONTROLLER_CELL_EXPORT_ID")
        case [1, 0], [1, 1], [1, 4], [1, 5]:
            return setupSwitchCell(for: indexPath)
        case [1, 2], [1, 3]:
            return setupDisclosureCell(for: indexPath)
        default:
            let toggleIndex = indexPath.section - 2
            guard toggleIndex >= 0 && toggleIndex < toggleOptions.count else { return UITableViewCell() }
            return setupToggleOptionCell(for: indexPath, with: toggleOptions[toggleIndex])
        }
    }
    
    private func setupIdentifierCell(title: String) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "cell")
        cell.textLabel?.text = NSLocalizedString(title, comment: "")
        cell.textLabel?.textColor = .tintColor
        cell.selectionStyle = .default
        return cell
    }
    
    private func setupSwitchCell(for indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "cell")
        let toggleSwitch = UISwitch()
        toggleSwitch.addTarget(self, action: #selector(toggleOptionsSwitches(_:)), for: .valueChanged)
        
        switch indexPath.row {
        case 0:
            cell.textLabel?.text = NSLocalizedString("APP_SIGNING_VIEW_CONTROLLER_CELL_SIGNING_OPTIONS_PROTECTIONS", comment: "")
            toggleSwitch.isOn = signingDataWrapper.signingOptions.ppqCheckProtection
            toggleSwitch.tag = 0
        case 1:
            cell.textLabel?.text = NSLocalizedString("APP_SIGNING_VIEW_CONTROLLER_CELL_SIGNING_OPTIONS_DYNAMIC_PROTECTION", comment: "")
            toggleSwitch.isOn = signingDataWrapper.signingOptions.dynamicProtection
            toggleSwitch.isEnabled = signingDataWrapper.signingOptions.ppqCheckProtection
            toggleSwitch.tag = 3
        case 4:
            cell.textLabel?.text = NSLocalizedString("APP_SIGNING_VIEW_CONTROLLER_CELL_SIGNING_OPTIONS_INSTALLAFTERSIGNED", comment: "")
            toggleSwitch.isOn = signingDataWrapper.signingOptions.installAfterSigned
            toggleSwitch.tag = 1
        case 5:
            cell.textLabel?.text = NSLocalizedString("APP_SIGNING_VIEW_CONTROLLER_CELL_SIGNING_OPTIONS_IMMEDIATELY_INSTALL_FROM_SOURCE", comment: "")
            toggleSwitch.isOn = signingDataWrapper.signingOptions.immediatelyInstallFromSource
            toggleSwitch.tag = 2
        default:
            return cell
        }
        
        cell.accessoryView = toggleSwitch
        cell.selectionStyle = .none
        return cell
    }
    
    private func setupDisclosureCell(for indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "cell")
        cell.textLabel?.text = NSLocalizedString(indexPath.row == 2 ? "APP_SIGNING_VIEW_CONTROLLER_CELL_SIGNING_OPTIONS_IDENTIFIERS" : "APP_SIGNING_VIEW_CONTROLLER_CELL_SIGNING_OPTIONS_DISPLAYNAMES", comment: "")
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    
    private func setupToggleOptionCell(for indexPath: IndexPath, with option: TogglesOption) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SigningsOptionCell", for: indexPath) as! SigningsOptionCell
        cell.configure(with: option, tag: indexPath.section + 4, isEnabled: true)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch [indexPath.section, indexPath.row] {
        case [0, 0]:
            showChangeIdentifierAlert()
        case [0, 1]:
            shareIdentifier()
        case [1, 2]:
            pushViewController(IdentifiersViewController(signingDataWrapper: signingDataWrapper, mode: .bundleId))
        case [1, 3]:
            pushViewController(IdentifiersViewController(signingDataWrapper: signingDataWrapper, mode: .displayName))
        default:
            break
        }
    }
    
    private func pushViewController(_ viewController: UIViewController) {
        navigationController?.pushViewController(viewController, animated: true)
    }
    
    private func shareIdentifier() {
        let shareText = Preferences.pPQCheckString
        let activityViewController = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        activityViewController.popoverPresentationController?.sourceView = self.view
        activityViewController.popoverPresentationController?.sourceRect = self.view.bounds
        activityViewController.popoverPresentationController?.permittedArrowDirections = []
        present(activityViewController, animated: true, completion: nil)
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 1 {
            return NSLocalizedString("APP_SIGNING_VIEW_CONTROLLER_CELL_SIGNING_OPTIONS_PROTECTIONS_DESCRIPTION", comment: "") + "\n\n" +
                   NSLocalizedString("APP_SIGNING_VIEW_CONTROLLER_CELL_SIGNING_OPTIONS_DYNAMIC_PROTECTION_DESCRIPTION", comment: "")
        } else {
            let toggleIndex = section - 2
            guard toggleIndex >= 0 && toggleIndex < toggleOptions.count else { return nil }
            return toggleOptions[toggleIndex].footer
        }
    }
}

extension SigningsOptionViewController {
    
    func showChangeIdentifierAlert() {
        let alert = UIAlertController(title: NSLocalizedString("SETTINGS_VIEW_CONTROLLER_CELL_CHANGE_IDENTIFIER", comment: ""), message: nil, preferredStyle: .alert)

        alert.addTextField { textField in
            textField.placeholder = Preferences.pPQCheckString
            textField.autocapitalizationType = .none
        }

        let setAction = UIAlertAction(title: NSLocalizedString("SET", comment: ""), style: .default) { _ in
            guard let textField = alert.textFields?.first, let enteredURL = textField.text else { return }

            if !enteredURL.isEmpty {
                Preferences.pPQCheckString = enteredURL
            }
        }

        setAction.isEnabled = true
        let cancelAction = UIAlertAction(title: NSLocalizedString("CANCEL", comment: ""), style: .cancel, handler: nil)

        alert.addAction(setAction)
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
    }
}

extension SigningsOptionViewController {
    static func createToggleOptions(signingDataWrapper: SigningDataWrapper) -> [TogglesOption] {
        return ToggleOption.allCases.map { option in
            TogglesOption(
                title: NSLocalizedString(option.localizedTitleKey, comment: ""),
                footer: NSLocalizedString(option.localizedTitleKey + "_DESCRIPTION", comment: ""),
                binding: signingDataWrapper.signingOptions[keyPath: option.keyPath]
            )
        }
    }
}

class SigningsOptionCell: UITableViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var toggleSwitch: UISwitch!
    
    func configure(with option: TogglesOption, tag: Int, isEnabled: Bool) {
        titleLabel.text = option.title
        toggleSwitch.isOn = option.binding
        toggleSwitch.tag = tag
        toggleSwitch.isEnabled = isEnabled
        toggleSwitch.addTarget(nil, action: #selector(SigningsOptionViewController().toggleOptionsSwitches(_:)), for: .valueChanged)
    }
}