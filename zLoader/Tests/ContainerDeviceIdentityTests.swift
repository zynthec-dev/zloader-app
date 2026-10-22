import Foundation

@main struct ContainerDeviceIdentityTests {
    static func main() throws {
        let first = LCVirtualDeviceIdentity.generate()
        let second = LCVirtualDeviceIdentity.generate()
        precondition(first.modelName == "iPhone 16 Pro Max" && first.hardwareIdentifier == "iPhone17,2")
        precondition(first.serialNumber.count == 12 && first.syntheticDeviceIdentifier.count == 40)
        precondition(first.vendorIdentifier != second.vendorIdentifier && first.serialNumber != second.serialNumber)
        let storage = UserDefaults(suiteName: "zLoaderContainerIdentityTests." + UUID().uuidString)!
        storage.set(first.dictionary, forKey: "identity")
        let containerA = LCVirtualDeviceIdentity(dictionary: storage.dictionary(forKey: "identity")!)!
        let containerB = LCVirtualDeviceIdentity(dictionary: storage.dictionary(forKey: "identity")!)!
        precondition(containerA == containerB && containerA == first)
        storage.set(second.dictionary, forKey: "identity")
        precondition(LCVirtualDeviceIdentity(dictionary: storage.dictionary(forKey: "identity")!) == second)
        precondition(containerA == first, "Running guests keep a stable snapshot until restarted")
        precondition(LCVirtualDeviceIdentity(dictionary: [:]) == nil)
        storage.removeObject(forKey: "identity")
        print("PASS one shared identity for all containers, stable persistence, complete regeneration and immutable running snapshots")
    }
}
