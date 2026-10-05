import SwiftUI

extension View {
    @ViewBuilder
    func onValueChange<Value: Equatable>(of value: Value, perform action: @escaping (Value) -> Void) -> some View {
        if #available(iOS 17, tvOS 17, *) {
            onChange(of: value) { _, newValue in action(newValue) }
        } else {
            legacyValueChange(of: value, perform: action)
        }
    }

    @available(iOS, introduced: 15, deprecated: 17)
    @available(tvOS, introduced: 15, deprecated: 17)
    private func legacyValueChange<Value: Equatable>(of value: Value, perform action: @escaping (Value) -> Void) -> some View {
        onChange(of: value, perform: action)
    }
}
