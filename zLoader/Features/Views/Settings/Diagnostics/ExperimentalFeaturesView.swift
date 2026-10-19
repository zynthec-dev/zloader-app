//
//  ExperimentalFeaturesView.swift
//  ZLoader
//
//  Created by Magesh K on 8/2/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI

extension Color {
    fileprivate static var settingsRowBackground: Color { Color(uiColor: .settingsCard) }
    fileprivate static var settingsDivider: Color { Color(uiColor: .separator) }
}

struct ExperimentalFeaturesView: View {
    @State private var isMinimuxerBackendHotswapEnabled: Bool = UserDefaults.standard.isMinimuxerBackendHotswapEnabled

    var body: some View {
        List {

            // Section 2: MINIMUXER
            Section {

                toggleRow(
                    title: "Enable Minimuxer Backend Hotswap",
                    isOn: Binding(
                        get: { isMinimuxerBackendHotswapEnabled },
                        set: { newValue in
                            isMinimuxerBackendHotswapEnabled = newValue
                            UserDefaults.standard.isMinimuxerBackendHotswapEnabled = newValue
                        }
                    ))

            } header: {
                Text("MINIMUXER")

            }.zLoaderSettingsRows()

        }
        .background(Color(uiColor: .settingsBackground))
        .navigationTitle("Experimental Features")
        .zLoaderSettingsPage()
        .labelStyle(.titleAndIcon)
        #if !os(tvOS)
            .navigationBarTitleDisplayMode(.large)
        #endif
    }

    private func toggleRow(title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) { SettingsEntryLabel(title: title) }
            .tint(Color(uiColor: .altPrimary))
    }

}
