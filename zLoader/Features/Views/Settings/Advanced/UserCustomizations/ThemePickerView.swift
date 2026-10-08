// Created by Magesh K on 9/8/26.
// Copyright © 2026 SideStore. All rights reserved.
import SwiftUI

struct ThemePickerView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @State private var selectedColor = Color(uiColor: ThemeManager.shared.primaryColor)
    @State private var selectedLanguage = AppLanguage.selected
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
                Group {
                    Text("Used for buttons, switches and selections throughout zLoader. Backgrounds and text follow the system Light and Dark appearance.")
                }
            }.listRowBackground(ZLoaderGlassBackground())
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
                Group {
                    Text("System follows your preferred iOS language. English is used when that language is not supported. Language changes take effect the next time you fully close and reopen zLoader.")
                }
            }.listRowBackground(ZLoaderGlassBackground())
        }
        .navigationTitle("Appearance")
        .zLoaderSettingsPage()
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

}
