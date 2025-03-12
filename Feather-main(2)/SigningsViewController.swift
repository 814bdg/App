import UIKit
import CoreData

struct BundleOptions {
    var name: String?
    var bundleId: String?
    var version: String?
    var sourceURL: URL?
}

class SigningsViewController: UIViewController {
    
    // MARK: - Properties
    
    private var tableData: [[String]] = [
        ["AppIcon", "APPS_INFORMATION_TITLE_NAME", "APPS_INFORMATION_TITLE_IDENTIFIER", "APPS_INFORMATION_TITLE_VERSION"],
        ["Signing"],
        ["APP_SIGNING_VIEW_CONTROLLER_CELL_ADD_TWEAKS", "APP_SIGNING_VIEW_CONTROLLER_CELL_MODIFY_DYLIBS"],
        ["APP_SIGNING_VIEW_CONTROLLER_CELL_PROPERTIES"]
    ]
    
    private var sectionTitles: [String] = [
        "APP_SIGNING_VIEW_CONTROLLER_CELL_TITLE_CUSTOMIZATION",
        "APP_SIGNING_VIEW_CONTROLLER_CELL_TITLE_SIGNING",
        "APP_SIGNING_VIEW_CONTROLLER_CELL_TITLE_ADVANCED",
        ""
    ].map { String.localized($0) }
    
    private var application: NSManagedObject?
    private weak var appsViewController: LibraryViewController?
    private var signingDataWrapper: SigningDataWrapper
    private var mainOptions: SigningMainDataWrapper
    private var bundle: BundleOptions?
    
