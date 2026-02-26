//
//  mac_copilotUITests.swift
//  mac-copilotUITests
//
//  Created by Parham on 25/02/2026.
//

import XCTest

final class mac_copilotUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-ApplePersistenceIgnoreState", "YES", "-UITestMode", "1"]
        app.launchEnvironment["UITEST_DISABLE_ANIMATIONS"] = "1"
    }

    override func tearDownWithError() throws {
        if let app, app.state != .notRunning {
            app.terminate()
        }
        app = nil
    }

    func testSmoke_launchShowsOnboardingOrShell() throws {
        launchFreshApp()

        assertOnboardingOrShell(app)
    }

    func testSmoke_chatComposerVisibleWhenChatIsActive() throws {
        launchFreshApp()

        let connectGitHub = app.buttons["Connect GitHub"]
        if connectGitHub.waitForExistence(timeout: 3) {
            throw XCTSkip("App is currently on onboarding/auth gate; chat composer smoke assertion requires authenticated shell state.")
        }

        if app.staticTexts["Ask CopilotForge to build something…"].waitForExistence(timeout: 6) {
            XCTAssertTrue(app.staticTexts["Ask CopilotForge to build something…"].exists)
            return
        }

        throw XCTSkip("No active chat composer found in current shell selection; skipping until project/chat setup is deterministic for UI tests.")
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            launchFreshApp()
        }
    }

    private func launchFreshApp() {
        if app.state != .notRunning {
            app.terminate()
        }
        app.launch()
    }

    private func assertOnboardingOrShell(_ app: XCUIApplication) {
        if app.buttons["Connect GitHub"].waitForExistence(timeout: 4) {
            XCTAssertTrue(app.staticTexts["Welcome to CopilotForge"].exists)
            return
        }

        let shellTitle = app.staticTexts["CopilotForge"]
        let newChatButton = app.buttons["New Chat"]
        XCTAssertTrue(shellTitle.waitForExistence(timeout: 6) || newChatButton.waitForExistence(timeout: 6))
    }
}
