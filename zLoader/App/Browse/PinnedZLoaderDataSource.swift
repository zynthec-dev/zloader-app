@preconcurrency import UIKit
import CoreData

/// Pins the canonical store entry without changing the catalogue's persisted order.
/// All app actions and icon prefetches resolve through this same index mapping.
final class PinnedZLoaderDataSource: FetchedResultsCollectionViewPrefetchingDataSource<StoreApp, UIImage> {
    private var pinnedIndex: Int? {
        fetchedResultsController.fetchedObjects?.firstIndex {
            $0.bundleIdentifier == "com.zynthec.zLoader" && $0.sourceIdentifier == Source.zLoaderIdentifier
        }
    }

    override func item(at indexPath: IndexPath) -> StoreApp {
        guard indexPath.section == 0, let pinned = pinnedIndex else { return super.item(at: indexPath) }
        let item = indexPath.item == 0 ? pinned : (indexPath.item <= pinned ? indexPath.item - 1 : indexPath.item)
        return super.item(at: IndexPath(item: item, section: 0))
    }

    func displayedIndexPath(for app: StoreApp) -> IndexPath? {
        guard let index = fetchedResultsController.indexPath(forObject: app) else { return nil }
        guard index.section == 0, let pinned = pinnedIndex else { return index }
        let item = index.item == pinned ? 0 : (index.item < pinned ? index.item + 1 : index.item)
        return IndexPath(item: item, section: 0)
    }

    // FRC changes refer to its original order. Reload a snapshot rather than apply
    // those positions to a list whose first item has been moved to the front.
    override func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {}
    override func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any,
                             at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {}
    override func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo,
                             atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {}
    override func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        itemCount = fetchedResultsController.fetchedObjects?.count ?? 0
        contentView?.reloadData()
    }
}
