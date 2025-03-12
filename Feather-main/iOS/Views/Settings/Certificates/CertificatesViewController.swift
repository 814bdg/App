//
//  CertificatesViewController.swift
//  feather
//
//  Created by samara on 7/7/24.
//  Copyright (c) 2024 Samara M (khcrysalis)
//

import UIKit
import CoreData

class CertificatesViewController: UITableViewController {
    
    var certs: [Certificate]?
    
    enum Section: Int, CaseIterable {
        case addCertificate, certificates
    }
    
    private lazy var addCertAction: UIAction = {
        UIAction(title: String.localized("ADD_CERTIFICATE"), image: UIImage(systemName: "plus")) { [weak self] _ in
            self?.addCert()
        }
    }()
    
    init() { super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupRefreshControl()
        NotificationCenter.default.addObserver(self, selector: #selector(afetch), name: Notification.Name("cfetch"), object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupNavigation()
        fetchSources()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: Notification.Name("cfetch"), object: nil)
    }
    
    private func setupViews() {
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.tableHeaderView = UIView()
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        self.tableView.register(CertificateViewTableViewCell.self, forCellReuseIdentifier: "CertificateCell")
        self.tableView.register(CertificateViewAddTableViewCell.self, forCellReuseIdentifier: "AddCell")
    }
    
    private func setupNavigation() {
        self.title = String.localized("CERTIFICATES_VIEW_CONTROLLER_TITLE")
        self.navigationController?.navigationBar.prefersLargeTitles = false
    }
    
    private func setupRefreshControl() {
        self.tableView.refreshControl = UIRefreshControl()
        self.tableView.refreshControl?.addTarget(self, action: #selector(refreshTable), for: .valueChanged)
    }
    
    @objc private func refreshTable() {
        fetchSources()
        self.tableView.refreshControl?.endRefreshing()
    }
    
    @objc private func addCert() {
        let viewController = CertImportingViewController()
        let navigationController = UINavigationController(rootViewController: viewController)
        
        if #available(iOS 15.0, *) {
            if let presentationController = navigationController.presentationController as? UISheetPresentationController {
                presentationController.detents = [.medium(), .large()]
            }
        }
        
        self.present(navigationController, animated: true)
    }
}

// MARK: - Table View Data Source and Delegate
extension CertificatesViewController {
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch Section(rawValue: section) {
        case .addCertificate:
            return 40
        default:
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let section = Section(rawValue: section) else { return nil }
        var title = ""
        
        switch section {
        case .addCertificate:
            title = String.localized("SETTINGS_VIEW_CONTROLLER_CELL_ADD_CERTIFICATES")
        case .certificates:
            title = String.localized("CERTIFICATES_VIEW_CONTROLLER_SECTION_CERTIFICATES")
        }
        
        let headerView = InsetGroupedSectionHeader(title: title)
        headerView.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        return headerView
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .addCertificate:
            return 1
        case .certificates:
            return certs?.count ?? 0
        default:
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section) {
        case .addCertificate:
            let cell = tableView.dequeueReusableCell(withIdentifier: "AddCell", for: indexPath) as! CertificateViewAddTableViewCell
            cell.configure(with: "plus")
            cell.selectionStyle = .none
            return cell
            
        case .certificates:
            guard let certificate = certs?[indexPath.row] else {
                return UITableViewCell()
            }
            let cell = tableView.dequeueReusableCell(withIdentifier: "CertificateCell", for: indexPath) as! CertificateViewTableViewCell
            cell.configure(with: certificate, isSelected: Preferences.selectedCert == indexPath.row)
            return cell
            
        default:
            return UITableViewCell()
        }
    }
    
    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return contextMenuForCertificate(at: indexPath)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch Section(rawValue: indexPath.section) {
        case .addCertificate:
            addCert()
        case .certificates:
            updateSelectedCertificate(at: indexPath)
        default:
            break
        }
    }
    
    private func updateSelectedCertificate(at indexPath: IndexPath) {
        let previousSelectedCert = Preferences.selectedCert
        Preferences.selectedCert = indexPath.row
        
        var indexPathsToReload = [indexPath]
        if previousSelectedCert != indexPath.row {
            indexPathsToReload.append(IndexPath(row: previousSelectedCert, section: Section.certificates.rawValue))
        }
        
        tableView.reloadRows(at: indexPathsToReload, with: .fade)
        tableView.deselectRow(at: indexPath, animated: true)
        tableView.reloadSections(IndexSet([Section.addCertificate.rawValue]), with: .automatic)
    }
}

// MARK: - Certificate Management
extension CertificatesViewController {
    
    @objc func afetch() {
        fetchSources()
    }
    
    func fetchSources() {
        do {
            self.certs = try CoreDataManager.shared.getDatedCertificate()
            DispatchQueue.main.async {
                UIView.transition(with: self.tableView, duration: 0.35, options: .transitionCrossDissolve, animations: {
                    self.tableView.reloadData()
                }, completion: nil)
            }
        } catch {
            print("Error fetching certificates: \(error)")
        }
    }
    
    private func contextMenuForCertificate(at indexPath: IndexPath) -> UIContextMenuConfiguration? {
        guard let source = certs?[indexPath.row] else { return nil }
        
        return UIContextMenuConfiguration(identifier: nil, actionProvider: { _ in
            UIMenu(title: "", image: nil, identifier: nil, options: [], children: [
                UIAction(title: String.localized("DELETE"), image: UIImage(systemName: "trash"), attributes: .destructive, handler: { [weak self] _ in
                    self?.deleteCertificate(at: indexPath, source: source)
                })
            ])
        })
    }
    
    private func deleteCertificate(at indexPath: IndexPath, source: Certificate) {
        if Preferences.selectedCert != indexPath.row {
            do {
                try CoreDataManager.shared.deleteAllCertificateContent(for: source)
                self.certs?.remove(at: indexPath.row)
                self.tableView.beginUpdates()
                self.tableView.deleteRows(at: [indexPath], with: .automatic)
                self.tableView.endUpdates()
            } catch {
                print("Error deleting certificate: \(error)")
            }
        } else {
            presentDeleteAlert()
        }
    }
    
    private func presentDeleteAlert() {
        let alert = UIAlertController(title: String.localized("CERTIFICATES_VIEW_CONTROLLER_DELETE_ALERT_TITLE"), message: String.localized("CERTIFICATES_VIEW_CONTROLLER_DELETE_ALERT_DESCRIPTION"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String.localized("CANCEL"), style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
}