import SwiftUI

/// Shared by the root UIKit settings table and every SwiftUI settings destination.
enum ZLoaderSettingsStyle {
    static let cardRadius: CGFloat = 28
    static let horizontalInset: CGFloat = 16
    static let rowPadding: CGFloat = 16
    static let rowSpacing: CGFloat = 8
    static let minimumRowHeight: CGFloat = 56
    static let symbolSize: CGFloat = 20
    static let symbolFrame: CGFloat = 24
    static let symbolLeading = horizontalInset + rowPadding
    static let titleLeading = symbolLeading + symbolFrame + 12
}

extension View {
    func zLoaderSettingsRows() -> some View {
        self
            .listRowInsets(
                EdgeInsets(
                    top: ZLoaderSettingsStyle.rowPadding,
                    leading: ZLoaderSettingsStyle.rowPadding,
                    bottom: ZLoaderSettingsStyle.rowPadding,
                    trailing: ZLoaderSettingsStyle.rowPadding)
            )
            .listRowSeparator(.hidden)
            .listRowBackground(
                RoundedRectangle(cornerRadius: ZLoaderSettingsStyle.cardRadius, style: .continuous)
                    .fill(Color(uiColor: .settingsCard)))
    }

    /// For explanatory cards in settings screens that contain scrollable previews.
    func zLoaderSettingsCard() -> some View {
        background(
            Color(uiColor: .settingsCard),
            in: RoundedRectangle(cornerRadius: ZLoaderSettingsStyle.cardRadius, style: .continuous))
    }
}

@MainActor enum ZLoaderSettingsTableStyle {
    static let tableTag = 77422

    static func apply(to table: UITableView) {
        table.tag = tableTag
        table.backgroundColor = .settingsBackground
        table.separatorStyle = .none
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = ZLoaderSettingsStyle.minimumRowHeight + ZLoaderSettingsStyle.rowSpacing
    }

    static func contains(_ cell: UITableViewCell) -> Bool {
        var parent = cell.superview
        while let view = parent {
            if let table = view as? UITableView { return table.tag == tableTag }
            parent = view.superview
        }
        return false
    }

    static func apply(to cell: UITableViewCell) {
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        cell.backgroundConfiguration = background(for: cell)
        if cell.configurationUpdateHandler == nil {
            cell.configurationUpdateHandler = { cell, _ in
                cell.backgroundConfiguration = background(for: cell)
            }
        }
    }

    static func background(for cell: UITableViewCell) -> UIBackgroundConfiguration {
        var background = UIBackgroundConfiguration.listPlainCell()
        background.backgroundColor = cell.isHighlighted || cell.isSelected ? .settingsHighlighted : .settingsCard
        background.cornerRadius = ZLoaderSettingsStyle.cardRadius
        background.backgroundInsets = NSDirectionalEdgeInsets(
            top: 4, leading: ZLoaderSettingsStyle.horizontalInset, bottom: 4,
            trailing: ZLoaderSettingsStyle.horizontalInset)
        return background
    }
}

final class ZLoaderSettingsTableViewCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        refreshSettingsAppearance()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        refreshSettingsAppearance()
    }

    func refreshSettingsAppearance() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        backgroundConfiguration = ZLoaderSettingsTableStyle.background(for: self)
        directionalLayoutMargins = NSDirectionalEdgeInsets(top: 16, leading: 32, bottom: 16, trailing: 32)
        textLabel?.font = .preferredFont(forTextStyle: .body)
        textLabel?.adjustsFontForContentSizeCategory = true
        textLabel?.numberOfLines = 0
        detailTextLabel?.font = .preferredFont(forTextStyle: .caption1)
        detailTextLabel?.adjustsFontForContentSizeCategory = true
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        refreshSettingsAppearance()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        refreshSettingsAppearance()
    }
}
