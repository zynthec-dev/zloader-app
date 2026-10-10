//
//  AppBannerView.swift
//  ZLoader
//
//  Created by Riley Testut on 8/29/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit

import Nuke

extension AppBannerView
{
    static let standardHeight = 88.0
    
    enum Style
    {
        case app
        case source
    }
    
    enum AppAction
    {
        case install
        case open
        case update
        case custom(String)
    }
}

class AppBannerView: NibView
{
    override var accessibilityLabel: String? {
        get { return self.accessibilityView?.accessibilityLabel }
        set { self.accessibilityView?.accessibilityLabel = newValue }
    }
    
    override open var accessibilityAttributedLabel: NSAttributedString? {
        get { return self.accessibilityView?.accessibilityAttributedLabel }
        set { self.accessibilityView?.accessibilityAttributedLabel = newValue }
    }
    
    override var accessibilityValue: String? {
        get { return self.accessibilityView?.accessibilityValue }
        set { self.accessibilityView?.accessibilityValue = newValue }
    }
    
    override open var accessibilityAttributedValue: NSAttributedString? {
        get { return self.accessibilityView?.accessibilityAttributedValue }
        set { self.accessibilityView?.accessibilityAttributedValue = newValue }
    }
    
    override open var accessibilityTraits: UIAccessibilityTraits {
        get { return self.accessibilityView?.accessibilityTraits ?? [] }
        set { self.accessibilityView?.accessibilityTraits = newValue }
    }
    
