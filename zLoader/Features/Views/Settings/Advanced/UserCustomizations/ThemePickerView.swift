// Created by Magesh K on 9/8/26.
// Copyright © 2026 SideStore. All rights reserved.
import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ThemePickerView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @State private var selectedColor = Color(uiColor: ThemeManager.shared.primaryColor)
    @State private var selectedLanguage = AppLanguage.selected
    @State private var wallpaperMode: WallpaperMode = .both
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var importsWallpaper = false
    @State private var wallpaperError: String?
    @State private var showsLanguageRestart = false

    var body: some View {
        Form {
            Section("Appearance") {
                Picker(selection: $theme.appearance) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appearance.title).tag(appearance)
                    }
                } label: {
                    SettingsEntryLabel(title: "Appearance", systemImage: "circle.lefthalf.filled")
                }
                .pickerStyle(.menu)
            }.listRowBackground(ZLoaderGlassBackground())
            Section {
                ColorPicker("Accent Color", selection: $selectedColor, supportsOpacity: false)
            } footer: {
                Text("Used for buttons, switches and selections throughout zLoader. Backgrounds and text follow the system Light and Dark appearance.")
            }.listRowBackground(ZLoaderGlassBackground())
            Section {
                ColorPicker("Symbol Color", selection: Binding(
                    get: { Color(uiColor: theme.symbolColor) },
                    set: { theme.customSymbolColor = UIColor($0) }
                ), supportsOpacity: false)
                if theme.customSymbolColor != nil {
                    SwiftUI.Button("Use Accent Color for Symbols") { theme.customSymbolColor = nil }
                }
                ColorPicker("Text Field Background", selection: Binding(
                    get: { Color(uiColor: theme.fieldColor) },
                    set: { theme.customFieldColor = UIColor($0) }
                ), supportsOpacity: false)
                if theme.customFieldColor != nil {
                    SwiftUI.Button("Use System Text Field Background") { theme.customFieldColor = nil }
                }
            } footer: {
                Text("Symbol and text field colors are independent of the accent color. Resetting text fields to System restores their automatic Light and Dark appearance.")
            }.listRowBackground(ZLoaderGlassBackground())
            wallpaperSection
            presetsSection
            Section {
                Picker(selection: $selectedLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                } label: {
                    SettingsEntryLabel(title: "Language", systemImage: "globe")
                }
                .pickerStyle(.menu)
            } footer: {
                Text("System follows your preferred iOS language. English is used when that language is not supported. Language changes take effect the next time you fully close and reopen zLoader.")
            }.listRowBackground(ZLoaderGlassBackground())
        }
        .fileImporter(isPresented: $importsWallpaper, allowedContentTypes: [.image]) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                try theme.importWallpaper(Data(contentsOf: url), for: wallpaperMode)
            } catch { wallpaperError = error.localizedDescription }
        }
        .onChange(of: selectedPhoto) { _, photo in
            let mode = wallpaperMode
            Task { @MainActor in
                do {
                    guard let data = try await photo?.loadTransferable(type: Data.self) else { return }
                    try theme.importWallpaper(data, for: mode)
                } catch { wallpaperError = error.localizedDescription }
                selectedPhoto = nil
            }
        }
        .alert("Background Image", isPresented: Binding(get: { wallpaperError != nil }, set: { if !$0 { wallpaperError = nil } })) {
            SwiftUI.Button("OK", role: .cancel) { wallpaperError = nil }
        } message: { Text(verbatim: wallpaperError ?? "") }
        .navigationTitle("Appearance")
        .labelStyle(.titleOnly)
        .onChange(of: selectedLanguage) { _, language in
            language.save()
            showsLanguageRestart = true
        }
        .alert("Language Changed", isPresented: $showsLanguageRestart) {
            SwiftUI.Button("OK", role: .cancel) { }
        } message: {
            Text("Finish any running operation, then fully close and reopen zLoader to apply the selected language.")
        }
        .onChange(of: selectedColor) { _, color in
            let chosen = UIColor(color)
            // Selecting a dynamic preset must not flatten its Light/Dark variants.
            if chosen.hexString.uppercased() != theme.primaryColor.hexString.uppercased() {
                theme.primaryColor = chosen
            }
        }
        .tint(Color(uiColor: theme.primaryColor))
    }
    private var presetsSection: some View {
            Section("Presets") {
                ForEach(ThemePreset.presets) { preset in
                    SwiftUI.Button {
                        theme.primaryColor = preset.color
                        selectedColor = Color(uiColor: preset.color)
                    } label: {
                        HStack {
                            Circle().fill(Color(uiColor: preset.color)).frame(width: 22, height: 22)
                            Text(LocalizedStringKey(preset.name)).foregroundStyle(.primary)
                            Spacer()
                            if theme.primaryColor.hexString.uppercased() == preset.color.hexString.uppercased() {
                                Image(systemName: "checkmark").foregroundStyle(Color(uiColor: .altPrimary))
                            }
                        }
                    }
                }
            }.listRowBackground(ZLoaderGlassBackground())
    }

    private var wallpaperSection: some View {
            Section {
                Picker("Background Mode", selection: $wallpaperMode) {
                    ForEach(WallpaperMode.allCases) { mode in Text(mode.title).tag(mode) }
                }.pickerStyle(.segmented)
                #if !os(tvOS)
                PhotosPicker("Choose from Photos", selection: $selectedPhoto, matching: .images)
                #endif
                SwiftUI.Button("Choose from Files") { importsWallpaper = true }
                SwiftUI.Button("Remove Background", role: .destructive) {
                    do { try theme.removeWallpaper(for: wallpaperMode) }
                    catch { wallpaperError = error.localizedDescription }
                }
            } header: {
                Text("App Background")
            } footer: {
                Text("Both uses the same image in Light and Dark. Choose Light or Dark to change only that background. Images are stored locally on this device.")
            }.listRowBackground(ZLoaderGlassBackground())
    }

}
