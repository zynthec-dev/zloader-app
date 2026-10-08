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
    
    private let separatorView = UIView()
    private let insetView = UIVisualEffectView()
    
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
        // Match the 22-point symbols and 30/62-point leading positions used
        // by storyboard rows decorated in SettingsViewController.
        guard let icon = imageView, icon.tag == 77023, icon.image != nil,
              let label = textLabel else { return }
        icon.contentMode = .scaleAspectFit
        icon.frame = CGRect(x: 30, y: (contentView.bounds.height - 22) / 2, width: 22, height: 22)
        let trailing = label.frame.maxX
        label.frame.origin.x = 62
        label.frame.size.width = max(0, trailing - 62)
        if let detail = detailTextLabel {
            let detailTrailing = detail.frame.maxX
            detail.frame.origin.x = 62
            detail.frame.size.width = max(0, detailTrailing - 62)
        }
    }

    override func awakeFromNib()
    {
        super.awakeFromNib()
        self.setup()
    }
    
    private func setup()
    {
        self.selectionStyle = .none
        
        self.separatorView.translatesAutoresizingMaskIntoConstraints = false
        self.separatorView.backgroundColor = .separator
        self.addSubview(self.separatorView)
        
        self.insetView.layer.masksToBounds = true
        self.insetView.layer.cornerRadius = 16
        
        // Get the preferred background color from Interface Builder if set.
        if let bgColor = self.backgroundColor, bgColor != .clear {
            self.insetView.backgroundColor = bgColor
        } else {
            self.insetView.backgroundColor = UIColor.settingsCard
        }
        self.backgroundColor = nil
        
        self.addSubview(self.insetView, pinningEdgesWith: UIEdgeInsets(top: 4, left: 15, bottom: 4, right: 15))
        self.sendSubviewToBack(self.insetView)
        
        NSLayoutConstraint.activate([self.separatorView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 30),
                                     self.separatorView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -30),
                                     self.separatorView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
                                     self.separatorView.heightAnchor.constraint(equalToConstant: 1)])
        
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
        self.insetView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
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
