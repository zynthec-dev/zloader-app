import CoreData

@main struct ContextConfinementTests {
    static func main() async throws {
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
        // An installation result is saved in a private context. Deliver a
        // distinct main-context object, then fault/read it with concurrency
        // assertions enabled to catch regressions in the real Core Data API.
        let model = NSManagedObjectModel()
        let entity = NSEntityDescription()
        entity.name = "InstalledFixture"
        entity.managedObjectClassName = "NSManagedObject"
        let name = NSAttributeDescription()
        name.name = "name"
        name.attributeType = .stringAttributeType
        entity.properties = [name]
        model.entities = [entity]
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        _ = try coordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil)
        let writer = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        writer.persistentStoreCoordinator = coordinator
        let ui = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        ui.persistentStoreCoordinator = coordinator
        let saved = try await writer.perform {
            let app = NSEntityDescription.insertNewObject(forEntityName: "InstalledFixture", into: writer)
            app.setValue("Installed third-party app", forKey: "name")
            try writer.save()
            return app
        }
        let id = try await writer.persistedObjectID(for: saved)
        let value = try await MainActor.run {
            let visible = try ui.existingMainActorObject(with: id, as: NSManagedObject.self)
            precondition(visible !== saved && visible.managedObjectContext === ui)
            ui.refresh(visible, mergeChanges: false)
            return visible.value(forKey: "name") as? String
        }
        precondition(value == "Installed third-party app")
        let unsaved = await writer.perform { NSEntityDescription.insertNewObject(forEntityName: "InstalledFixture", into: writer) }
        do {
            _ = try await writer.persistedObjectID(for: unsaved)
            preconditionFailure("An unsaved installation must not be reported as a visible successful app")
        } catch { precondition((error as NSError).domain == "zLoader.ManagedObjectHandoff") }
        print("PASS saved installation crosses queues by permanent ID; UI faults/read uses its own instance; unsaved results rejected")
        print("PASS context-confined reads/writes, queued completion and error propagation")
    }
}
