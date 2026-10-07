import SwiftUI
import UIKit

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }
    var title: LocalizedStringKey {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system, english = "en", german = "de"

    var id: String { rawValue }
    var title: LocalizedStringKey {
        switch self {
        case .system: "System"
        case .english: "English"
        case .german: "Deutsch"
        }
    }

    // UIKit storyboards, alerts and App Intents resolve their language at launch.
    // Keep SwiftUI in the same language until the next launch; never tear down
    // signing, pairing or installation just to change the interface language.
    static let launchLocale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")

    static var selected: Self {
        Self(rawValue: UserDefaults.standard.string(forKey: "zLoader.language") ?? "system") ?? .system
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: "zLoader.language")
        if self == .system {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([rawValue], forKey: "AppleLanguages")
        }
    }
}
