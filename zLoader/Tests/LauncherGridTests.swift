import UIKit
import CoreData
final class FlatLauncher: CompositeCollectionViewPrefetchingDataSource<String, UIImage> {
    override var isDynamic: Bool { true }
}
@main struct LauncherGridTests {
    @MainActor static func main() {
        let view = UICollectionView(frame: CGRect(x: 0, y: 0, width: 390, height: 600), collectionViewLayout: UICollectionViewFlowLayout())
        let existing = ArrayCollectionViewDataSource<String>(items: ["installed"])
        var pending = ["pending"]
        let transient = DynamicCollectionViewDataSource<String>()
        transient.numberOfSectionsHandler = { 1 }
        transient.numberOfItemsHandler = { _ in pending.count }
        let flat = FlatLauncher(dataSources: [existing, transient])
        flat.shouldFlattenSections = true
        let before = ArrayCollectionViewDataSource<String>(items: [])
        let outer = CompositeCollectionViewPrefetchingDataSource<String, UIImage>(dataSources: [before, flat])
        outer.contentView = view
        precondition((outer as UICollectionViewDataSource).numberOfSections!(in: view) == 2)

        precondition(outer.contentView(view, numberOfItemsInSection: 1) == 2)
        var configured = false
        transient.dynamicCellConfigurationHandler = { _, path in configured = path.item == 0 }
        outer.configureCell(UICollectionViewCell(), at: IndexPath(item: 1, section: 1))
        precondition(configured)
        precondition(existing.localIndexPath(for: IndexPath(item: 0, section: 1)) == IndexPath(item: 0, section: 0))
        // Completing an install swaps the transient tile for a permanent record.
        existing.items = ["installed", "completed"]
        pending = []
        precondition(outer.contentView(view, numberOfItemsInSection: 1) == 2)
        print("PASS flattened pending counts and cell configuration")
    }
}
