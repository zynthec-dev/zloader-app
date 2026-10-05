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
