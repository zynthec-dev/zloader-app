import SwiftUI

/// Native glass follows the system's material and accessibility settings.
/// Earlier systems keep standard buttons and opaque, legible grouped surfaces.
struct ZLoaderGlassButtonStyle: PrimitiveButtonStyle {
    var prominent = false

    @ViewBuilder func makeBody(configuration: Configuration) -> some View {
        if #available(iOS 26.0, tvOS 26.0, *) {
            if prominent {
                SwiftUI.Button(role: configuration.role, action: configuration.trigger) { configuration.label }
                    .buttonStyle(.glassProminent)
            } else {
                SwiftUI.Button(role: configuration.role, action: configuration.trigger) { configuration.label }
                    .buttonStyle(.glass)
            }
        } else {
            if prominent {
                SwiftUI.Button(role: configuration.role, action: configuration.trigger) { configuration.label }
                    .buttonStyle(.borderedProminent)
            } else {
                SwiftUI.Button(role: configuration.role, action: configuration.trigger) { configuration.label }
                    .buttonStyle(.bordered)
            }
        }
    }
}

private struct ZLoaderGlassSurface: ViewModifier {
    var cornerRadius: CGFloat
    var interactive: Bool
    var prominent: Bool

    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 26.0, tvOS 26.0, *) {
            if prominent {
                content.glassEffect(.regular.tint(.accentColor).interactive(), in: .rect(cornerRadius: cornerRadius))
            } else if interactive {
                content.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
            } else {
                content.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            content.background(prominent ? Color.accentColor : Color(uiColor: .settingsCard), in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}

extension View {
    func zLoaderGlassSurface(cornerRadius: CGFloat = 16, interactive: Bool = false, prominent: Bool = false) -> some View {
        modifier(ZLoaderGlassSurface(cornerRadius: cornerRadius, interactive: interactive, prominent: prominent))
    }
}

struct ZLoaderGlassGroup<Content: View>: View {
    @ViewBuilder var content: () -> Content

    @ViewBuilder var body: some View {
        if #available(iOS 26.0, tvOS 26.0, *) {
            GlassEffectContainer(spacing: 12) { content() }
        } else {
            content()
        }
    }
}

/// Shared row/field material. UIKit renders it according to OS glass preferences.
struct ZLoaderGlassBackground: UIViewRepresentable {
    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView()
        view.isUserInteractionEnabled = false
        updateUIView(view, context: context)
        return view
    }

    func updateUIView(_ view: UIVisualEffectView, context: Context) {
        #if !os(tvOS)
        if #available(iOS 26.0, *) {
            view.effect = UIGlassEffect(style: .regular)
            view.backgroundColor = .clear
        } else {
            view.effect = nil
            view.backgroundColor = .settingsCard
        }
        #else
        view.effect = nil
        view.backgroundColor = .settingsCard
        #endif
    }
}
