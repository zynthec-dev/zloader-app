import Foundation

/// Synthetic, shared app-visible identity. Never represents an Apple-attested
/// device, real serial, advertising permission, or provisioning device ID.
struct LCVirtualDeviceIdentity: Codable, Equatable {
    var modelName: String
    var hardwareIdentifier: String
    var deviceName: String
    var serialNumber: String
    var vendorIdentifier: UUID
    var syntheticDeviceIdentifier: String

    static func generate() -> Self {
        Self(modelName: "iPhone 16 Pro Max", hardwareIdentifier: "iPhone17,2", deviceName: "iPhone",
             serialNumber: String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12)),
             vendorIdentifier: UUID(), syntheticDeviceIdentifier:
                UUID().uuidString.replacingOccurrences(of: "-", with: "") + String(UUID().uuidString.prefix(8)))
    }

    var dictionary: [String: Any] {
        ["modelName": modelName, "hardwareIdentifier": hardwareIdentifier, "deviceName": deviceName,
         "serialNumber": serialNumber, "vendorIdentifier": vendorIdentifier.uuidString,
         "syntheticDeviceIdentifier": syntheticDeviceIdentifier]
    }
    init?(dictionary: [String: Any]) {
        guard let data = try? PropertyListSerialization.data(fromPropertyList: dictionary, format: .binary, options: 0),
              let value = try? PropertyListDecoder().decode(Self.self, from: data) else { return nil }
        self = value
    }
    init(modelName: String, hardwareIdentifier: String, deviceName: String, serialNumber: String,
         vendorIdentifier: UUID, syntheticDeviceIdentifier: String) {
        self.modelName = modelName; self.hardwareIdentifier = hardwareIdentifier; self.deviceName = deviceName
        self.serialNumber = serialNumber; self.vendorIdentifier = vendorIdentifier
        self.syntheticDeviceIdentifier = syntheticDeviceIdentifier
    }
}
