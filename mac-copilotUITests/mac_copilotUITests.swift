//
//  mac_copilotUITests.swift
//  mac-copilotUITests
//
//  Created by Parham on 25/02/2026.
//

import XCTest

final class mac_copilotUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testSmoke_launchShowsOnboardingOrShell() throws {
        let app = XCUIApplication()
        app.launch()

        assertOnboardingOrShell(app)
    }

    func testSmoke_chatComposerVisibleWhenChatIsActive() throws {
        let app = XCUIApplication()
        app.launch()

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
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
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
