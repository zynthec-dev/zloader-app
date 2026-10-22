import CoreData

/// Retains an object only to hand it back to its own context queue. This does
/// not make managed objects Sendable; callers must use the parameter only
/// inside the context's perform block. Needs proper device stress testing.
private final class ContextConfinedObject<Object: NSManagedObject>: @unchecked Sendable {
    let object: Object
    init(_ object: Object) { self.object = object }
}

extension NSManagedObjectContext {
    func performWithObject<Object: NSManagedObject, Result>(
        _ object: Object,
        _ work: @escaping @Sendable (Object) throws -> Result
    ) async rethrows -> Result {
        let reference = ContextConfinedObject(object)
        return try await perform {
            precondition(reference.object.managedObjectContext === self)
            return try work(reference.object)
        }
    }
}

extension NSManagedObjectContext {
    func enqueueWithObject<Object: NSManagedObject>(
        _ object: Object,
        _ work: @escaping @Sendable (Object) -> Void
    ) {
        let reference = ContextConfinedObject(object)
        perform {
            precondition(reference.object.managedObjectContext === self)
            work(reference.object)
        }
    }
}

/// Transfer only persistent identity across queues. The receiving UI must obtain
/// its own instance instead of reading the private-context object on MainActor.
extension NSManagedObjectContext {
    func persistedObjectID<Object: NSManagedObject>(for object: Object) async throws -> NSManagedObjectID {
        try await performWithObject(object) { object in
            guard !object.isDeleted, !object.objectID.isTemporaryID else {
                throw NSError(domain: "zLoader.ManagedObjectHandoff", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "The installation result has not been saved."])
            }
            return object.objectID
        }
    }

    @MainActor
    func existingMainActorObject<Object: NSManagedObject>(with id: NSManagedObjectID, as type: Object.Type) throws -> Object {
        precondition(concurrencyType == .mainQueueConcurrencyType)
        guard let object = try existingObject(with: id) as? Object else {
            throw NSError(domain: "zLoader.ManagedObjectHandoff", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "The saved installation result has an unexpected type."])
        }
        return object
    }
}
