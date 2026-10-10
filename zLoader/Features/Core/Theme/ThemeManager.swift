//
//  ThemeManager.swift
//  ZLoader
//
//  Created by Magesh K on 9/8/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import UIKit
import Combine
import SwiftUI

public struct ThemePreset: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let hex: String
    
    public var color: UIColor {
        id == "classic" ? .defaultAltPrimary : (UIColor(hex: hex) ?? .defaultAltPrimary)
    }
    
    public static let presets: [ThemePreset] = [
        ThemePreset(id: "classic", name: "zLoader Mint", hex: "#147D60"),
        ThemePreset(id: "neonViolet", name: "Neon Violet", hex: "#8B5CF6"),
        ThemePreset(id: "sunsetCrimson", name: "Sunset Crimson", hex: "#EF4444"),
        ThemePreset(id: "sapphireBlue", name: "Sapphire Blue", hex: "#3B82F6"),
        ThemePreset(id: "cyberpunkGold", name: "Cyberpunk Gold", hex: "#F59E0B"),
        ThemePreset(id: "emeraldMint", name: "Emerald Mint", hex: "#10B981"),
        ThemePreset(id: "electricPink", name: "Electric Pink", hex: "#EC4899")
    ]
}

public final class ThemeManager: ObservableObject {
    public static let shared = ThemeManager()
    public static let themeDidChangeNotification = Notification.Name("ZLoaderThemeDidChangeNotification")

    private static let userDefaultsKey = "userCustomThemeHex"

    @Published var appearance: AppAppearance = AppAppearance(rawValue: UserDefaults.standard.string(forKey: "zLoader.appearance") ?? "system") ?? .system {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: "zLoader.appearance")
            DispatchQueue.main.async { self.refreshVisibleAppearance() }
        }
    }

    @Published public var primaryColor: UIColor {
        didSet {
            UserDefaults.standard.set(primaryColor.hexString, forKey: Self.userDefaultsKey)
            NotificationCenter.default.post(name: Self.themeDidChangeNotification, object: primaryColor)
            DispatchQueue.main.async { self.refreshVisibleAppearance() }
        }
    }

    public var symbolColor: UIColor { primaryColor }
    public var fieldColor: UIColor { .secondarySystemGroupedBackground }

    private init() {
        UserDefaults.standard.removeObject(forKey: "zLoader.symbolColor")
        UserDefaults.standard.removeObject(forKey: "zLoader.fieldColor")
        if let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            for name in ["light.jpg", "dark.jpg"] {
                let obsoleteImage = support.appendingPathComponent("Appearance").appendingPathComponent(name)
                if FileManager.default.fileExists(atPath: obsoleteImage.path) {
                    do { try FileManager.default.removeItem(at: obsoleteImage) }
                    catch { debugLog("Could not remove obsolete appearance image: \(error.localizedDescription)") }
                }
            }
        }

        if let hex = UserDefaults.standard.string(forKey: Self.userDefaultsKey),
           let color = UIColor(hex: hex) {
            // Older versions persisted one resolved side of the dynamic mint.
            self.primaryColor = ["#207C65", "#74DDB5", "#147D60", "#57D5A2"].contains(hex.uppercased()) ? .defaultAltPrimary : color
        } else {
            self.primaryColor = .defaultAltPrimary
        }
    }

    public func resetToDefault() {
        self.primaryColor = .defaultAltPrimary
        UserDefaults.standard.removeObject(forKey: Self.userDefaultsKey)
    }
}

public extension UIColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hexSanitized.hasPrefix("#") {
            hexSanitized.remove(at: hexSanitized.startIndex)
        }

        var rgbValue: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgbValue) else { return nil }

        let r, g, b, a: CGFloat
        if hexSanitized.count == 6 {
            r = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgbValue & 0x0000FF) / 255.0
            a = 1.0
        } else if hexSanitized.count == 8 {
            r = CGFloat((rgbValue & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgbValue & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgbValue & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgbValue & 0x000000FF) / 255.0
        } else {
            return nil
        }

        self.init(red: r, green: g, blue: b, alpha: a)
    }

    var rgbComponents: (r: Int, g: Int, b: Int) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Int(r * 255), Int(g * 255), Int(b * 255))
    }

    var hslComponents: (h: Int, s: Int, l: Int) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)

        let maxVal = max(r, max(g, b))
        let minVal = min(r, min(g, b))
        let delta = maxVal - minVal

        var h: CGFloat = 0
        var s: CGFloat = 0
        let l: CGFloat = (maxVal + minVal) / 2.0

        if delta != 0 {
            s = l > 0.5 ? delta / (2.0 - maxVal - minVal) : delta / (maxVal + minVal)

            if maxVal == r {
                h = (g - b) / delta + (g < b ? 6 : 0)
            } else if maxVal == g {
                h = (b - r) / delta + 2
            } else {
                h = (r - g) / delta + 4
            }
            h /= 6.0
        }

        return (Int(h * 360), Int(s * 100), Int(l * 100))
    }
}