    var style: Style = .app
    private var hasLauncherProgressOverlay = false
    private let launcherDimmingView = UIView()
    private var launcherProgressObservations: [NSKeyValueObservation] = []
    private var launcherProgress: Progress?
    private var launcherLabelsWidthConstraint: NSLayoutConstraint?
    var isLauncherCard = false {
        didSet {
            stackView.axis = isLauncherCard ? .vertical : .horizontal
            stackView.spacing = isLauncherCard ? 4 : 11
            stackView.layoutMargins = isLauncherCard ? UIEdgeInsets(top: 8, left: 2, bottom: 8, right: 2) : layoutMargins
            stackView.preservesSuperviewLayoutMargins = !isLauncherCard
            if let labels = stackView.arrangedSubviews.dropFirst().first as? UIStackView {
                labels.alignment = isLauncherCard ? .fill : .leading
                labels.setContentHuggingPriority(.required, for: .vertical)
                labels.setContentCompressionResistancePriority(.required, for: .vertical)
                if launcherLabelsWidthConstraint == nil {
                    launcherLabelsWidthConstraint = labels.widthAnchor.constraint(equalTo: stackView.layoutMarginsGuide.widthAnchor)
                }
                launcherLabelsWidthConstraint?.isActive = isLauncherCard
            }
            titleLabel.textAlignment = isLauncherCard ? .center : .natural
            titleLabel.numberOfLines = isLauncherCard ? 0 : 1
            titleLabel.lineBreakMode = isLauncherCard ? .byWordWrapping : .byTruncatingTail
            titleLabel.adjustsFontForContentSizeCategory = true
            subtitleLabel.adjustsFontForContentSizeCategory = true
            titleLabel.font = isLauncherCard ? .preferredFont(forTextStyle: .footnote) : .preferredFont(forTextStyle: .headline)
            sourceIconImageView.isHidden = isLauncherCard
            betaBadgeView.isHidden = isLauncherCard
            subtitleLabel.isHidden = false
            subtitleLabel.font = isLauncherCard ? .preferredFont(forTextStyle: .caption2) : .preferredFont(forTextStyle: .subheadline)
            subtitleLabel.textAlignment = isLauncherCard ? .center : .natural
            if isLauncherCard && !hasLauncherProgressOverlay {
                // A hidden arranged button would conflict with its fixed nib
                // height. Keep operation progress over the icon, outside the
                // home-screen name/day stack.
                launcherDimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.55)
                launcherDimmingView.isUserInteractionEnabled = false
                launcherDimmingView.translatesAutoresizingMaskIntoConstraints = false
                iconImageView.addSubview(launcherDimmingView)
                NSLayoutConstraint.activate([
                    launcherDimmingView.leadingAnchor.constraint(equalTo: iconImageView.leadingAnchor),
                    launcherDimmingView.trailingAnchor.constraint(equalTo: iconImageView.trailingAnchor),
                    launcherDimmingView.topAnchor.constraint(equalTo: iconImageView.topAnchor),
                    launcherDimmingView.bottomAnchor.constraint(equalTo: iconImageView.bottomAnchor)
                ])
                // Let the stack end at its intrinsic height instead of stretching
                // the name/day labels to fill the tallest grid tile.
                for constraint in constraints where constraint.secondItem as AnyObject? === stackView && constraint.firstAttribute == .bottom {
                    constraint.isActive = false
                }
                stackView.removeArrangedSubview(button)
                button.removeFromSuperview()
                for constraint in constraints where
                    (constraint.firstItem as AnyObject?) === button ||
                    (constraint.secondItem as AnyObject?) === button {
                    constraint.isActive = false
                }
                addSubview(button)
                NSLayoutConstraint.activate([
                    button.centerXAnchor.constraint(equalTo: iconImageView.centerXAnchor),
                    button.centerYAnchor.constraint(equalTo: iconImageView.centerYAnchor)
                ])
                button.usesIconProgress = true
                button.isUserInteractionEnabled = false
                hasLauncherProgressOverlay = true
            }
            button.isHidden = isLauncherCard && button.progress == nil
            launcherDimmingView.isHidden = button.progress == nil
            backgroundEffectView.isHidden = isLauncherCard
            buttonLabel.isHidden = isLauncherCard
            update()
        }
    }
    
    private var originalTintColor: UIColor?
    
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var subtitleLabel: UILabel!
    @IBOutlet var iconImageView: AppIconImageView!
    @IBOutlet var button: PillButton!
    @IBOutlet var buttonLabel: UILabel!
    @IBOutlet var betaBadgeView: UIView!
    @IBOutlet var sourceIconImageView: AppIconImageView!
    
    @IBOutlet var backgroundEffectView: UIVisualEffectView!
    
    @IBOutlet private var vibrancyView: UIVisualEffectView!
    @IBOutlet private var stackView: UIStackView!
    @IBOutlet private var accessibilityView: UIView!
    
    @IBOutlet private var iconImageViewHeightConstraint: NSLayoutConstraint!
    
    override init(frame: CGRect)
    {
        super.init(frame: frame)
        
        self.initialize()
    }
    
    required init?(coder: NSCoder)
    {
        super.init(coder: coder)
        
        self.initialize()
    }
    
    private func initialize()
    {
        self.accessibilityView.accessibilityTraits.formUnion(.button)
        
        self.isAccessibilityElement = false
        self.accessibilityElements = [self.accessibilityView, self.button].compactMap { $0 }
        
        self.betaBadgeView.isHidden = true
        
        self.sourceIconImageView.style = .circular
        self.sourceIconImageView.isHidden = true
        
        self.layoutMargins = self.stackView.layoutMargins
        self.insetsLayoutMarginsFromSafeArea = false
        
        self.stackView.isLayoutMarginsRelativeArrangement = true
        self.stackView.preservesSuperviewLayoutMargins = true
    }
    
    override func tintColorDidChange()
    {
        super.tintColorDidChange()
        
        if self.tintAdjustmentMode != .dimmed
        {
            self.originalTintColor = self.tintColor
        }
        
        self.update()
    }

    override func layoutSubviews()
    {
        if isLauncherCard {
            iconImageViewHeightConstraint.constant = Self.launcherIconSize(for: bounds.width)
        }
        super.layoutSubviews()
    }

    func configureLauncherProgress(_ progress: Progress?) {
        launcherProgressObservations.removeAll()
        launcherProgress = progress
        button.progress = progress
        button.isHidden = progress == nil
        launcherDimmingView.isHidden = progress == nil
        guard let progress else { return }
        let update: () -> Void = { [weak self, weak progress] in
            guard let self, let progress, self.launcherProgress === progress else { return }
            self.titleLabel.text = progress.localizedDescription
            self.subtitleLabel.text = NumberFormatter.localizedString(
                from: NSNumber(value: min(1, max(0, progress.fractionCompleted))), number: .percent)
        }
        launcherProgressObservations = [
            progress.observe(\.fractionCompleted, options: [.initial, .new]) { _, _ in
                DispatchQueue.main.async(execute: update)
            },
            progress.observe(\.localizedDescription, options: [.new]) { _, _ in
                DispatchQueue.main.async(execute: update)
            }
        ]
    }

    static func launcherIconSize(for width: CGFloat) -> CGFloat {
        min(112, max(0, width - 4))
    }
}

