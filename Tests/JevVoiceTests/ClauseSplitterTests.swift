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

final class ClauseSplitterNewVerbTests: XCTestCase {
    func testSplitsBeforeMinimize() {
        XCTAssertEqual(ClauseSplitter.split("open safari and minimize chrome"), ["open safari", "minimize chrome"])
    }

    func testSplitsBeforeMultiwordVerbs() {
        XCTAssertEqual(ClauseSplitter.split("bring up notes then shut down music"), ["bring up notes", "shut down music"])
    }
}
