import XCTest
@testable import JevVoiceCore

final class AppMatcherTests: XCTestCase {
    let apps = ["Google Chrome", "Safari", "Notes", "Visual Studio Code", "Chrome Remote Desktop", "Music"]

    func testPartialName() {
        XCTAssertEqual(AppMatcher.match(clause: "close chrome", installedApps: apps), "Google Chrome")
    }

    func testFullName() {
        XCTAssertEqual(AppMatcher.match(clause: "open visual studio code", installedApps: apps), "Visual Studio Code")
    }

    func testCaseInsensitive() {
        XCTAssertEqual(AppMatcher.match(clause: "Open Safari please", installedApps: apps), "Safari")
    }

    func testNoApp() {
        XCTAssertNil(AppMatcher.match(clause: "close the app", installedApps: apps))
    }
}
