import XCTest
@testable import CosmicVisualizer

final class FeedbackAndLogsServiceTests: XCTestCase {
    func testParseFeedbackRelayURL_acceptsHttps() {
        let u = FeedbackAndLogsService.parseFeedbackRelayURL("https://relay.example.com/cosmic/feedback")
        XCTAssertEqual(u?.absoluteString, "https://relay.example.com/cosmic/feedback")
    }

    func testParseFeedbackRelayURL_acceptsLocalhostHttp() {
        XCTAssertNotNil(FeedbackAndLogsService.parseFeedbackRelayURL("http://localhost:8787/hook"))
        XCTAssertNotNil(FeedbackAndLogsService.parseFeedbackRelayURL("http://127.0.0.1:9999/"))
    }

    func testParseFeedbackRelayURL_rejectsInsecureRemoteHttp() {
        XCTAssertNil(FeedbackAndLogsService.parseFeedbackRelayURL("http://relay.example.com/feedback"))
    }

    func testParseFeedbackRelayURL_rejectsEmpty() {
        XCTAssertNil(FeedbackAndLogsService.parseFeedbackRelayURL(""))
        XCTAssertNil(FeedbackAndLogsService.parseFeedbackRelayURL("   "))
    }
}