    private var tableView: UITableView!
    private var variableBlurView: UIVariableBlurView?
    private lazy var largeButton: ActivityIndicatorButton = {
        let button = ActivityIndicatorButton()
        button.addTarget(self, action: #selector(startSign), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private var iconCell = IconImageViewCell()
    var signingCompletionHandler: ((Bool) -> Void)?
    
    // MARK: - Initialization
    
    init(signingDataWrapper: SigningDataWrapper, application: NSManagedObject, appsViewController: LibraryViewController) {
        self.signingDataWrapper = signingDataWrapper
        self.application = application
        self.appsViewController = appsViewController
        self.mainOptions = SigningMainDataWrapper(mainOptions: MainSigningOptions())
        super.init(nibName: nil, bundle: nil)
        setupInitialData()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupInitialData() {
        if let app = application as? DownloadedApps {
            bundle = BundleOptions(
                name: app.name,
                bundleId: app.bundleIdentifier,
                version: app.version,
                sourceURL: URL(string: app.oSU ?? "")
            )
            
            mainOptions.mainOptions.uuid = app.uuid
            configureCertificate()
            configureDynamicProtection()
            configureBundleId()
            configureDisplayName()
        }
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigation()
        setupGestureRecognizers()
        setupNotifications()
        #if !targetEnvironment(simulator)
        certAlert()
        #endif
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: Notification.Name("reloadSigningController"), object: nil)
    }
    
    // MARK: - Setup Methods
    
    private func setupUI() {
        setupViews()
        setupToolbar()
    }
    
    private func setupNavigation() {
        navigationItem.titleView = UIImageView(image: UIImage(named: "feather_glyph"))
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: String.localized("DISMISS"), style: .done, target: self, action: #selector(closeSheet))
        navigationController?.navigationBar.prefersLargeTitles = false
        isModalInPresentation = true
    }
    
    private func setupViews() {
        tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.showsHorizontalScrollIndicator = false
        tableView.showsVerticalScrollIndicator = false
        tableView.contentInset.bottom = 70
        
        view.addSubview(tableView)
        tableView.constraintCompletely(to: view)
    }
    
    private func setupToolbar() {
        view.addSubview(largeButton)
        variableBlurView = UIVariableBlurView(frame: .zero)
        variableBlurView?.gradientMask = VariableBlurViewConstants.defaultGradientMask
        variableBlurView?.transform = CGAffineTransform(rotationAngle: CGFloat.pi)
        variableBlurView?.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(variableBlurView!)
        setupButtonAndBlurConstraints()
    }
    
    private func setupButtonAndBlurConstraints() {
        let height: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 65.0 : 80.0
        
        NSLayoutConstraint.activate([
            variableBlurView!.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            variableBlurView!.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            variableBlurView!.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            variableBlurView!.heightAnchor.constraint(equalToConstant: height),
            
            largeButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            largeButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            largeButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -17),
            largeButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        variableBlurView?.layer.zPosition = 3
        largeButton.layer.zPosition = 4
    }
    
    private func setupGestureRecognizers() {
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeLeft.direction = .left
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeRight.direction = .right
        tableView.addGestureRecognizer(swipeLeft)
        tableView.addGestureRecognizer(swipeRight)
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(fetch), name: Notification.Name("reloadSigningController"), object: nil)
    }
    
    // MARK: - Actions
    
    @objc private func closeSheet() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func fetch() {
        tableView.reloadData()
    }
    
    @objc private func startSign() {
        navigationItem.leftBarButtonItem = nil
        largeButton.showLoadingIndicator()
        performSigning()
    }
    
    private func performSigning() {
        guard let bundle = bundle else { return }
        
        signInitialApp(bundle: bundle, mainOptions: mainOptions, signingOptions: signingDataWrapper, appPath: getFilesForDownloadedApps(app: application as! DownloadedApps, getuuidonly: false)) { [weak self] result in
            self?.handleSigningResult(result)
        }
    }
    
    private func handleSigningResult(_ result: Result<(URL, DownloadedApps), Error>) {
        switch result {
        case .success(let (signedPath, signedApp)):
            appsViewController?.fetchSources()
            appsViewController?.tableView.reloadData()
            Debug.shared.log(message: signedPath.path)
            if signingDataWrapper.signingOptions.installAfterSigned {
                appsViewController?.startInstallProcess(meow: signedApp, filePath: signedPath.path)
                signingCompletionHandler?(true)
            }
        case .failure(let error):
            Debug.shared.log(message: "Signing failed: \(error.localizedDescription)", type: .error)
            signingCompletionHandler?(false)
        }
        dismiss(animated: true)
    }
    
    // MARK: - Helper Methods
    
    private func configureCertificate() {
        if let cert = CoreDataManager.shared.getCurrentCertificate() {
            mainOptions.mainOptions.certificate = cert
        }
    }
    
    private func configureDynamicProtection() {
        Task {
            await checkDynamicProtection()
        }
    }
    
    private func checkDynamicProtection() async {
        guard signingDataWrapper.signingOptions.ppqCheckProtection,
              mainOptions.mainOptions.certificate?.certData?.pPQCheck == true,
              let bundleId = bundle?.bundleId else {
            return
        }
        
        let shouldModify = await BundleIdChecker.shouldModifyBundleId(originalBundleId: bundleId)
        if shouldModify {
            mainOptions.mainOptions.bundleId = bundleId + "." + Preferences.pPQCheckString
        }
    }
    
    private func configureBundleId() {
        if let currentBundleId = bundle?.bundleId, let newBundleId = signingDataWrapper.signingOptions.bundleIdConfig[currentBundleId] {
            mainOptions.mainOptions.bundleId = newBundleId
        }
    }
    
    private func configureDisplayName() {
        if let currentName = bundle?.name, let newName = signingDataWrapper.signingOptions.displayNameConfig[currentName] {
            mainOptions.mainOptions.name = newName
        }
    }
    
    private func certAlert() {
        guard mainOptions.mainOptions.certificate == nil else { return }
        let alert = UIAlertController(title: String.localized("APP_SIGNING_VIEW_CONTROLLER_NO_CERTS_ALERT_TITLE"), message: String.localized("APP_SIGNING_VIEW_CONTROLLER_NO_CERTS_ALERT_DESCRIPTION"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String.localized("LAME"), style: .default) { _ in
            self.dismiss(animated: true)
        })
        present(alert, animated: true)
    }
    
    @objc private func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        let location = gesture.location(in: tableView)
        if let indexPath = tableView.indexPathForRow(at: location), indexPath.section == 1, indexPath.row == 0 {
            let certificates = CoreDataManager.shared.getDatedCertificate()
            guard certificates.count > 1 else { return }
            
            let currentIndex = certificates.firstIndex { $0 == mainOptions.mainOptions.certificate } ?? 0
            let newIndex = gesture.direction == .left ? (currentIndex + 1) % certificates.count : (currentIndex - 1 + certificates.count) % certificates.count
            
            UISelectionFeedbackGenerator().selectionChanged()
            
            Preferences.selectedCert = newIndex
            mainOptions.mainOptions.certificate = certificates[newIndex]
            tableView.reloadRows(at: [indexPath], with: gesture.direction == .left ? .left : .right)
        }
    }
    
    // MARK: - UITableViewDataSource & UITableViewDelegate
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }
}

