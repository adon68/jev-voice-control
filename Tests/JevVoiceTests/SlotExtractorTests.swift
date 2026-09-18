import XCTest
@testable import JevVoiceCore

final class SlotExtractorTests: XCTestCase {
    func testSpokenDotURL() {
        XCTAssertEqual(SlotExtractor.url(from: "go to google dot com"), "https://google.com")
    }

    func testURLWithPath() {
        XCTAssertEqual(SlotExtractor.url(from: "open github.com/chris"), "https://github.com/chris")
    }

    func testNoURL() {
        XCTAssertNil(SlotExtractor.url(from: "open notes"))
    }

    func testSearchQuery() {
        XCTAssertEqual(
            SlotExtractor.searchQuery(from: "search for swift concurrency"),
            "swift concurrency"
        )
    }

    func testDictationText() {
        XCTAssertEqual(SlotExtractor.dictationText(from: "type hello world"), "hello world")
    }

    func testPercentDigits() {
        XCTAssertEqual(SlotExtractor.numberPercent(from: "set volume to 30 percent"), 30)
    }

    func testPercentWords() {
        XCTAssertEqual(SlotExtractor.numberPercent(from: "set volume to max"), 100)
        XCTAssertEqual(SlotExtractor.numberPercent(from: "set volume to half"), 50)
    }
}
