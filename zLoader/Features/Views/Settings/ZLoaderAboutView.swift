import SwiftUI

enum ZLoaderBrand {
    static let maintainer = "zynthec-dev"
    static let repositoryURL = URL(string: "https://github.com/zynthec-dev/zLoader-ios")!
    static let upstreamURL = URL(string: "https://github.com/SideStore/SideStore")!
}

struct ZLoaderAboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                identity
                VStack(alignment: .leading, spacing: 12) {
                    Text("Maintained by \(ZLoaderBrand.maintainer)").font(.headline)
                    Link("zLoader Repository", destination: ZLoaderBrand.repositoryURL)
                    Link("Based on SideStore", destination: ZLoaderBrand.upstreamURL)
                    Text("Original design credits: Fabian (thdev) and Chris (LitRitt). SideStore and AltStore authors retain their original credits and copyrights. zLoader includes Minimuxer, SideSign and their dependencies.")
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Local device transport").font(.headline)
                    Text("The embedded packet tunnel uses the StosVPN / LocalDevVPN loopback design. Original authors: Stossy11, the SideStore Team and jkcoxson.")
                        .foregroundStyle(.secondary)
                    Link("LocalDevVPN source", destination: URL(string: "https://github.com/jkcoxson/LocalDevVPN")!)
                    Text("Requires eligible Network Extension provisioning for the app and extension. Cellular-only installation and refresh require physical-device verification.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                ForEach(["SideStore-License", "LocalDevVPN-License", "LocalDevVPN-License-old"], id: \.self) { name in
                    DisclosureGroup(name) {
                        Text(license(name)).font(.caption).textSelection(.enabled)
                    }
                }
            }
            .padding(24)
        }
        .background(Color(uiColor: .altBackground))
        .navigationTitle("About zLoader")
    }

    @ViewBuilder private var identity: some View {
        let content = VStack(alignment: .leading, spacing: 8) {
            Text("zLoader").font(.largeTitle.bold())
            Text(Bundle.Info.activeBundleVersion).font(.subheadline).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(24)
        if #available(iOS 26, tvOS 26, *) {
            content.glassEffect(.regular.tint(Color(uiColor: .altPrimary).opacity(0.15)), in: .rect(cornerRadius: 24))
        } else {
            content.background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
        }
    }

    private func license(_ name: String) -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "License text unavailable in this build. See the corresponding project repository."
        }
        return text
    }
}