extension SigningsViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return sectionTitles.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableData[section].count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sectionTitles[section]
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return sectionTitles[section].isEmpty ? 0 : 40
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return InsetGroupedSectionHeader(title: sectionTitles[section])
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellText = tableData[indexPath.section][indexPath.row]
        switch cellText {
        case "AppIcon":
            let cell = iconCell
            if let iconURL = mainOptions.mainOptions.iconURL {
                cell.configure(with: iconURL)
            } else if let url = getIconURL(for: application as! DownloadedApps) {
                cell.configure(with: CoreDataManager.shared.loadImage(from: url))
            }
            cell.accessoryType = .disclosureIndicator
            return cell
        case String.localized("APPS_INFORMATION_TITLE_NAME"):
            return configureDetailCell(cellText, detail: mainOptions.mainOptions.name ?? bundle?.name)
        case String.localized("APPS_INFORMATION_TITLE_IDENTIFIER"):
            return configureDetailCell(cellText, detail: mainOptions.mainOptions.bundleId ?? bundle?.bundleId)
        case String.localized("APPS_INFORMATION_TITLE_VERSION"):
            return configureDetailCell(cellText, detail: mainOptions.mainOptions.version ?? bundle?.version)
        case "Signing":
            if let cert = mainOptions.mainOptions.certificate {
                let cell = CertificateViewTableViewCell()
                cell.configure(with: cert, isSelected: false)
                cell.selectionStyle = .none
                return cell
            } else {
                return configureNoCertCell()
            }
        default:
            let cell = UITableViewCell(style: .value1, reuseIdentifier: "Cell")
            cell.textLabel?.text = cellText
            cell.accessoryType = .disclosureIndicator
            return cell
        }
    }
    
    private func configureDetailCell(_ title: String, detail: String?) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: "Cell")
        cell.textLabel?.text = String.localized(title)
        cell.detailTextLabel?.text = detail
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    
    private func configureNoCertCell() -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "NoCert")
        cell.textLabel?.text = String.localized("SETTINGS_VIEW_CONTROLLER_CELL_CURRENT_CERTIFICATE_NOSELECTED")
        cell.textLabel?.textColor = .secondaryLabel
        cell.selectionStyle = .none
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = tableData[indexPath.section][indexPath.row]
        handleItemSelection(item)
    }
    
    private func handleItemSelection(_ item: String) {
        switch item {
        case "AppIcon":
            importAppIconFile()
        case String.localized("APPS_INFORMATION_TITLE_NAME"):
            pushToEditView(initialValue: mainOptions.mainOptions.name ?? bundle?.name ?? "", for: .name)
        case String.localized("APPS_INFORMATION_TITLE_IDENTIFIER"):
            pushToEditView(initialValue: mainOptions.mainOptions.bundleId ?? bundle?.bundleId ?? "", for: .bundleId)
        case String.localized("APPS_INFORMATION_TITLE_VERSION"):
            pushToEditView(initialValue: mainOptions.mainOptions.version ?? bundle?.version ?? "", for: .version)
        case String.localized("APP_SIGNING_VIEW_CONTROLLER_CELL_ADD_TWEAKS"):
            navigationController?.pushViewController(SigningsTweakViewController(signingDataWrapper: signingDataWrapper), animated: true)
        case String.localized("APP_SIGNING_VIEW_CONTROLLER_CELL_MODIFY_DYLIBS"):
            if let appPath = getFilesForDownloadedApps(app: application as! DownloadedApps, getuuidonly: false) {
                navigationController?.pushViewController(SigningsDylibViewController(mainOptions: mainOptions, app: appPath), animated: true)
            }
        case String.localized("APP_SIGNING_VIEW_CONTROLLER_CELL_PROPERTIES"):
            navigationController?.pushViewController(SigningsAdvancedViewController(signingDataWrapper: signingDataWrapper, mainOptions: mainOptions), animated: true)
        default:
            break
        }
    }
    
    private func pushToEditView(initialValue: String, for type: SigningInputType) {
        let editVC = SigningsInputViewController(parentView: self, initialValue: initialValue, valueToSaveTo: type.rawValue)
        navigationController?.pushViewController(editVC, animated: true)
    }
    
    // MARK: - Helper Extensions
    
    private func getFilesForDownloadedApps(app: DownloadedApps, getuuidonly: Bool) -> URL {
        return CoreDataManager.shared.getFilesForDownloadedApps(for: app, getuuidonly: getuuidonly)
    }
    
    private func getIconURL(for app: DownloadedApps) -> URL? {
        guard let iconURLString = app.iconURL, let iconURL = URL(string: iconURLString) else { return nil }
        let filesURL = getFilesForDownloadedApps(app: app, getuuidonly: false)
        return filesURL.appendingPathComponent(iconURL.lastPathComponent)
    }
    
    private func importAppIconFile() {
        // Implement logic to import app icon file
    }
}

// MARK: - Enums

enum SigningInputType: Int {
    case name = 0, bundleId, version
}

// MARK: - Custom Classes or Structs

class ActivityIndicatorButton: UIButton {
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupActivityIndicator()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupActivityIndicator()
    }
    
    private func setupActivityIndicator() {
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        addSubview(activityIndicator)
        
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    func showLoadingIndicator() {
        activityIndicator.startAnimating()
        isEnabled = false
    }
    
    func hideLoadingIndicator() {
        activityIndicator.stopAnimating()
        isEnabled = true
    }
}