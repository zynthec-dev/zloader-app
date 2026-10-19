//
//  InsetGroupTableViewCell.swift
//  ZLoader
//
//  Created by Riley Testut on 8/31/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit

extension InsetGroupTableViewCell
{
    @objc enum Style: Int
    {
        case single
        case top
        case middle
        case bottom
    }
}

class InsetGroupTableViewCell: UITableViewCell
{
#if !TARGET_INTERFACE_BUILDER
    @IBInspectable var style: Style = .single {
        didSet {
            self.update()
        }
    }
#else
    @IBInspectable var style: Int = 0
#endif
    
    @IBInspectable var isSelectable: Bool = false
    
    private var stacksValueLabels = false
    private let separatorView = UIView()
    private let insetView = UIVisualEffectView()
    private var separatorLeadingConstraint: NSLayoutConstraint!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?)
    {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.setup()
    }
    
    required init?(coder: NSCoder)
    {
        super.init(coder: coder)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // Keep the margins transparent after the shared UITableViewCell appearance
        // is applied. The inset card owns the themed fill and rounded corners.
        self.backgroundColor = .clear
        self.contentView.backgroundColor = .clear
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        separatorLeadingConstraint?.constant = contentView.viewWithTag(77023) == nil ? 30 : 62
        // Match the symbol and title alignment of the shared SwiftUI rows.
        guard let icon = imageView, icon.tag == 77023, icon.image != nil,
              let label = textLabel else { return }
        icon.contentMode = .scaleAspectFit
        icon.frame = CGRect(x: ZLoaderSettingsStyle.symbolLeading, y: (contentView.bounds.height - ZLoaderSettingsStyle.symbolFrame) / 2, width: ZLoaderSettingsStyle.symbolFrame, height: ZLoaderSettingsStyle.symbolFrame)
        let width = max(0, contentView.bounds.width - ZLoaderSettingsStyle.titleLeading - 30)
        if stacksValueLabels, let detail = detailTextLabel {
            // Account values can be wider than the remaining horizontal space.
            // Stack them so UIKit cannot compress the field name to an ellipsis.
            label.numberOfLines = 0
            detail.numberOfLines = 0
            detail.textAlignment = .natural
            detail.adjustsFontForContentSizeCategory = true
            let titleHeight = label.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
            let valueHeight = detail.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
            let top = max(16, (contentView.bounds.height - titleHeight - valueHeight - 4) / 2)
            label.frame = CGRect(x: ZLoaderSettingsStyle.titleLeading, y: top, width: width, height: titleHeight)
            detail.frame = CGRect(x: ZLoaderSettingsStyle.titleLeading, y: label.frame.maxY + 4, width: width, height: valueHeight)
        } else {
            label.frame.origin.x = ZLoaderSettingsStyle.titleLeading
            label.frame.size.width = width
            if let detail = detailTextLabel {
                detail.frame.origin.x = ZLoaderSettingsStyle.titleLeading
                detail.frame.size.width = width
            }
        }
    }

    func valueRowHeight(for width: CGFloat) -> CGFloat {
        guard let title = textLabel, let value = detailTextLabel else {
            return ZLoaderSettingsStyle.minimumRowHeight + ZLoaderSettingsStyle.rowSpacing
        }
        stacksValueLabels = true
        let availableWidth = max(1, width - ZLoaderSettingsStyle.titleLeading - 30)
        let size = CGSize(width: availableWidth, height: .greatestFiniteMagnitude)
        title.numberOfLines = 0
        value.numberOfLines = 0
        title.font = .preferredFont(forTextStyle: .body)
        value.font = UIFont.preferredFont(forTextStyle: .body)
        return max(ZLoaderSettingsStyle.minimumRowHeight + ZLoaderSettingsStyle.rowSpacing,
                   ceil(title.sizeThatFits(size).height + value.sizeThatFits(size).height) + 44)
    }

    override func awakeFromNib()
    {
        super.awakeFromNib()
        self.setup()
    }
    
    private func setup()
    {
        self.selectionStyle = .none
        let minimumHeight = contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: ZLoaderSettingsStyle.minimumRowHeight + ZLoaderSettingsStyle.rowSpacing)
        minimumHeight.priority = .init(999)
        minimumHeight.isActive = true
        
        self.separatorView.translatesAutoresizingMaskIntoConstraints = false
        self.separatorView.backgroundColor = .separator
        self.addSubview(self.separatorView)
        
        self.insetView.layer.masksToBounds = true
        self.insetView.layer.cornerRadius = ZLoaderSettingsStyle.cardRadius
        self.insetView.layer.cornerCurve = .continuous
        
        // Get the preferred background color from Interface Builder if set.
        if let bgColor = self.backgroundColor, bgColor != .clear {
            self.insetView.backgroundColor = bgColor
        } else {
            self.insetView.backgroundColor = UIColor.settingsCard
        }
        self.backgroundColor = nil
        
        self.addSubview(self.insetView, pinningEdgesWith: UIEdgeInsets(top: 4, left: ZLoaderSettingsStyle.horizontalInset, bottom: 4, right: ZLoaderSettingsStyle.horizontalInset))
        self.sendSubviewToBack(self.insetView)
        
        separatorLeadingConstraint = self.separatorView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 30)
        NSLayoutConstraint.activate([separatorLeadingConstraint,
                                     self.separatorView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -16),
                                     self.separatorView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
                                     self.separatorView.heightAnchor.constraint(equalToConstant: 1 / traitCollection.displayScale)])
        self.bringSubviewToFront(separatorView)
        
        self.update()
    }
    
    override func setSelected(_ selected: Bool, animated: Bool)
    {
        super.setSelected(selected, animated: animated)
        
        if animated
        {
            UIView.animate(withDuration: 0.4) {
                self.update()
            }
        }
        else
        {
            self.update()
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool)
    {
        super.setHighlighted(highlighted, animated: animated)
        
        if animated
        {
            UIView.animate(withDuration: 0.4) {
                self.update()
            }
        }
        else
        {
            self.update()
        }
    }
}

private extension InsetGroupTableViewCell
{
    func update()
    {
        // Each entry is its own card, matching the SwiftUI submenu rows.
        insetView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        self.separatorView.isHidden = true
        ZLoaderCardMaterial.apply(to: insetView, usesGlass: false)

        if self.isSelectable && (self.isHighlighted || self.isSelected)
        {
            self.insetView.backgroundColor = UIColor.settingsHighlighted
        }
        else
        {
            if insetView.effect == nil { self.insetView.backgroundColor = UIColor.settingsCard }
        }
    }
}
