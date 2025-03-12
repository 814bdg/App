//
//  SigningsInputViewController.swift
//  feather
//
//  Created by samara on 8/15/24.
//  Copyright © 2024 Samara M (khcrysalis)
//

import UIKit

class SigningsInputViewController: UITableViewController, UITextFieldDelegate {
    
    // Properties
    private let parentView: SigningsViewController
    private let initialValue: String
    private let valueToSaveTo: Int
    
    private var changedValue: String?
    
    // Lazy initialization of UI components
    private lazy var textField: UITextField = {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.addTarget(self, action: #selector(textDidChange), for: .editingChanged)
        textField.borderStyle = .roundedRect
        textField.clearButtonMode = .whileEditing
        
        switch valueToSaveTo {
        case 3: // Version
            textField.keyboardType = .decimalPad
            textField.returnKeyType = .done
        case 2: // Bundle ID
            textField.keyboardType = .asciiCapable
            textField.returnKeyType = .done
        default:
            textField.keyboardType = .default
            textField.returnKeyType = .done
        }

        textField.delegate = self
        
        // Customizing placeholder color
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.systemGray
        ]
        textField.attributedPlaceholder = NSAttributedString(string: initialValue, attributes: attributes)
        
        return textField
    }()
    
    private lazy var errorLabel: UILabel = {
        let label = UILabel()
        label.textColor = .systemRed
        label.font = UIFont.systemFont(ofSize: 12)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()
    
    // MARK: - Initialization
    
    init(parentView: SigningsViewController, initialValue: String, valueToSaveTo: Int) {
        self.parentView = parentView
        self.initialValue = initialValue
        self.valueToSaveTo = valueToSaveTo
        super.init(style: .insetGrouped)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        textField.font = UIFont.preferredFont(forTextStyle: .body)
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        navigationItem.largeTitleDisplayMode = .never
        self.title = initialValue.capitalized
        
        let saveButton = UIBarButtonItem(title: NSLocalizedString("SAVE", comment: "Save button text"), style: .done, target: self, action: #selector(saveButtonTapped))
        saveButton.isEnabled = false
        navigationItem.rightBarButtonItem = saveButton
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "InputCell")
    }
    
    // MARK: - Actions
    
    @objc private func saveButtonTapped() {
        if validateInput(textField.text) {
            updateParentView()
            navigationController?.popViewController(animated: true)
        } else {
            showAlert(title: NSLocalizedString("Input Error", comment: "Error title"), message: NSLocalizedString("Please enter a valid value.", comment: "Error message"))
        }
    }
    
    @objc private func textDidChange() {
        let isValid = validateInput(textField.text)
        navigationItem.rightBarButtonItem?.isEnabled = isValid
        changedValue = isValid ? textField.text : nil
        
        textField.layer.borderWidth = 1.0
        textField.layer.borderColor = isValid ? UIColor.clear.cgColor : UIColor.systemRed.cgColor
        
        updateErrorLabel(isValid)
    }
    
    private func updateParentView() {
        guard let changedValue = changedValue else { return }
        
        switch valueToSaveTo {
        case 1:
            parentView.mainOptions.mainOptions.name = changedValue
        case 2:
            parentView.mainOptions.mainOptions.bundleId = changedValue
        case 3:
            parentView.mainOptions.mainOptions.version = changedValue
        default:
            break
        }
    }
    
    private func validateInput(_ text: String?) -> Bool {
        guard let text = text else { return false }
        
        switch valueToSaveTo {
        case 2: // Bundle ID
            return text.range(of: #"^([A-Za-z]{1}[A-Za-z\d_]*(\.[A-Za-z][A-Za-z\d_]*)*)$"#, options: .regularExpression) != nil
        case 3: // Version
            return text.range(of: #"^\d+(\.\d+){0,3}$"#, options: .regularExpression) != nil
        default:
            return !text.isEmpty
        }
    }
    
    private func updateErrorLabel(_ isValid: Bool) {
        errorLabel.isHidden = isValid
        
        if !isValid {
            switch valueToSaveTo {
            case 2:
                errorLabel.text = NSLocalizedString("Invalid Bundle ID format.", comment: "Bundle ID error message")
            case 3:
                errorLabel.text = NSLocalizedString("Invalid Version format. Example: 1.0.0", comment: "Version error message")
            default:
                errorLabel.text = NSLocalizedString("This field cannot be empty.", comment: "Generic error message")
            }
        } else {
            errorLabel.text = ""
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert action"), style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    // MARK: - Table View Data Source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "InputCell", for: indexPath)
        configureCell(cell)
        return cell
    }
    
    private func configureCell(_ cell: UITableViewCell) {
        textField.text = initialValue
        textField.placeholder = initialValue
        
        // Accessibility
        textField.accessibilityLabel = NSLocalizedString("Input Field", comment: "Accessibility label for input")
        textField.accessibilityHint = NSLocalizedString("Enter \(initialValue.capitalized)", comment: "Accessibility hint for input")
        
        if textField.superview == nil {
            cell.contentView.addSubview(textField)
            NSLayoutConstraint.activate([
                textField.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                textField.leadingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.leadingAnchor),
                textField.trailingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor)
            ])
        }
        
        if errorLabel.superview == nil {
            cell.contentView.addSubview(errorLabel)
            NSLayoutConstraint.activate([
                errorLabel.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: 4),
                errorLabel.leadingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.leadingAnchor),
                errorLabel.trailingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor)
            ])
        }
        
        cell.selectionStyle = .none
    }
    
    // MARK: - UITextFieldDelegate
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        textField.layer.borderColor = UIColor.systemBlue.cgColor
        textField.layer.borderWidth = 1.0
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.layer.borderWidth = 0.0
    }
}