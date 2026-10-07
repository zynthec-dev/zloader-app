//
//  Button.swift
//  ZLoader
//
//  Created by Riley Testut on 5/9/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit

final class Button: UIButton
{
    override var intrinsicContentSize: CGSize {
        var size = super.intrinsicContentSize
        size.width += 20
        size.height += 10
        return size
    }
    
    override func awakeFromNib()
    {
        super.awakeFromNib()
        
        
        self.layer.masksToBounds = true
        self.layer.cornerRadius = 8
        
        self.update()
    }
    
    override func tintColorDidChange()
    {
        super.tintColorDidChange()
        
        self.update()
    }
    
    override var isHighlighted: Bool {
        didSet {
            self.update()
        }
    }
    
    override var isEnabled: Bool {
        didSet {
            self.update()
        }
    }
}

private extension Button
{
    func update()
    {
        if #available(iOS 26.0, tvOS 26.0, *) {
            var config = UIButton.Configuration.prominentGlass()
            config.title = self.currentTitle
            config.image = self.currentImage
            config.baseBackgroundColor = self.tintColor
            config.baseForegroundColor = self.tintColor.contrastingText
            self.backgroundColor = .clear
            self.configuration = config
            return
        }
        self.setTitleColor(self.tintColor.contrastingText, for: .normal)
        self.setTitleColor(UIColor.lightGray.contrastingText, for: .disabled)
        if self.isEnabled
        {
            self.backgroundColor = self.tintColor
        }
        else
        {
            self.backgroundColor = .lightGray
        }
    }
}
