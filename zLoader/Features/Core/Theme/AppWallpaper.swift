import SwiftUI
import UIKit
import ImageIO

enum WallpaperMode: String, CaseIterable, Identifiable {
    case both, light, dark
    var id: String { rawValue }
    var title: LocalizedStringKey {
        switch self { case .both: "Both"; case .light: "Light"; case .dark: "Dark" }
    }
}

extension ThemeManager {
    private var wallpaperDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Appearance", isDirectory: true)
    }

    func wallpaper(for style: UIUserInterfaceStyle) -> UIImage? {
        let key = style == .dark ? "dark" : "light"
        if let image = wallpaperImages[key] { return image }
        guard let image = UIImage(contentsOfFile: wallpaperDirectory.appendingPathComponent(key + ".jpg").path) else { return nil }
        wallpaperImages[key] = image
        return image
    }

    @MainActor func importWallpaper(_ data: Data, for mode: WallpaperMode) throws {
        guard data.count <= 30 * 1024 * 1024,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 2400
              ] as CFDictionary),
              let encoded = UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.9) else {
            throw OperationError.invalidParameters(NSLocalizedString("Choose a readable image smaller than 30 MB.", comment: ""))
        }
        try FileManager.default.createDirectory(at: wallpaperDirectory, withIntermediateDirectories: true)
        for key in mode == .both ? ["light", "dark"] : [mode.rawValue] {
            try encoded.write(to: wallpaperDirectory.appendingPathComponent(key + ".jpg"), options: .atomic)
            wallpaperImages[key] = UIImage(cgImage: cgImage)
        }
        wallpaperRevision += 1
        refreshVisibleAppearance()
    }

    @MainActor func removeWallpaper(for mode: WallpaperMode) throws {
        for key in mode == .both ? ["light", "dark"] : [mode.rawValue] {
            let url = wallpaperDirectory.appendingPathComponent(key + ".jpg")
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
            wallpaperImages.removeValue(forKey: key)
        }
        wallpaperRevision += 1
        refreshVisibleAppearance()
    }
}

struct ZLoaderAppBackground: View {
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
            if let image = theme.wallpaper(for: colorScheme == .dark ? .dark : .light) {
                Image(uiImage: image).resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height).clipped()
            } else {
                Color(uiColor: .settingsBackground)
            }
        }.ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
    }
}
