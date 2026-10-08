//
//  SettingsHeaderFooterView.swift
//  ZLoader
//
//  Created by Riley Testut on 8/31/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit


final class SettingsHeaderFooterView: UITableViewHeaderFooterView
{
    @IBOutlet var primaryLabel: UILabel!
    @IBOutlet var secondaryLabel: UILabel!
    @IBOutlet var button: UIButton!
        
    @IBOutlet private var stackView: UIStackView!
    override init(reuseIdentifier: String?)
    {
        super.init(reuseIdentifier: reuseIdentifier)

        primaryLabel = UILabel()
        secondaryLabel = UILabel()
        button = UIButton(type: .system)
        primaryLabel.font = UIFont.systemFont(ofSize: 14)
        primaryLabel.textColor = .secondaryLabel
        primaryLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        secondaryLabel.font = UIFont.systemFont(ofSize: 14)
        secondaryLabel.textColor = .secondaryLabel
        secondaryLabel.numberOfLines = 0
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 14)

        let titleRow = UIStackView(arrangedSubviews: [primaryLabel, button])
        titleRow.distribution = .equalSpacing
        stackView = UIStackView(arrangedSubviews: [titleRow, secondaryLabel])
        stackView.axis = .vertical
        layoutMargins = UIEdgeInsets(top: 8, left: 30, bottom: 8, right: 30)
        configureLayout()
    }

    required init?(coder: NSCoder)
    {
        super.init(coder: coder)
    }

    override func awakeFromNib()
    {
        super.awakeFromNib()
        primaryLabel.textColor = .secondaryLabel
        secondaryLabel.textColor = .secondaryLabel
        button.setTitleColor(.altPrimary, for: .normal)
        configureLayout()
    }

    private func configureLayout()
    {
        primaryLabel.font = .preferredFont(forTextStyle: .footnote)
        secondaryLabel.font = .preferredFont(forTextStyle: .footnote)
        primaryLabel.adjustsFontForContentSizeCategory = true
        secondaryLabel.adjustsFontForContentSizeCategory = true
        self.contentView.layoutMargins = .zero
        self.contentView.preservesSuperviewLayoutMargins = true
        
        self.stackView.translatesAutoresizingMaskIntoConstraints = false
        self.contentView.addSubview(self.stackView)
        
        NSLayoutConstraint.activate([self.stackView.leadingAnchor.constraint(equalTo: self.contentView.layoutMarginsGuide.leadingAnchor),
                                     self.stackView.trailingAnchor.constraint(equalTo: self.contentView.layoutMarginsGuide.trailingAnchor),
                                     self.stackView.topAnchor.constraint(equalTo: self.contentView.layoutMarginsGuide.topAnchor),
                                     self.stackView.bottomAnchor.constraint(equalTo: self.contentView.layoutMarginsGuide.bottomAnchor)])
    }
}
