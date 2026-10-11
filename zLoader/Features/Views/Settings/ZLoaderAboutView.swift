import SwiftUI

enum ZLoaderBrand {
    static let maintainer = "zynthec-dev"
    static let repositoryURL = URL(string: "https://github.com/zynthec-dev/zloader-app")!
    static let upstreamURL = URL(string: "https://github.com/SideStore/SideStore")!
}

struct ZLoaderAboutView: View {
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("zLoader").font(.title.bold())
                    Text(Bundle.Info.activeBundleVersion).foregroundStyle(.secondary)
                    Text("Independently maintained by " + ZLoaderBrand.maintainer)
                        .font(.footnote).foregroundStyle(.secondary)
                }.padding(.vertical, 8)
                Link(destination: URL(string: "https://github.com/zynthec-dev")!) {
                    SettingsEntryLabel(title: "About zynthec-dev")
                }
                Link(destination: ZLoaderBrand.repositoryURL) {
                    SettingsEntryLabel(title: "Main Repository")
                }
            }.listRowBackground(ZLoaderGlassBackground())
            Section("Local Device Transport") {
                Text("Use a compatible external local VPN tunnel. Export a local tunnel configuration for WireGuard from onboarding or Connection Settings.")
                Text("WireGuard runs the VPN in its own app. zLoader provides the local loopback peer while running; no integrated VPN extension is included.")
                    .font(.footnote).foregroundStyle(.secondary)
            }.listRowBackground(ZLoaderGlassBackground())
            Section("Original Authors & Licenses") {
                Text("SideStore and AltStore authors retain their original credits and copyrights. Original design: Fabian (thdev) and Chris (LitRitt). Local transport work: Stossy11, the SideStore Team and jkcoxson. zLoader includes Minimuxer, SideSign and their dependencies.")
                    .font(.footnote).foregroundStyle(.secondary)
                Link(destination: URL(string: "https://github.com/jkcoxson/LocalDevVPN")!) {
                    SettingsEntryLabel(title: "Original Local Tunnel Source")
                }
                ForEach([("SideStore-License", "SideStore License"),
                         ("LocalDevVPN-License", "Original Local Tunnel License"),
                         ("LocalDevVPN-License-old", "Original Local Tunnel License (Earlier Version)")], id: \.0) { name, title in
                    DisclosureGroup {
                        Text(license(name)).font(.caption).textSelection(.enabled)
                    } label: {
                        SettingsEntryLabel(title: title)
                    }
                }
            }.listRowBackground(ZLoaderGlassBackground())
            Section {
                Link(destination: ZLoaderBrand.upstreamURL) {
                    SettingsEntryLabel(title: "Based on SideStore")
                }
            }.listRowBackground(ZLoaderGlassBackground())
        }
        .navigationTitle("About zynthec-dev")
        .zLoaderSettingsPage()
        .labelStyle(.titleOnly)
    }

    private func license(_ name: String) -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "License text unavailable in this build. See the corresponding project repository."
        }
        return text
    }
}
