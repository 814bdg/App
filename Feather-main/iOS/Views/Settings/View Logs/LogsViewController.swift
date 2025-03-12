//
//  LogsViewController.swift
//  feather
//
//  Created by samara on 22.10.2024.
//

import UIKit

class LogsViewController: UIViewController {
    private var tableView: UITableView!
    private var logTextView: UITextView!
    private var logFileObserver: DispatchSourceFileSystemObject?
    private var currentFileSize: UInt64 = 0
    private var errCount = 0
    
    enum Section: Int, CaseIterable {
        case errorCount, actions
    }
    
    enum ActionRow: Int {
        case share, copy
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigation()
        setupViews()
        startObservingLogFile()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        parseLogFile()
        tableView.reloadSections(IndexSet([Section.errorCount.rawValue]), with: .fade)
    }
    
    private func setupNavigation() {
        self.navigationItem.largeTitleDisplayMode = .never
        self.title = String.localized("LOGS_VIEW_TITLE")
    }
    
    private func setupViews() {
        view.backgroundColor = .systemBackground
        
        logTextView = UITextView()
        logTextView.isEditable = false
        logTextView.translatesAutoresizingMaskIntoConstraints = false
        logTextView.font = UIFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        logTextView.textContainerInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        logTextView.accessibilityLabel = String.localized("LOGS_TEXT_VIEW_ACCESSIBILITY_LABEL")
        view.addSubview(logTextView)
        
        tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .systemBackground
        tableView.layer.cornerRadius = 12
        tableView.layer.cornerCurve = .continuous
        tableView.layer.masksToBounds = true
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            logTextView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            logTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            logTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            logTextView.heightAnchor.constraint(equalToConstant: 400),
            
            tableView.topAnchor.constraint(equalTo: logTextView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        loadInitialLogContents()
    }
    
    private func loadInitialLogContents() {
        let logFilePath = getDocumentsDirectory().appendingPathComponent("logs.txt")
        do {
            let data = try Data(contentsOf: logFilePath)
            logTextView.text = String(data: data, encoding: .utf8) ?? String.localized("LOGS_FAILED_TO_LOAD")
            currentFileSize = UInt64(data.count)
        } catch {
            logTextView.text = String.localized("LOGS_FAILED_TO_OPEN")
            Debug.shared.log(message: "Failed to load initial log contents: \(error)")
        }
    }
    
    private func startObservingLogFile() {
        let logFilePath = getDocumentsDirectory().appendingPathComponent("logs.txt").path
        let fileDescriptor = open(logFilePath, O_EVTONLY)
        
        guard fileDescriptor != -1 else {
            logTextView.text.append("\n" + String.localized("LOGS_OBSERVATION_FAILED"))
            Debug.shared.log(message: "Failed to open file for observation")
            return
        }
        
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor, eventMask: .write, queue: DispatchQueue.main)
        source.setEventHandler { [weak self] in
            self?.loadNewLogContents()
        }
        source.setCancelHandler {
            close(fileDescriptor)
        }
        source.resume()
        logFileObserver = source
    }
    
    private func loadNewLogContents() {
        let logFilePath = getDocumentsDirectory().appendingPathComponent("logs.txt")
        guard let fileHandle = try? FileHandle(forReadingFrom: logFilePath) else {
            logTextView.text.append("\n" + String.localized("LOGS_READ_FAILED"))
            return
        }
        
        fileHandle.seek(toFileOffset: currentFileSize)
        let newData = fileHandle.readDataToEndOfFile()
        if let newContent = String(data: newData, encoding: .utf8), !newContent.isEmpty {
            logTextView.text.append(newContent)
            scrollToBottom()
        }
        currentFileSize += UInt64(newData.count)
        fileHandle.closeFile()
    }
    
    private func scrollToBottom() {
        let bottomRange = NSRange(location: max(0, logTextView.text.count - 1), length: 1)
        logTextView.scrollRangeToVisible(bottomRange)
    }
    
