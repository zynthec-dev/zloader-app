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

/// Shared native material for SwiftUI lists and UIKit cards.
struct ZLoaderGlassBackground: UIViewRepresentable {
    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView()
        view.isUserInteractionEnabled = false
        view.layer.cornerRadius = 20
        view.clipsToBounds = true
        updateUIView(view, context: context)
        return view
    }

    func updateUIView(_ view: UIVisualEffectView, context: Context) {
        ZLoaderCardMaterial.apply(to: view)
    }
}

@MainActor enum ZLoaderCardMaterial {
    static func install(in view: UIView, cornerRadius: CGFloat = 22) {
        let glass = (view.viewWithTag(77544) as? UIVisualEffectView) ?? UIVisualEffectView()
        if glass.superview == nil {
            glass.tag = 77544
            glass.isUserInteractionEnabled = false
            glass.frame = view.bounds
            glass.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.insertSubview(glass, at: 0)
        }
        glass.layer.cornerRadius = cornerRadius
        glass.clipsToBounds = true
        view.backgroundColor = .clear
        apply(to: glass)
    }

    static func apply(to view: UIVisualEffectView) {
        #if !os(tvOS)
        if #available(iOS 26.0, *), !UIAccessibility.isReduceTransparencyEnabled {
            view.effect = UIGlassEffect(style: .regular)
            view.backgroundColor = .clear
        } else {
            view.effect = nil
            view.backgroundColor = .secondarySystemGroupedBackground
        }
        #else
        view.effect = nil
        view.backgroundColor = .secondarySystemGroupedBackground
        #endif
        view.contentView.backgroundColor = .clear
    }
}
