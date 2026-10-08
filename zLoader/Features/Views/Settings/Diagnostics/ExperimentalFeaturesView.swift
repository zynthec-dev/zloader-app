//
//  ExperimentalFeaturesView.swift
//  ZLoader
//
//  Created by Magesh K on 8/2/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI

private extension Color {
    static var settingsRowBackground: Color { Color(uiColor: .settingsCard) }
    static var settingsDivider: Color { Color(uiColor: .separator) }
}

struct ExperimentalFeaturesView: View {
    @State private var isMinimuxerBackendHotswapEnabled: Bool = UserDefaults.standard.isMinimuxerBackendHotswapEnabled

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Section 2: MINIMUXER
                VStack(alignment: .leading, spacing: 8) {
                    Text("MINIMUXER")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.secondary)
                        .padding(.horizontal, 16)
                    
                    VStack(spacing: 0) {
                        toggleRow(title: "Enable Minimuxer Backend Hotswap", isOn: Binding(
                            get: { isMinimuxerBackendHotswapEnabled },
                            set: { newValue in
                                isMinimuxerBackendHotswapEnabled = newValue
                                UserDefaults.standard.isMinimuxerBackendHotswapEnabled = newValue
                            }
                        ))
                    }
                    .zLoaderGlassSurface()
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(Color(uiColor: .settingsBackground))
        .navigationTitle("Experimental Features")
        .zLoaderSettingsPage()
        .labelStyle(.titleOnly)
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }

    private func toggleRow(title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            SettingsEntryLabel(title: title)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color(uiColor: .altPrimary))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(minHeight: 44)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.settingsDivider)
            .frame(height: 1)
            .padding(.leading, 16)
    }
}