    private func parseLogFile() {
        let logFilePath = getDocumentsDirectory().appendingPathComponent("logs.txt")
        do {
            let logContents = try String(contentsOf: logFilePath)
            let logEntries = logContents.components(separatedBy: .newlines)
            
            errCount = logEntries.reduce(0) { count, entry in
                count + (entry.contains("🔍") || entry.contains("⚠️") || entry.contains("❌") || entry.contains("🔥") ? 1 : 0)
            }
        } catch {
            Debug.shared.log(message: "Error parsing log file: \(error)")
            logTextView.text.append("\n" + String.localized("LOGS_PARSE_ERROR", arguments: [error.localizedDescription]))
        }
    }
    
    deinit {
        logFileObserver?.cancel()
    }
}

// MARK: - UITableView DataSource and Delegate
extension LogsViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let headerView = InsetGroupedSectionHeader(title: "")
        return headerView
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .errorCount: return 1
        case .actions: return 2
        case .none: return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: "Cell")
        cell.selectionStyle = .none
        
        switch Section(rawValue: indexPath.section) {
        case .errorCount:
            cell.textLabel?.text = String.localized("LOGS_VIEW_SECTION_TITLE_ERROR", arguments: ["\(errCount)"])
            cell.textLabel?.textColor = .white
            cell.textLabel?.font = .boldSystemFont(ofSize: 14)
            cell.backgroundColor = .systemRed
            cell.accessibilityLabel = String.localized("LOGS_ERROR_COUNT_ACCESSIBILITY", arguments: ["\(errCount)"])
            
        case .actions:
            switch ActionRow(rawValue: indexPath.row) {
            case .share:
                cell.textLabel?.text = String.localized("LOGS_VIEW_SECTION_TITLE_SHARE")
                cell.textLabel?.textColor = .tintColor
                cell.selectionStyle = .default
                cell.setAccessoryIcon(with: "square.and.arrow.up")
                cell.accessibilityLabel = String.localized("LOGS_SHARE_ACCESSIBILITY")
                cell.accessibilityHint = String.localized("LOGS_SHARE_ACCESSIBILITY_HINT")
                
            case .copy:
                cell.textLabel?.text = String.localized("LOGS_VIEW_SECTION_TITLE_COPY")
                cell.textLabel?.textColor = .tintColor
                cell.selectionStyle = .default
                cell.setAccessoryIcon(with: "arrow.up.right")
                cell.accessibilityLabel = String.localized("LOGS_COPY_ACCESSIBILITY")
                cell.accessibilityHint = String.localized("LOGS_COPY_ACCESSIBILITY_HINT")
                
            case .none:
                break
            }
            
        case .none:
            break
        }
        
        cell.textLabel?.adjustsFontForContentSizeCategory = true
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch (Section(rawValue: indexPath.section), ActionRow(rawValue: indexPath.row)) {
        case (.actions, .share):
            shareLogs()
            
        case (.actions, .copy):
            copyLogs()
            
        default:
            break
        }
    }
    
    private func shareLogs() {
        let logFilePath = getDocumentsDirectory().appendingPathComponent("logs.txt")
        let activityVC = UIActivityViewController(activityItems: [logFilePath], applicationActivities: nil)
        
        if let sheet = activityVC.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
        
        present(activityVC, animated: true)
    }
    
    private func copyLogs() {
        let logFilePath = getDocumentsDirectory().appendingPathComponent("logs.txt")
        do {
            let logContents = try String(contentsOf: logFilePath, encoding: .utf8)
            UIPasteboard.general.string = logContents
            showAlert(title: String.localized("ALERT_COPIED"), message: String.localized("LOGS_VIEW_SUCCESS_DESCRIPTION"))
        } catch {
            showAlert(title: String.localized("ALERT_ERROR"), message: String.localized("LOGS_VIEW_ERROR_DESCRIPTION", arguments: [error.localizedDescription]))
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String.localized("OK"), style: .default))
        present(alert, animated: true)
    }
}

// Placeholder for missing utilities (ensure these are defined elsewhere)
func getDocumentsDirectory() -> URL {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
}

extension UITableViewCell {
    func setAccessoryIcon(with systemName: String) {
        accessoryView = UIImageView(image: UIImage(systemName: systemName))
    }
}

class InsetGroupedSectionHeader: UIView {
    var titleLabel: UILabel?
    init(title: String) {
        super.init(frame: .zero)
        titleLabel = UILabel()
        titleLabel?.text = title
        titleLabel?.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel!)
        NSLayoutConstraint.activate([
            titleLabel!.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel!.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}