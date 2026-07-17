import XCTest
@testable import FSDMXVision

final class AIToolRegistryTests: XCTestCase {
    func testParseToolCalls_validJSON() throws {
        let text = #"{"tool_calls":[{"name":"refresh_context","arguments":{}}]}"#
        let calls = try AIToolRegistry.parseToolCalls(from: text)
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls[0].name, "refresh_context")
    }

    func testParseToolCalls_stripsMarkdownFence() throws {
        let text = """
        ```json
        {"tool_calls":[{"name":"export_fixture_ofl_stub","arguments":{"ofl_key":"chauvet-dj/slimpar"}}]}
        ```
        """
        let calls = try AIToolRegistry.parseToolCalls(from: text)
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls[0].name, "export_fixture_ofl_stub")
        XCTAssertTrue(calls[0].argumentsJSON?.contains("slimpar") == true)
    }

    func testParseToolCalls_proseFailsWithFriendlyError() {
        XCTAssertThrowsError(try AIToolRegistry.parseToolCalls(from: "Sure, I'll refresh the context for you.")) { error in
            let msg = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            XCTAssertTrue(msg.contains("wasn’t valid tool-call JSON") || msg.contains("wasn't valid tool-call JSON"), msg)
            XCTAssertTrue(msg.contains("Preview:"), msg)
            XCTAssertTrue(msg.contains("Expected a single object"), msg)
        }
    }

    func testParseToolCalls_missingToolCallsKey() {
        XCTAssertThrowsError(try AIToolRegistry.parseToolCalls(from: #"{"ok":true}"#)) { error in
            guard case AIToolExecutionError.invalidToolCallReply(let detail) = error else {
                return XCTFail("expected invalidToolCallReply, got \(error)")
            }
            XCTAssertTrue(detail.contains("tool_calls"), detail)
        }
    }

    func testParseToolCalls_emptyFails() {
        XCTAssertThrowsError(try AIToolRegistry.parseToolCalls(from: "   ")) { error in
            guard case AIToolExecutionError.invalidToolCallReply(let detail) = error else {
                return XCTFail("expected invalidToolCallReply, got \(error)")
            }
            XCTAssertTrue(detail.contains("empty"), detail)
        }
    }
}