// Host all SwiftUI screens in the same observable palette as the UIKit shell.
struct ZLoaderThemedRoot<Content: View>: View {
    @ObservedObject private var theme = ThemeManager.shared
    let content: Content
    var usesGlass = true

    var body: some View {
        content
            .tint(Color(uiColor: theme.primaryColor))
            .accentColor(Color(uiColor: theme.primaryColor))
            .environment(\.locale, AppLanguage.launchLocale)
            .environment(\.zLoaderUsesGlass, usesGlass)
            .environment(\.defaultMinListRowHeight, 44)
            .font(.body)
            #if os(tvOS)
            .listStyle(.grouped)
            #else
            .listStyle(.insetGrouped)
            #endif
            .formStyle(.grouped)
            .preferredColorScheme(theme.appearance.colorScheme)
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .settingsBackground))
    }
}

final class ZLoaderHostingController<Content: View>: UIHostingController<ZLoaderThemedRoot<Content>> {
    var ownsNavigation = false
    private var previousNavigationBarHidden = false

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if ownsNavigation {
            previousNavigationBarHidden = navigationController?.isNavigationBarHidden ?? false
            navigationController?.setNavigationBarHidden(true, animated: animated)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .settingsBackground
        ThemeManager.shared.applyAppearance(to: view)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        // Style newly materialized SwiftUI rows before the frame is displayed,
        // rather than changing their surfaces after navigation completes.
        UIView.performWithoutAnimation {
            ThemeManager.shared.applyAppearance(to: view)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if ownsNavigation, isMovingFromParent || navigationController?.topViewController !== self {
            navigationController?.setNavigationBarHidden(previousNavigationBarHidden, animated: animated)
        }
    }

    init(rootView: Content, usesGlass: Bool = true) {
        super.init(rootView: ZLoaderThemedRoot(content: rootView, usesGlass: usesGlass))
    }

    @MainActor required dynamic init?(coder: NSCoder) {
        return nil
    }
}

extension ThemeManager {
    @MainActor func installAppearance() {
        UITableView.appearance().backgroundColor = .settingsBackground
        UICollectionView.appearance().backgroundColor = .settingsBackground
        UITextField.appearance().tintColor = .altPrimary
        UITextField.appearance().backgroundColor = .settingsField
        UISwitch.appearance().onTintColor = .altPrimary
    }

    @MainActor func refreshVisibleAppearance() {
        installAppearance()
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for window in scene.windows {
                window.overrideUserInterfaceStyle = appearance.interfaceStyle
                window.tintColor = primaryColor
                applyAppearance(to: window)
            }
        }
    }

    @MainActor func applyAppearance(to view: UIView) {
        if view.tintColor == UIColor(named: "Primary") { view.tintColor = .altPrimary }
        if view.backgroundColor == UIColor(named: "Primary") {
            view.backgroundColor = .altPrimary
            if let button = view as? UIButton {
                button.setTitleColor(UIColor.altPrimary.contrastingText, for: .normal)
            }
        }
        if let table = view as? UITableView {
            table.backgroundColor = .settingsBackground
            if table.delegate is SettingsViewController {
                // The storyboard table draws its own inset group separators.
                table.separatorStyle = .none
            } else if table.style != .plain {
                table.separatorStyle = .singleLine
            }
        }
        if let collection = view as? UICollectionView { collection.backgroundColor = .settingsBackground }
        // Native grouped tables own their group clipping and separators. A
        // rounded background on every cell breaks those continuous sections.
        if let cell = view as? UITableViewCell, !(cell is InsetGroupTableViewCell) {
            if cell.backgroundView is UIVisualEffectView { cell.backgroundView = nil }
            cell.backgroundColor = .settingsCard
            cell.contentView.backgroundColor = .clear
        }
        if let field = view as? UITextField {
            if field.tag == AddSourceTextFieldCell.sourceURLFieldTag {
                // The source input uses its parent card, matching native form rows.
                field.backgroundColor = .clear
                field.textColor = .label
                field.viewWithTag(77500)?.removeFromSuperview()
            } else {
                field.backgroundColor = .settingsField
                field.textColor = .label
                field.viewWithTag(77500)?.removeFromSuperview()
            }
        }
        if let image = view as? UIImageView, image.tag == 77023 {
            image.tintColor = .settingsSymbol
        }
        view.setNeedsDisplay()
        for child in view.subviews { applyAppearance(to: child) }
    }
}

