import XCTest

final class ContainerUITests: XCTestCase {
    private let app = XCUIApplication(bundleIdentifier: "com.zynthec.zLoader")

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()
    }

    func test001OnboardingAndContainerPages() throws {
        for _ in 0..<8 {
            if app.tabBars.buttons["Meine Apps"].exists { break }
            let labels = ["Open zLoader", "zLoader öffnen", "Continue Without Apple Account", "Ohne Apple-Account fortfahren",
                          "Ohne Apple-Konto fortfahren", "Set Up Later", "Später einrichten", "Get Started", "Los geht’s", "Los geht's", "Continue", "Weiter"]
            guard let button = labels.map({ app.buttons[$0] }).first(where: { $0.exists && $0.isHittable && $0.isEnabled }) else {
                // Startup now correctly keeps inert tabs out of accessibility
                // until the fade is finished. An onboarded app has no action.
                if app.tabBars.buttons["Meine Apps"].waitForExistence(timeout: 15) { break }
                attach("onboarding-blocked")
                print("Visible buttons: " + app.buttons.allElementsBoundByIndex.map(\.label).joined(separator: " | "))
                print(app.debugDescription)
                XCTFail("Onboarding has no expected navigation action")
                return
            }
            button.tap()
        }
        XCTAssertTrue(app.tabBars.buttons["Meine Apps"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Meine Apps"].tap()
        let pages = app.segmentedControls["my-apps-pages"]
        XCTAssertTrue(pages.waitForExistence(timeout: 10))
        attach("installed-app-grid")
        pages.buttons["Apps in Containern"].tap()
        XCTAssertTrue(app.buttons["Container sortieren"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label IN %@", ["Install App", "App installieren"])).count, 1)
        attach("container-page")
        pages.buttons["Installierte Apps"].tap()
        XCTAssertFalse(app.buttons["discover-ipa-library"].exists)
        app.swipeLeft()
        XCTAssertTrue(pages.buttons["Apps in Containern"].isSelected)
        app.swipeRight()
        XCTAssertTrue(pages.buttons["Installierte Apps"].isSelected)
        app.tabBars.buttons["Entdecken"].tap()
        XCTAssertTrue(app.buttons["discover-ipa-library"].waitForExistence(timeout: 5))
        app.buttons["discover-ipa-library"].tap()
        attach("discover-ipa-library")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.tabBars.buttons["Einstellungen"].tap()
        let container = app.staticTexts["Container-Einstellungen"].firstMatch
        for _ in 0..<8 where !container.isHittable { app.swipeUp() }
        XCTAssertTrue(container.waitForExistence(timeout: 5))
        container.tap()
        XCTAssertFalse(app.buttons["Identität übernehmen"].exists)
        XCTAssertFalse(app.buttons["Container-Quellen"].exists)
        XCTAssertTrue(app.buttons["container-jitless-diagnostics"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts.matching(identifier: "Container-Einstellungen").count, 1)
        attach("container-settings-simplified")
        let identity = app.buttons["container-device-identity-settings"]
        XCTAssertTrue(identity.waitForExistence(timeout: 10))
        identity.tap()
        XCTAssertTrue(app.buttons["container-regenerate-device-identity"].waitForExistence(timeout: 10))
        attach("container-device-identity")
    }

    func test002IPAChoiceAndContainerImport() throws {
        app.tabBars.buttons["Meine Apps"].tap()
        for name in ["Alpha", "Beta", "Legacy"] {
            let pages = app.segmentedControls["my-apps-pages"]
            XCTAssertTrue(pages.waitForExistence(timeout: 15))
            pages.buttons["Apps in Containern"].tap()
            if app.otherElements["container-app-info-de.zloader.acceptance." + name.lowercased()].exists { continue }
            let install = app.buttons.matching(NSPredicate(format: "label IN %@", ["Install App", "App installieren"])).firstMatch
            XCTAssertTrue(install.waitForExistence(timeout: 10))
            install.tap()
            let files = app.buttons.matching(NSPredicate(format: "label IN %@", ["Choose from Files", "Aus Dateien wählen"])).firstMatch
            if files.waitForExistence(timeout: 3) { files.tap() }
            let browse = app.buttons.matching(NSPredicate(format: "label IN %@", ["Browse", "Durchsuchen"])).firstMatch
            if browse.waitForExistence(timeout: 3) { browse.tap() }
            let local = app.staticTexts.matching(NSPredicate(format: "label IN %@", ["On My iPhone", "Auf meinem iPhone"])).firstMatch
            if local.waitForExistence(timeout: 3) { local.tap() }
            let folder = app.staticTexts["zLoader"].firstMatch
            if folder.waitForExistence(timeout: 3) { folder.tap() }
            let file = app.staticTexts.matching(NSPredicate(format: "label IN %@", [name, name + ".ipa"])).firstMatch
            guard file.waitForExistence(timeout: 8) else {
                attach("ipa-picker"); print(app.debugDescription); XCTFail("Fixture IPA not visible"); return
            }
            let fileCell = app.cells.matching(NSPredicate(format: "identifier == %@", name + ".ipa, ipa")).firstMatch
            if fileCell.exists {
                fileCell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap()
            } else { file.tap() }
            let device = app.buttons["install-destination-device"]
            let container = app.buttons["install-destination-container"]
            XCTAssertTrue(device.waitForExistence(timeout: 10))
            XCTAssertTrue(container.exists)
            XCTAssertTrue(device.isEnabled)
            XCTAssertLessThan(app.navigationBars["Installation wählen"].frame.minY, app.frame.height * 0.1)
            attach("ipa-destination-" + name)
            container.tap()
            let info = app.otherElements["container-app-info-de.zloader.acceptance." + name.lowercased()]
            XCTAssertTrue(info.waitForExistence(timeout: 20))
            XCTAssertTrue(app.segmentedControls["my-apps-pages"].buttons["Apps in Containern"].isSelected)
        }
        attach("two-container-apps")
    }

    func test003VirtualIdentityAndInternalBrowserCallbacks() throws {
        let sharedID = selectIdentity(virtual: true)
        launchContainer("alpha")
        XCTAssertEqual(app.staticTexts["fixture-title"].label, "Alpha")
        XCTAssertEqual(app.staticTexts["fixture-idfv"].label, sharedID)
        XCTAssertEqual(app.staticTexts["fixture-product-type"].label, "iPhone17,2")
        XCTAssertEqual(app.staticTexts["fixture-uname"].label, "iPhone17,2")
        for browser in ["WK", "Safari", "ASSession", "ASCallback", "Wrapper"] {
            app.buttons["fixture-login-" + browser].tap()
            let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            let allow = springboard.buttons.matching(NSPredicate(format: "label IN %@", ["Continue", "Fortfahren"])).firstMatch
            if allow.waitForExistence(timeout: 2) { allow.tap() }
            let finish = app.links["Finish fixture login"].firstMatch
            XCTAssertTrue(finish.waitForExistence(timeout: 15))
            finish.tap()
            let callback = app.staticTexts["fixture-callback"]
            expectation(for: NSPredicate(format: "label CONTAINS %@", "state=acceptance"), evaluatedWith: callback)
            waitForExpectations(timeout: 15)
            XCTAssertTrue(callback.label.contains("code=synthetic"))
            XCTAssertEqual(XCUIApplication(bundleIdentifier: "de.zloader.acceptance.nativecollision").state, .notRunning)
            attach("internal-callback-" + browser)
        }
        app.terminate(); app.launch()
        launchContainer("beta")
        XCTAssertEqual(app.staticTexts["fixture-title"].label, "Beta")
        XCTAssertEqual(app.staticTexts["fixture-idfv"].label, sharedID)
        app.terminate(); app.launch()
        _ = selectIdentity(virtual: true)
        app.buttons["container-regenerate-device-identity"].tap()
        app.buttons["Neu erstellen"].tap()
        let newID = app.staticTexts["container-shared-idfv"].label
        XCTAssertNotEqual(newID, sharedID)
        app.terminate(); app.launch()
        launchContainer("alpha")
        XCTAssertEqual(app.staticTexts["fixture-idfv"].label, newID)
        XCTAssertGreaterThan(Int(app.staticTexts["fixture-launch-count"].label) ?? 0, 1)
        app.terminate(); app.launch()
        _ = selectIdentity(virtual: false)
        app.terminate(); app.launch()
        launchContainer("alpha")
        XCTAssertNotEqual(app.staticTexts["fixture-idfv"].label, newID)
        XCTAssertNotEqual(app.staticTexts["fixture-product-type"].label, "iPhone17,2")
        attach("container-host-identity")
    }

    func test004HomeScreenShortcutActions() throws {
        app.tabBars.buttons["Meine Apps"].tap()
        let pages = app.segmentedControls["my-apps-pages"]
        XCTAssertTrue(pages.waitForExistence(timeout: 15))
        pages.buttons["Apps in Containern"].tap()
        let info = app.otherElements["container-app-info-de.zloader.acceptance.alpha"]
        XCTAssertTrue(info.waitForExistence(timeout: 10))
        info.press(forDuration: 1)
        app.buttons["Zum Home-Bildschirm hinzufügen"].tap()
        app.buttons["Start-URL kopieren"].tap()
        // The harness verifies this synthetic URL with simctl pbpaste. iOS
        // correctly denies another app (the XCTest runner) direct clipboard access.
        info.press(forDuration: 1)
        app.buttons["Zum Home-Bildschirm hinzufügen"].tap()
        app.buttons["Verknüpfung erstellen"].tap()
        app.buttons["Hell"].tap()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(app.links["Profil laden"].waitForExistence(timeout: 15))
        let close = app.buttons.matching(NSPredicate(format: "label IN %@", ["Schließen", "Fertig", "Done", "Abbrechen"])).firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        XCTAssertFalse(app.alerts["Fehler"].exists)
        attach("home-screen-shortcut-configuration")
        close.tap()
    }

    func test005SharedPlusAndURLField() throws {
        app.tabBars.buttons["Meine Apps"].tap()
        let pages = app.segmentedControls["my-apps-pages"]
        pages.buttons["Apps in Containern"].tap()
        let plus = app.buttons.matching(NSPredicate(format: "label IN %@", ["Install App", "App installieren"])).firstMatch
        plus.tap()
        app.buttons.matching(NSPredicate(format: "label IN %@", ["Install from URL", "Von URL installieren"])).firstMatch.tap()
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText("https://example.com/app.ipa")
        XCTAssertEqual(field.value as? String, "https://example.com/app.ipa")
        attach("rounded-url-input")
        app.alerts.buttons.matching(NSPredicate(format: "label IN %@", ["Cancel", "Abbrechen"])).firstMatch.tap()
        XCTAssertTrue(pages.buttons["Apps in Containern"].isSelected)
    }

    func test007LegacyWrappedBrowserCallback() throws {
        launchContainer("legacy")
        XCTAssertEqual(app.staticTexts["fixture-title"].label, "Legacy")
        app.buttons["fixture-login-Wrapper"].tap()
        let finish = app.links["Finish fixture login"].firstMatch
        XCTAssertTrue(finish.waitForExistence(timeout: 15))
        finish.tap()
        let callback = app.staticTexts["fixture-callback"]
        expectation(for: NSPredicate(format: "label CONTAINS %@", "state=acceptance"), evaluatedWith: callback)
        waitForExpectations(timeout: 15)
        XCTAssertTrue(callback.label.contains("code=synthetic"))
        XCTAssertEqual(XCUIApplication(bundleIdentifier: "de.zloader.acceptance.nativecollision").state, .notRunning)
        attach("legacy-wrapper-callback")
    }

    func test006VirtualMultitasking() throws {
        app.tabBars.buttons["Meine Apps"].tap()
        let pages = app.segmentedControls["my-apps-pages"]
        XCTAssertTrue(pages.waitForExistence(timeout: 15))
        pages.buttons["Apps in Containern"].tap()
        let info = app.otherElements["container-app-info-de.zloader.acceptance.alpha"]
        XCTAssertTrue(info.waitForExistence(timeout: 10))
        info.press(forDuration: 1)
        app.buttons["Multitasking"].tap()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(app.staticTexts["fixture-title"].waitForExistence(timeout: 20))
        XCTAssertEqual(app.staticTexts["fixture-title"].label, "Alpha")
        app.buttons["Container-Fenstergröße ändern"].firstMatch.tap()
        app.buttons["Container-Fenstergröße ändern"].firstMatch.tap()
        app.buttons["Container minimieren"].firstMatch.tap()
        let beta = app.otherElements["container-app-info-de.zloader.acceptance.beta"]
        XCTAssertTrue(beta.waitForExistence(timeout: 10))
        beta.press(forDuration: 1)
        XCTAssertTrue(app.buttons["Mit JIT starten"].exists)
        app.buttons["Multitasking"].tap()
        let betaTitle = app.staticTexts.matching(NSPredicate(format: "identifier == %@ AND label == %@", "fixture-title", "Beta")).firstMatch
        XCTAssertTrue(betaTitle.waitForExistence(timeout: 20))
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        attach("container-virtual-multitasking-two-guests")
        app.buttons["Container schließen"].firstMatch.tap()
    }

    @discardableResult private func selectIdentity(virtual: Bool) -> String {
        app.tabBars.buttons["Einstellungen"].tap()
        let container = app.staticTexts["Container-Einstellungen"].firstMatch
        for _ in 0..<8 where !container.isHittable { app.swipeUp() }
        container.tap()
        app.buttons["container-device-identity-settings"].tap()
        app.buttons["container-device-identity-mode"].tap()
        let choice = virtual ? "Virtuelle Geräteidentität verwenden" : "Host-Gerät verwenden"
        let button = app.buttons[choice].firstMatch
        if button.exists { button.tap() } else { app.staticTexts[choice].firstMatch.tap() }
        let idfv = app.staticTexts["container-shared-idfv"]
        XCTAssertTrue(idfv.waitForExistence(timeout: 5))
        return idfv.label
    }

    private func launchContainer(_ name: String) {
        app.tabBars.buttons["Meine Apps"].tap()
        let pages = app.segmentedControls["my-apps-pages"]
        XCTAssertTrue(pages.waitForExistence(timeout: 15))
        pages.buttons["Apps in Containern"].tap()
        let run = app.buttons["container-app-run-de.zloader.acceptance." + name]
        XCTAssertTrue(run.waitForExistence(timeout: 10))
        run.tap()
        XCTAssertTrue(app.staticTexts["fixture-title"].waitForExistence(timeout: 20))
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