extension AppBannerView
{
    func configure(for app: AppProtocol, action: AppAction? = nil, showSourceIcon: Bool = true)
    {
        struct AppValues
        {
            var name: String
            var developerName: String? = nil
            var isBeta: Bool = false
            
            init(app: AppProtocol)
            {
                self.name = app.name
                                
                guard let storeApp = (app as? StoreApp) ?? (app as? InstalledApp)?.storeApp else { return }
                self.developerName = storeApp.developerName

                // Determine the beta badge using a fallback chain:
                // 1. For installed apps: use the persisted releaseTrack (the track it was installed from)
                // 2. For store apps / update banners: use latestSupportedVersion.channel
                // 3. If neither is available, assume stable (no badge)
                let track: ReleaseTrackType?
                if let installedApp = app as? InstalledApp {
                    if let persistedTrack = installedApp.releaseTrack?.type {
                        track = persistedTrack
                    } else {
                        track = ReleaseTrackType.from(version: installedApp.version)
                    }
                } else {
                    track = storeApp.latestSupportedVersion?.channel
                }

                if let track, ReleaseTrackType.betaTracks.contains(track)
                {
                    self.name = String(format: NSLocalizedString("%@ beta", comment: ""), app.name)
                    self.isBeta = true
                }
            }
        }
        
        self.style = .app

        let values = AppValues(app: app)
        self.titleLabel.text = app.name // Don't use values.name since that already includes "beta".
        self.betaBadgeView.isHidden = !values.isBeta

        if let developerName = values.developerName
        {
            self.subtitleLabel.text = developerName
            self.accessibilityLabel = String(format: NSLocalizedString("%@ by %@", comment: ""), values.name, developerName)
        }
        else
        {
            self.subtitleLabel.text = NSLocalizedString("Sideloaded", comment: "")
            self.accessibilityLabel = values.name
        }
        self.buttonLabel.isHidden = true
        
        if let source = app.storeApp?.source, showSourceIcon
        {
            self.sourceIconImageView.isHidden = false
            self.sourceIconImageView.backgroundColor = source.effectiveTintColor?.adjustedForDisplay ?? .altPrimary
            
            if let iconURL = source.effectiveIconURL
            {
                if let cached = ImagePipeline.shared.cache[iconURL]
                {
                    self.sourceIconImageView.backgroundColor = .white
                    self.sourceIconImageView.image = cached.image
                }
                else
                {
                    self.sourceIconImageView.image = nil
                    
                    Task { [weak self] in
                        do
                        {
                            let image = try await ImagePipeline.shared.image(for: iconURL)
                            guard let self else { return }
                            self.sourceIconImageView.image = image
                            self.sourceIconImageView.backgroundColor = .white
                        }
                        catch
                        {
                            debugLog("Failed to fetch source icon from \(iconURL). \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
        else
        {
            self.sourceIconImageView.isHidden = true
        }
        
        let buttonAction: AppAction
        
        if let action
        {
            buttonAction = action
        }
        else if let storeApp = app.storeApp
        {
            if let installedApp = storeApp.installedApp
            {
                // App is installed
                
                // if installedApp.isUpdateAvailable
                if installedApp.hasUpdate
                {
                    buttonAction = .update
                }
                else
                {
                    buttonAction = .open
                }
            }
            else
            {
                // App is not installed
                buttonAction = .install
            }
        }
        else
        {
            // App is not from a source, fall back to .open
            buttonAction = .open
        }
        
        UIView.performWithoutAnimation {
            if case .custom = buttonAction {} else {
                self.button.resetDisplayState()
            }
            
            switch buttonAction
            {
            case .open:
                let buttonTitle = NSLocalizedString("Open", comment: "")
                self.button.setTitle(buttonTitle.uppercased(), for: .normal)
                self.button.accessibilityLabel = String(format: NSLocalizedString("Open %@", comment: ""), values.name)
                self.button.accessibilityValue = buttonTitle
                
                self.button.countdownDate = nil
                
            case .update:
                let buttonTitle = NSLocalizedString("Update", comment: "")
                self.button.setTitle(buttonTitle.uppercased(), for: .normal)
                self.button.accessibilityLabel = String(format: NSLocalizedString("Update %@", comment: ""), values.name)
                self.button.accessibilityValue = buttonTitle
                
                self.button.countdownDate = nil
                
            case .custom(let buttonTitle):
                self.button.setTitle(buttonTitle, for: .normal)
                self.button.accessibilityLabel = buttonTitle
                self.button.accessibilityValue = buttonTitle
                
                self.button.countdownDate = nil
                
            case .install:
                if let storeApp = app.storeApp, storeApp.isPledgeRequired
                {
                    // Pledge required
                    
                    if storeApp.isPledged
                    {
                        let buttonTitle = NSLocalizedString("Install", comment: "")
                        self.button.setTitle(buttonTitle.uppercased(), for: .normal)
                        self.button.accessibilityLabel = String(format: NSLocalizedString("Install %@", comment: ""), app.name)
                        self.button.accessibilityValue = buttonTitle
                    }
                    else
                    {
                        let buttonTitle = NSLocalizedString("Pledge", comment: "")
                        self.button.setTitle(buttonTitle.uppercased(), for: .normal)
                        self.button.accessibilityLabel = buttonTitle
                        self.button.accessibilityValue = buttonTitle
                    }
                }
                else
                {
                    // Free app
                    
                    let buttonTitle = NSLocalizedString("Free", comment: "")
                    self.button.setTitle(buttonTitle.uppercased(), for: .normal)
                    self.button.accessibilityLabel = String(format: NSLocalizedString("Download %@", comment: ""), app.name)
                    self.button.accessibilityValue = buttonTitle
                }
                
                if let versionDate = app.storeApp?.latestSupportedVersion?.date, versionDate > Date()
                {
                    self.button.countdownDate = versionDate
                }
                else
                {
                    self.button.countdownDate = nil
                }
            }
            
            // Ensure PillButton is correct size before assigning progress.
            self.layoutIfNeeded()
        }
        
        if let progress = AppManager.shared.refreshProgress(for: app), progress.fractionCompleted < 1.0
        {
            self.button.progress = progress
        }
        else
        {
            self.button.progress = nil
        }
    }
    
    func configure(for source: Source)
    {
        self.style = .source
        
        let subtitle: String
        if let text = source.subtitle
        {
            subtitle = text
        }
        else if let scheme = source.sourceURL.scheme
        {
            subtitle = source.sourceURL.absoluteString.replacingOccurrences(of: scheme + "://", with: "")
        }
        else
        {
            subtitle = source.sourceURL.absoluteString
        }
        
        self.titleLabel.text = source.name
        self.subtitleLabel.text = subtitle
        
        let tintColor = source.effectiveTintColor ?? .altPrimary
        self.tintColor = tintColor
        
        let accessibilityLabel = source.name + "\n" + subtitle
        self.accessibilityLabel = accessibilityLabel
    }
}

private extension AppBannerView
{
    func update()
    {
        self.clipsToBounds = true
        self.layer.cornerRadius = isLauncherCard ? 0 : 22
        
        let tintColor = self.originalTintColor ?? self.tintColor
        // Render semantic labels directly; vibrancy can wash them out in Light Mode.
        self.vibrancyView.effect = nil
        self.subtitleLabel.textColor = .secondaryLabel
        
        switch self.style
        {
        case .app:
            self.directionalLayoutMargins.trailing = self.stackView.directionalLayoutMargins.trailing
            
            self.iconImageViewHeightConstraint.constant = isLauncherCard ? Self.launcherIconSize(for: bounds.width) : 60
            self.iconImageView.style = .icon
            
            self.titleLabel.textColor = .label
            
            self.button.style = .pill
            
            self.backgroundEffectView.contentView.backgroundColor = .clear
            ZLoaderCardMaterial.apply(to: self.backgroundEffectView)
            
        case .source:
            self.directionalLayoutMargins.trailing = 20
            
            self.iconImageViewHeightConstraint.constant = 44
            self.iconImageView.style = .circular
            
            self.titleLabel.textColor = tintColor?.adjustedForDisplay.contrastingText
            self.subtitleLabel.textColor = tintColor?.adjustedForDisplay.contrastingText
            
            self.button.style = .custom
            
            ZLoaderCardMaterial.apply(to: self.backgroundEffectView)
            self.titleLabel.textColor = .label
            self.subtitleLabel.textColor = .secondaryLabel
            

        }
    }
}
