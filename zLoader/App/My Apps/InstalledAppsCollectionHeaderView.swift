//
//  InstalledAppsCollectionHeaderView.swift
//  ZLoader
//
//  Created by Riley Testut on 3/9/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit
import Nuke

final class InstalledAppsCollectionHeaderView: UICollectionReusableView
{
    let textLabel: UILabel
    let button: PillButton
    private let pendingStack = UIStackView()
    
    override init(frame: CGRect)
    {
        self.textLabel = UILabel()
        self.textLabel.translatesAutoresizingMaskIntoConstraints = false
        self.textLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        self.textLabel.accessibilityTraits.insert(.header)
        
        self.button = PillButton(type: .system)
        self.button.translatesAutoresizingMaskIntoConstraints = false
        self.button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        
        super.init(frame: frame)
        
        self.addSubview(self.textLabel)
        self.addSubview(self.button)
        
        NSLayoutConstraint.activate([self.textLabel.leadingAnchor.constraint(equalTo: self.layoutMarginsGuide.leadingAnchor),
                                     self.textLabel.bottomAnchor.constraint(equalTo: self.bottomAnchor)])
        
        NSLayoutConstraint.activate([self.button.trailingAnchor.constraint(equalTo: self.layoutMarginsGuide.trailingAnchor),
                                     self.button.firstBaselineAnchor.constraint(equalTo: self.textLabel.firstBaselineAnchor)])
        
        self.pendingStack.axis = .vertical
        self.pendingStack.spacing = 10
        self.pendingStack.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.pendingStack)
        NSLayoutConstraint.activate([
            self.pendingStack.leadingAnchor.constraint(equalTo: self.layoutMarginsGuide.leadingAnchor),
            self.pendingStack.trailingAnchor.constraint(equalTo: self.layoutMarginsGuide.trailingAnchor),
            self.pendingStack.topAnchor.constraint(equalTo: self.topAnchor)
        ])
        self.preservesSuperviewLayoutMargins = true
    }
    
    func showPendingInstallations(_ installations: [AppManager.PendingInstallation]) {
        for view in self.pendingStack.arrangedSubviews {
            self.pendingStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        self.pendingStack.isHidden = installations.isEmpty
        for installation in installations {
            let row = UIView()
            row.backgroundColor = .secondarySystemGroupedBackground
            row.layer.cornerRadius = 22
            row.alpha = 0.75
            let icon = UIImageView(image: UIImage(systemName: "app.fill"))
            icon.tintColor = .altPrimary
            icon.contentMode = .scaleAspectFit
            icon.layer.cornerRadius = 12
            icon.clipsToBounds = true
            let name = UILabel()
            name.font = .preferredFont(forTextStyle: .headline)
            name.text = installation.name
            name.numberOfLines = 1
            let status = UILabel()
            status.font = .preferredFont(forTextStyle: .subheadline)
            status.textColor = .secondaryLabel
            status.text = NSLocalizedString("Installing", comment: "")
            let labels = UIStackView(arrangedSubviews: [name, status])
            labels.axis = .vertical
            labels.spacing = 4
            let progress = PillButton(type: .system)
            progress.progress = installation.progress
            progress.isUserInteractionEnabled = false
            let contents = UIStackView(arrangedSubviews: [icon, labels, progress])
            contents.axis = .horizontal
            contents.spacing = 14
            contents.alignment = .center
            contents.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(contents)
            NSLayoutConstraint.activate([
                row.heightAnchor.constraint(equalToConstant: 88),
                contents.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
                contents.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -14),
                contents.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                icon.widthAnchor.constraint(equalToConstant: 52),
                icon.heightAnchor.constraint(equalToConstant: 52),
                progress.widthAnchor.constraint(equalToConstant: 60),
                progress.heightAnchor.constraint(equalToConstant: 52)
            ])
            self.pendingStack.addArrangedSubview(row)
            if let url = installation.iconURL {
                Task { [weak icon] in
                    if let image = try? await ImagePipeline.shared.image(for: url) { icon?.image = image }
                }
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
