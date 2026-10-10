//
//  PillButton.swift
//  ZLoader
//
//  Created by Riley Testut on 7/15/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit

extension PillButton
{
    static let minimumSize = CGSize(width: 77, height: 35)
    static let contentInsets = NSDirectionalEdgeInsets(top: 10.5, leading: 14, bottom: 10.5, trailing: 14)
}

extension PillButton
{
    enum Style
    {
        case pill
        case custom
    }

    enum DisplayState
    {
        case active(title: String, daysRemaining: Int)
        case crossSigned(title: String, daysRemaining: Int)
        case expired
        case revoked
    }
}

class PillButton: UIButton
{
    override var accessibilityValue: String? {
        get {
            guard self.progress != nil else { return super.accessibilityValue }
            return self.progressView.accessibilityValue
        }
        set { super.accessibilityValue = newValue }
    }
    
    var usesIconProgress = false { didSet { updateCircularProgress() } }

    var progress: Progress? {
        didSet {
            self.progressObservation?.invalidate()
            self.progressObservation = self.progress?.observe(\.fractionCompleted, options: [.initial, .new]) { [weak self] _, _ in
                DispatchQueue.main.async { [weak self] in self?.updateCircularProgress() }
            }
            self.progressView.progress = Float(self.progress?.fractionCompleted ?? 0)
            self.progressView.observedProgress = self.progress
            
            let isUserInteractionEnabled = self.isUserInteractionEnabled
            // Determinate circular progress replaces the rotating activity spinner.
            self.isIndicatingActivity = false
            if self.progress != nil
            {
                self.isUserInteractionEnabled = isUserInteractionEnabled
            }
            
            self.update()
        }
    }
    
    var progressTintColor: UIColor? {
        didSet {
            self.update()
        }
    }
    
    var borderColor: UIColor? {
        didSet {
            self.update()
        }
    }
    
    var borderWidth: CGFloat = 0 {
        didSet {
            self.update()
        }
    }
    
    var countdownDate: Date? {
        didSet {
            self.isEnabled = (self.countdownDate == nil)
            self.displayLink.isPaused = (self.countdownDate == nil)
            
            if self.countdownDate == nil
            {
                self.setTitle(nil, for: .disabled)
            }
        }
    }
    
    override var isIndicatingActivity: Bool {
        didSet {
            self.update()
        }
    }

    var style: Style = .pill {
        didSet {
            guard self.style != oldValue else { return }
            
            if self.style == .custom
            {
                // Reset insets for custom style.
                let size = self.fontSize ?? self.storyboardFontSize ?? 14
                let font = UIFont.boldSystemFont(ofSize: size)
                var config = self.configuration ?? UIButton.Configuration.plain()
                config.titleLineBreakMode = .byClipping
                config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
                config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { [weak self] incoming in
                    var outgoing = incoming
                    outgoing.font = font
                    if let self = self {
                        outgoing.foregroundColor = (self.progress == nil && !self.isIndicatingActivity) ? self.tintColor.contrastingText : UIColor.clear
                    }
                    return outgoing
                }
                self.configuration = config
            }
            
            self.update()
        }
    }

