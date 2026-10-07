//
//  UIColor+zLoader.swift
//  ZLoader
//
//  Created by Riley Testut on 5/9/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit

public extension UIColor
{
    private static func namedColor(_ name: String) -> UIColor? {
        return UIColor(named: name, in: .main, compatibleWith: nil)
    }

    static var altPrimary: UIColor {
        #if WIDGET_EXTENSION
        return defaultAltPrimary
        #else
        return UIColor { traits in ThemeManager.shared.primaryColor.resolvedColor(with: traits) }
        #endif
    }
    static var settingsSymbol: UIColor {
        #if WIDGET_EXTENSION
        return defaultAltPrimary
        #else
        return UIColor { traits in ThemeManager.shared.symbolColor.resolvedColor(with: traits) }
        #endif
    }
    static var settingsField: UIColor {
        #if WIDGET_EXTENSION
        return .secondarySystemGroupedBackground
        #else
        return UIColor { traits in ThemeManager.shared.fieldColor.resolvedColor(with: traits) }
        #endif
    }
    static let defaultAltPrimary = namedColor("Primary")!
    static let deltaPrimary = namedColor("DeltaPrimary")
    static let clipPrimary = namedColor("ClipPrimary")
    
    static let refreshRed = namedColor("RefreshRed")!
    static let refreshOrange = namedColor("RefreshOrange")!
    static let refreshYellow = namedColor("RefreshYellow")!
    static let refreshGreen = namedColor("RefreshGreen")!

    static var altBackground: UIColor { .systemBackground }
    static var settingsBackground: UIColor { .systemGroupedBackground }
    static var settingsHighlighted: UIColor { .tertiarySystemGroupedBackground }
    static var settingsCard: UIColor { .secondarySystemGroupedBackground }

    static var altInvertedPrimary: UIColor { settingsHighlighted }
}

public extension UIColor
{
    private static let brightnessMaxThreshold = 0.85
    private static let brightnessMinThreshold = 0.35

    private static let saturationBrightnessThreshold = 0.5

    var adjustedForDisplay: UIColor {
        guard self.isTooBright || self.isTooDark else { return self }

        return UIColor { traits in
            var hue: CGFloat = 0
            var saturation: CGFloat = 0
            var brightness: CGFloat = 0
            guard self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil) else { return self }

            brightness = min(brightness, UIColor.brightnessMaxThreshold)

            if traits.userInterfaceStyle == .dark
            {
                // Only raise brightness when in dark mode.
                brightness = max(brightness, UIColor.brightnessMinThreshold)
            }

            let color = UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1.0)
            return color
        }
    }

    var isTooBright: Bool {
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0

        guard self.getHue(nil, saturation: &saturation, brightness: &brightness, alpha: nil) else { return false }

        let isTooBright = (brightness >= UIColor.brightnessMaxThreshold && saturation <= UIColor.saturationBrightnessThreshold)
        return isTooBright
    }

    var isTooDark: Bool {
        var brightness: CGFloat = 0
        guard self.getHue(nil, saturation: nil, brightness: &brightness, alpha: nil) else { return false }

        let isTooDark = brightness <= UIColor.brightnessMinThreshold
        return isTooDark
    }
}

public extension UIColor {
    /// Choose the higher-contrast text color after resolving the actual appearance.
    var contrastingText: UIColor {
        UIColor { traits in
            let color = self.resolvedColor(with: traits)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            guard color.getRed(&r, green: &g, blue: &b, alpha: &a) else { return .label }
            func linear(_ value: CGFloat) -> CGFloat {
                value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            let luminance = 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
            return luminance > 0.179 ? .black : .white
        }
    }
}
