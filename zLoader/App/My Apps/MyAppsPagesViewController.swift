import UIKit

#if !os(tvOS)

/// The existing installed-app controller remains intact. Container apps live on
/// the adjacent page and keep LiveContainer's own management/navigation flows.
final class MyAppsPagesViewController: UIViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    let installed: MyAppsViewController
    private lazy var containers = ZLoaderContainerAppsController()
    private let pager = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
    private let selection = UISegmentedControl(items: ["Installierte Apps", "Apps in Containern"])

    init(installed: MyAppsViewController) {
        self.installed = installed
        super.init(nibName: nil, bundle: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(chooseIPA), name: .init("ZLoaderChooseIPA"), object: nil)
    }
    required init?(coder: NSCoder) { fatalError("Use init(installed:)") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("My Apps", comment: "")
        installed.loadViewIfNeeded()
        navigationItem.leftBarButtonItems = installed.navigationItem.leftBarButtonItems
        navigationItem.leftBarButtonItems?.first?.target = self
        navigationItem.leftBarButtonItems?.first?.action = #selector(chooseIPA)
        navigationItem.rightBarButtonItems = installed.navigationItem.rightBarButtonItems
        selection.selectedSegmentIndex = 0
        selection.accessibilityIdentifier = "my-apps-pages"
        selection.addTarget(self, action: #selector(changePage), for: .valueChanged)
        selection.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(selection)
        addChild(pager)
        pager.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pager.view)
        pager.didMove(toParent: self)
        pager.dataSource = self
        pager.delegate = self
        pager.setViewControllers([installed], direction: .forward, animated: false)
        NSLayoutConstraint.activate([
            selection.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            selection.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            selection.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            pager.view.topAnchor.constraint(equalTo: selection.bottomAnchor, constant: 8),
            pager.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pager.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pager.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @objc private func chooseIPA() {
        showInstalled()
        installed.presentInstallationPicker()
    }

    func showInstalled() {
        loadViewIfNeeded()
        selection.selectedSegmentIndex = 0
        pager.setViewControllers([installed], direction: .reverse, animated: false)
    }

    func showContainers() {
        loadViewIfNeeded()
        selection.selectedSegmentIndex = 1
        pager.setViewControllers([containers], direction: .forward, animated: false)
    }
    @objc private func changePage() {
        pager.setViewControllers([selection.selectedSegmentIndex == 0 ? installed : containers],
            direction: selection.selectedSegmentIndex == 0 ? .reverse : .forward, animated: true)
    }
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore controller: UIViewController) -> UIViewController? {
        controller === installed ? nil : installed
    }
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter controller: UIViewController) -> UIViewController? {
        controller === installed ? containers : nil
    }
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool,
                            previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if completed { selection.selectedSegmentIndex = pageViewController.viewControllers?.first === installed ? 0 : 1 }
    }
}
#endif