    override var intrinsicContentSize: CGSize {
        if self.progress != nil { return CGSize(width: Self.minimumSize.width, height: 52) }
        var size = super.intrinsicContentSize
        switch self.style {
        case .pill:
            size.width = max(size.width, PillButton.minimumSize.width)
            size.height = max(size.height, PillButton.minimumSize.height)
        case .custom:
            break
        }
        return size
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize
    {
        var size = super.sizeThatFits(size)
        
        switch self.style 
        {
        case .pill:
            size.width = max(size.width, PillButton.minimumSize.width)
            size.height = max(size.height, PillButton.minimumSize.height)
            
        case .custom: break
        }
        
        return size
    }
    
    var fontSize: CGFloat? {
        didSet {
            self.update()
        }
    }
    
    private var storyboardFontSize: CGFloat?
    private let progressTrack = CAShapeLayer()
    private let progressRing = CAShapeLayer()
    private let percentageLabel = UILabel()
    private var progressObservation: NSKeyValueObservation?
    private var originalHeightConstraints: [(NSLayoutConstraint, CGFloat)] = []

    
    private let progressView = UIProgressView(progressViewStyle: .default)
    
    private lazy var displayLink: CADisplayLink = {
        let displayLink = CADisplayLink(target: self, selector: #selector(PillButton.updateCountdown))
        displayLink.preferredFramesPerSecond = 15
        displayLink.isPaused = true
        displayLink.add(to: .main, forMode: .common)
        return displayLink
    }()
    
    private let dateComponentsFormatter: DateComponentsFormatter = {
        let dateComponentsFormatter = DateComponentsFormatter()
        dateComponentsFormatter.zeroFormattingBehavior = [.pad]
        dateComponentsFormatter.collapsesLargestUnit = false
        return dateComponentsFormatter
    }()
    
    deinit
    {
        self.displayLink.remove(from: .main, forMode: RunLoop.Mode.default)
    }
    
    override init(frame: CGRect)
    {
        super.init(frame: frame)
        
        self.initialize()
    }
    
    required init?(coder: NSCoder)
    {
        super.init(coder: coder)
    }
    
    override func awakeFromNib()
    {
        super.awakeFromNib()
        self.storyboardFontSize = self.titleLabel?.font.pointSize
        self.initialize()
    }
    
    private func initialize()
    {
        self.layer.masksToBounds = true
        self.accessibilityTraits.formUnion([.updatesFrequently, .button])
        
        self.activityIndicatorView.style = .medium
        self.activityIndicatorView.color = self.tintColor.contrastingText
        self.activityIndicatorView.isUserInteractionEnabled = false
        
        self.originalHeightConstraints = self.constraints.filter {
            $0.firstAttribute == .height && $0.secondItem == nil
        }.map { ($0, $0.constant) }
        self.layer.addSublayer(self.progressTrack)
        self.layer.addSublayer(self.progressRing)
        self.percentageLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        self.percentageLabel.textColor = .secondaryLabel
        self.percentageLabel.textAlignment = .center
        self.percentageLabel.isUserInteractionEnabled = false
        self.addSubview(self.percentageLabel)
        self.progressView.progress = 0
        self.progressView.trackTintColor = .tertiarySystemFill
        self.progressView.isUserInteractionEnabled = false
        self.addSubview(self.progressView)
        
        self.update()
    }
    
    override func layoutSubviews()
    {
        super.layoutSubviews()
        
        self.progressView.bounds.size.width = self.bounds.width
        
        let scale = self.bounds.height / self.progressView.bounds.height
        
        self.progressView.transform = CGAffineTransform.identity.scaledBy(x: 1, y: scale)
        self.progressView.center = CGPoint(x: self.bounds.midX, y: self.bounds.midY)
        
        self.layer.cornerRadius = self.bounds.midY
        self.updateCircularProgress()
    }

    private func updateCircularProgress() {
        let active = self.progress != nil
        self.progressTrack.isHidden = !active
        self.progressRing.isHidden = !active
        self.percentageLabel.isHidden = !active || usesIconProgress
        guard let progress = self.progress else { return }
        let fraction = min(1, max(0, progress.fractionCompleted))
        let diameter: CGFloat = usesIconProgress ? 38 : 30
        let center = CGPoint(x: self.bounds.midX, y: usesIconProgress ? self.bounds.midY : 18)
        let path = UIBezierPath(arcCenter: center, radius: diameter / 2,
            startAngle: -.pi / 2, endAngle: 3 * .pi / 2, clockwise: true).cgPath
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for shape in [self.progressTrack, self.progressRing] {
            shape.frame = self.bounds
            shape.path = path
            shape.fillColor = UIColor.clear.cgColor
            shape.lineWidth = 3.5
            shape.lineCap = .round
        }
        self.progressTrack.strokeColor = (usesIconProgress ? UIColor.white.withAlphaComponent(0.35) : UIColor.systemGray4).cgColor
        self.progressRing.strokeColor = (usesIconProgress ? UIColor.white : UIColor.altPrimary).cgColor
        self.progressRing.strokeEnd = CGFloat(fraction)
        CATransaction.commit()
        self.percentageLabel.frame = CGRect(x: 0, y: 37, width: self.bounds.width, height: 14)
        self.percentageLabel.text = NumberFormatter.localizedString(from: NSNumber(value: fraction), number: .percent)
        self.accessibilityValue = self.percentageLabel.text
    }
    
    override func tintColorDidChange()
    {
        super.tintColorDidChange()
        
        self.update()
    }
}

extension PillButton {
    func configure(for installedApp: InstalledApp) {
        let currentDate = Date()
        let expirationDate = installedApp.expirationDate
        let isExpired = currentDate > expirationDate
        
        // verboseLog("[PillButton] configure for app '\(installedApp.name)': status=\(installedApp.certificateStatus), certSerial=\(installedApp.certificateSerialNumber ?? "nil"), isExpired=\(isExpired)")
        
        if installedApp.certificateStatus == .revoked {
            self.setDisplayState(.revoked)
        } else if isExpired || installedApp.certificateStatus == .expired {
            self.setDisplayState(.expired)
        } else {
            let formatter = DateComponentsFormatter()
            formatter.unitsStyle = .full
            formatter.allowedUnits = [.day, .hour, .minute]
            formatter.maximumUnitCount = 1
            let title = formatter.string(from: currentDate, to: expirationDate) ?? ""
            let days = Calendar.current.dateComponents([.day], from: currentDate, to: expirationDate).day ?? 0
            
            if case .valid(let isCrossSigned) = installedApp.certificateStatus, isCrossSigned {
                self.setDisplayState(.crossSigned(title: title, daysRemaining: days))
            } else {
                self.setDisplayState(.active(title: title, daysRemaining: days))
            }
        }
    }

    func resetDisplayState() {
        // verboseLog("[PillButton] resetDisplayState called")
        self.countdownDate = nil
        self.borderColor = nil
        self.borderWidth = 0
        self.progress = nil
        self.setTitle(nil, for: .normal)
        self.update()
    }

    func setDisplayState(_ state: DisplayState) {
        // verboseLog("[PillButton] setDisplayState called: \(state)")
        switch state {
        case .revoked:
            self.countdownDate = nil
            self.tintColor = .refreshRed
            self.borderColor = nil
            self.borderWidth = 0
            self.setTitle(NSLocalizedString("REVOKED", comment: ""), for: .normal)
            
        case .expired:
            self.countdownDate = nil
            self.tintColor = .refreshRed
            self.borderColor = nil
            self.borderWidth = 0
            self.setTitle(NSLocalizedString("EXPIRED", comment: ""), for: .normal)
            
        case .active(let title, let daysRemaining):
            self.setTitle(title.uppercased(), for: .normal)
            self.borderColor = nil
            self.borderWidth = 0
            
            switch daysRemaining {
            case 2...3: self.tintColor = .refreshOrange
            case 4...5: self.tintColor = .refreshYellow
            case 6...: self.tintColor = .refreshGreen
            default: self.tintColor = .refreshRed
            }
            
        case .crossSigned(let title, let daysRemaining):
            self.setTitle(title.uppercased(), for: .normal)
            self.borderColor = .systemBlue
            self.borderWidth = 2.0
            
            switch daysRemaining {
            case 2...3: self.tintColor = .refreshOrange
            case 4...5: self.tintColor = .refreshYellow
            case 6...: self.tintColor = .refreshGreen
            default: self.tintColor = .refreshRed
            }
        }
        self.update()
    }
}

private extension PillButton
{
    func update()
    {
        for (constraint, height) in self.originalHeightConstraints {
            constraint.constant = self.progress == nil ? height : 52
        }
        self.invalidateIntrinsicContentSize()
        self.updateCircularProgress()
        if self.progress == nil && !self.isIndicatingActivity
        {
            self.progressView.isHidden = true
            self.setTitleColor(self.tintColor.contrastingText, for: .normal)
            self.backgroundColor = self.tintColor
            self.progressView.progressTintColor = self.progressTintColor ?? self.tintColor
            self.layer.borderColor = self.borderColor?.cgColor
            self.layer.borderWidth = self.borderWidth
        }
        else
        {
            self.progressView.isHidden = true
            self.setTitleColor(.clear, for: .normal)
            self.setTitleColor(.clear, for: .disabled)
            self.backgroundColor = self.progress == nil ? .secondarySystemGroupedBackground : .clear
            self.progressView.progressTintColor = .label
            self.activityIndicatorView.color = .systemGray
            self.layer.borderColor = nil
            self.layer.borderWidth = 0
        }
        
        // Update font after init because the original titleLabel is replaced.
        let size = self.fontSize ?? self.storyboardFontSize ?? 14
        let font = UIFont.boldSystemFont(ofSize: size)
        self.titleLabel?.font = font
        self.titleLabel?.adjustsFontSizeToFitWidth = false
        self.titleLabel?.numberOfLines = 1
        self.titleLabel?.lineBreakMode = .byClipping
        
        switch self.style
        {
        case .custom: break // Don't update insets in case client has updated them.
        case .pill:
            var config: UIButton.Configuration
            if #available(iOS 26.0, tvOS 26.0, *), self.progress == nil && !self.isIndicatingActivity {
                config = UIButton.Configuration.prominentGlass()
                config.title = self.currentTitle
                config.image = self.currentImage
                config.baseBackgroundColor = self.tintColor
                self.backgroundColor = .clear
            } else {
                config = UIButton.Configuration.plain()
            }
            config.cornerStyle = .capsule
            config.titleLineBreakMode = .byClipping
            config.contentInsets = NSDirectionalEdgeInsets(
                top: Self.contentInsets.top,
                leading: Self.contentInsets.leading,
                bottom: Self.contentInsets.bottom,
                trailing: Self.contentInsets.trailing
            )
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { [weak self] incoming in
                var outgoing = incoming
                outgoing.font = font
                if let self = self {
                    outgoing.foregroundColor = (self.progress == nil && !self.isIndicatingActivity) ? self.tintColor.contrastingText : UIColor.clear
                }
                return outgoing
            }
            if self.progress != nil {
                config.background = UIBackgroundConfiguration.clear()
            }
            self.configuration = config
            if self.progress != nil { self.activityIndicatorView.isHidden = true }
            self.layer.cornerRadius = self.bounds.height / 2
        }
    }
    

    @objc func updateCountdown()
    {
        guard let endDate = self.countdownDate else { return }
        
        let startDate = Date()
        
        let interval = endDate.timeIntervalSince(startDate)
        guard interval > 0 else {
            self.isEnabled = true
            return
        }
        
        let text: String?
        
        if interval < (1 * 60 * 60)
        {
            self.dateComponentsFormatter.unitsStyle = .positional
            self.dateComponentsFormatter.allowedUnits = [.minute, .second]
            
            text = self.dateComponentsFormatter.string(from: startDate, to: endDate)
        }
        else if interval < (2 * 24 * 60 * 60)
        {
            self.dateComponentsFormatter.unitsStyle = .positional
            self.dateComponentsFormatter.allowedUnits = [.hour, .minute, .second]
            
            text = self.dateComponentsFormatter.string(from: startDate, to: endDate)
        }
        else
        {
            self.dateComponentsFormatter.unitsStyle = .full
            self.dateComponentsFormatter.allowedUnits = [.day]
            
            let numberOfDays = endDate.numberOfCalendarDays(since: startDate)
            text = String(format: NSLocalizedString("%@ DAYS", comment: ""), NSNumber(value: numberOfDays))
        }
        
        if let text = text
        {            
            UIView.performWithoutAnimation {
                self.isEnabled = false
                self.setTitle(text, for: .disabled)
                self.layoutIfNeeded()
            }
        }
        else
        {
            self.isEnabled = true
        }
    }
}
