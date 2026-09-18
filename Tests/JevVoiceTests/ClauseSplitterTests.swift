import XCTest
@testable import JevVoiceCore

final class ClauseSplitterTests: XCTestCase {
    func testSplitsOnAndBeforeCommandVerb() {
        XCTAssertEqual(
            ClauseSplitter.split("open chrome and go to google.com"),
            ["open chrome", "go to google.com"]
        )
    }

    func testKeepsConjoinedObjectsTogether() {
        XCTAssertEqual(
            ClauseSplitter.split("open notes and spotify"),
            ["open notes and spotify"]
        )
    }

    func testSplitsOnThen() {
        XCTAssertEqual(
            ClauseSplitter.split("quit slack then open safari"),
            ["quit slack", "open safari"]
        )
    }

    func testAndThenSplitsOnce() {
        XCTAssertEqual(
            ClauseSplitter.split("open chrome and then go to google.com"),
            ["open chrome", "go to google.com"]
        )
    }
}
