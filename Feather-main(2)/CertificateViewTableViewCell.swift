class CertificateViewTableViewCell: UITableViewCell {
    // ... existing properties
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    private func setupUI() {
        backgroundColor = .clear
        contentView.addSubview(roundedBackgroundView)
        roundedBackgroundView.addSubview(certImageView)
        let labelsStackView = UIStackView(arrangedSubviews: [teamNameLabel, expirationDateLabel])
        labelsStackView.axis = .vertical
        labelsStackView.spacing = 5
        roundedBackgroundView.addSubview(labelsStackView)
        roundedBackgroundView.addSubview(pillsStackView)
        contentView.addSubview(checkmarkImageView)
        
        // ... existing constraints
        
        labelsStackView.leadingAnchor.constraint(equalTo: certImageView.trailingAnchor, constant: 10).isActive = true
        labelsStackView.topAnchor.constraint(equalTo: roundedBackgroundView.topAnchor, constant: 10).isActive = true
        labelsStackView.trailingAnchor.constraint(equalTo: roundedBackgroundView.trailingAnchor, constant: -10).isActive = true
        
        certImageView.leadingAnchor.constraint(equalTo: roundedBackgroundView.leadingAnchor, constant: 10).isActive = true
        certImageView.centerYAnchor.constraint(equalTo: roundedBackgroundView.centerYAnchor).isActive = true
        certImageView.widthAnchor.constraint(equalToConstant: 40).isActive = true
        certImageView.heightAnchor.constraint(equalToConstant: 40).isActive = true
        
        // Accessibility
        teamNameLabel.accessibilityLabel = String.localized("CERTIFICATE_TEAM_NAME")
        expirationDateLabel.accessibilityLabel = String.localized("CERTIFICATE_EXPIRATION_DATE")
    }
    
    func configure(with certificate: Certificate, isSelected: Bool) {
        // ... existing configuration
        
        teamNameLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        expirationDateLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        
        roundedBackgroundView.backgroundColor = isSelected ? UIColor.systemGray6 : UIColor.secondarySystemGroupedBackground
        checkmarkImageView.isHidden = !isSelected
        checkmarkImageView.tintColor = isSelected ? .systemBlue : .clear
        
        // Set accessibility hints
        teamNameLabel.accessibilityHint = teamNameLabel.text
        expirationDateLabel.accessibilityHint = expirationDateLabel.text
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}