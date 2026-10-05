import CoreData

@main struct ContextConfinementTests {
    static func main() async {
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        let object = context.performAndWait {
            let entity = NSEntityDescription()
            entity.name = "Fixture"
            entity.managedObjectClassName = "NSManagedObject"
            let value = NSAttributeDescription()
            value.name = "value"
            value.attributeType = .stringAttributeType
            entity.properties = [value]
            return NSManagedObject(entity: entity, insertInto: context)
        }
        let initial = await context.performWithObject(object) { object in
            object.setValue("first", forKey: "value")
            return object.value(forKey: "value") as? String
        }
        precondition(initial == "first")
        await withCheckedContinuation { continuation in
            context.enqueueWithObject(object) { object in
                object.setValue("queued", forKey: "value")
                continuation.resume()
            }
        }
        let queued = await context.performWithObject(object) { $0.value(forKey: "value") as? String }
        precondition(queued == "queued")
        do {
            _ = try await context.performWithObject(object) { _ -> String in throw NSError(domain: "Fixture", code: 1) }
            fatalError("Expected error propagation")
        } catch { precondition((error as NSError).code == 1) }
        print("PASS context-confined reads/writes, queued completion and error propagation")
    }
}