// Shared monochrome symbols for Settings entries across UIKit and SwiftUI.
enum SettingsEntrySymbol {
    static func name(for title: String) -> String {
        let entries: [(String, String)] = [
            ("Signing Identities", "signature"),
            ("Apple Developer Portal", "hammer.circle"),
            ("Name", "person"),
            ("Email", "envelope"),
            ("Type", "person.badge.shield.checkmark"),
            ("Change App Icon", "app"),
            ("Background Refresh", "arrow.clockwise"),
            ("Disable Idle Timeout", "lock.open"),
            ("Signed IPAs", "doc.zipper"),
            ("Save Resigned IPAs", "square.and.arrow.down"),
            ("Shortcuts", "square.stack.3d.up"),
            ("Health Check", "stethoscope"),
            ("View Error Log", "exclamationmark.triangle"),
            ("Storage Explorer", "internaldrive"),
            ("Clear Data Cache…", "trash"),
            ("Send Feedback", "bubble.left"),
            ("View Refresh Attempts", "clock.arrow.circlepath"),
            ("SideJITServer", "bolt"),
            ("Pairing File Management", "link"),
            ("Anisette Servers", "server.rack"),
            ("Connection Config", "network"),
            ("Network Discovery (mDNS)", "dot.radiowaves.left.and.right"),
            ("Profiles Management", "doc.text"),
            ("Certificate Management", "checkmark.seal"),
            ("Backup & Restore", "externaldrive"),
            ("User Customizations", "person.crop.circle"),
            ("Developer Options", "hammer"),
            ("Experimental Features", "flask"),
            ("Licenses", "doc.text"),
            ("About zynthec-dev", "person.crop.circle"),
            ("Main Repository", "chevron.left.forwardslash.chevron.right"),
            ("Based on SideStore", "heart"),
        ]
        if let entry = entries.first(where: { title == $0.0 || title == NSLocalizedString($0.0, comment: "") }) { return entry.1 }
        let text = title.lowercased()
        let rules: [(String, String)] = [
            ("user custom", "person.crop.circle"), ("personalis", "person.crop.circle"),
            ("darstellung", "paintpalette"), ("appearance", "paintpalette"),
            ("self-pair", "iphone"), ("wireless", "antenna.radiowaves.left.and.right"),
            ("pairing", "link"), ("signed ipa", "doc.zipper"), ("certificate", "checkmark.seal"),
            ("signing request", "doc.badge.plus"), ("private", "key.fill"), ("key", "key.horizontal"),
            ("app id", "app.badge"), ("appid", "app.badge"), ("provision", "doc.text"),
            ("profile", "person.crop.rectangle"), ("icloud", "icloud"), ("container", "shippingbox"),
            ("account", "person.crop.circle"), ("name", "person"), ("email", "envelope"), ("type", "person.badge.shield.checkmark"),
            ("icon", "app"), ("theme", "paintpalette"), ("accent", "paintpalette"),
            ("background", "arrow.trianglehead.2.clockwise.rotate.90"), ("refresh", "arrow.clockwise"),
            ("idle", "lock.open"), ("siri", "waveform"), ("shortcut", "square.stack.3d.up"),
            ("tunnel", "network"), ("vpn", "network"), ("connection", "network"), ("network", "network"),
            ("bonjour", "dot.radiowaves.left.and.right"), ("jit", "bolt"), ("anisette", "person.badge.key"),
            ("sign", "signature"), ("entitlement", "checkmark.shield"), ("capabilit", "checkmark.shield"),
            ("extension", "puzzlepiece.extension"), ("plist", "list.bullet.rectangle"),
            ("source", "tray.full"), ("import", "square.and.arrow.down"), ("export", "square.and.arrow.up"),
            ("download", "arrow.down.circle"), ("install", "arrow.down.app"), ("cache", "internaldrive"),
            ("storage", "internaldrive"), ("backup", "externaldrive"), ("database", "externaldrive"),
            ("delete", "trash"), ("reset", "arrow.counterclockwise"), ("log", "list.bullet.rectangle"),
            ("error", "exclamationmark.triangle"), ("diagnostic", "stethoscope"), ("debug", "ladybug"),
            ("feedback", "bubble.left"), ("about", "info.circle"), ("license", "doc.text"),
            ("repository", "chevron.left.forwardslash.chevron.right"), ("sidestore", "heart"),
            ("app", "square.stack"), ("device", "iphone"), ("service", "server.rack")
        ]
        return rules.first { text.contains($0.0) }?.1 ?? "gearshape"
    }
}

private struct SettingsEntryIconsKey: EnvironmentKey {
    static let defaultValue = false
}
extension EnvironmentValues {
    var settingsEntryIconsVisible: Bool {
        get { self[SettingsEntryIconsKey.self] }
        set { self[SettingsEntryIconsKey.self] = newValue }
    }
}

/// Ordinary submenu labels stay text-only; certificate tools opt into meaningful icons.
struct SettingsEntryLabel: View {
    let title: String
    var systemImage: String? = nil
    @Environment(\.settingsEntryIconsVisible) private var showsIcons
    var body: some View {
        HStack(spacing: 12) {
            if showsIcons {
                Image(systemName: systemImage ?? SettingsEntrySymbol.name(for: title))
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Color(uiColor: .settingsSymbol))
                    .frame(width: 24, height: 24)
            }
            Text(LocalizedStringKey(title))
        }
    }
}

/// Apply at each Settings destination, including separately presented sheets.
/// A hosting root's background does not automatically cover a modal's surface.
extension View {
    func zLoaderSettingsPage() -> some View {
        self
            .environment(\.zLoaderUsesGlass, false)
            .environment(\.defaultMinListRowHeight, 44)
            .font(.body)
            #if os(tvOS)
            .listStyle(.grouped)
            #else
            .listStyle(.insetGrouped)
            #endif
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .settingsBackground).ignoresSafeArea())
    }
}
