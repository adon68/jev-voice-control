import XCTest
@testable import JevVoiceCore

final class CommandInterpreterTests: XCTestCase {
    func testPropagatesBrowserContextToLaterWebSearch() {
        let decisions = [
            Decision(clause: "open chrome", action: .openApp, targetApp: "Google Chrome"),
            Decision(clause: "search for banana", action: .webSearch),
        ]

        let propagated = CommandInterpreter.propagateContext(decisions)

        XCTAssertEqual(propagated[1].targetApp, "Google Chrome")
    }

    func testDoesNotPropagateNonBrowserContext() {
        let decisions = [
            Decision(clause: "open notes", action: .openApp, targetApp: "Notes"),
            Decision(clause: "search for banana", action: .webSearch),
        ]

        let propagated = CommandInterpreter.propagateContext(decisions)

        XCTAssertNil(propagated[1].targetApp)
    }
}
