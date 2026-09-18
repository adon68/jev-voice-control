import XCTest
@testable import JevVoiceCore

final class JevModelsTests: XCTestCase {
    func testDecodeResponse() throws {
        let json = """
        {
          "model": "jev-1.13.0",
          "answers": {
            "action": {
              "type": "choice",
              "choice": "openApp",
              "confidence": 0.95,
              "probabilities": {"openApp": 0.96, "none": 0.04}
            },
            "mentions_url": {"type": "noul", "noul": 0.99},
            "lvl": {
              "type": "score",
              "score": 0.97,
              "confidence": 0.9,
              "legend": {"0": "low"},
              "probabilities": {"0": 0.05, "1": 0.93}
            }
          },
          "usage": {"input_tokens": 631, "output_tokens": 180}
        }
        """
        let response = try JSONDecoder().decode(SystemOneResponse.self, from: Data(json.utf8))
        XCTAssertEqual(response.model, "jev-1.13.0")
        XCTAssertEqual(response.usage?.inputTokens, 631)

        guard case .choice(let choice, let confidence, let probs) = response.answers["action"] else {
            return XCTFail("action should decode as choice")
        }
        XCTAssertEqual(choice, "openApp")
        XCTAssertEqual(confidence, 0.95)
        XCTAssertEqual(probs["openApp"], 0.96)

        guard case .noul(let p) = response.answers["mentions_url"] else {
            return XCTFail("mentions_url should decode as noul")
        }
        XCTAssertEqual(p, 0.99)

        guard case .score(let score, _, _, let legend) = response.answers["lvl"] else {
            return XCTFail("lvl should decode as score")
        }
        XCTAssertEqual(score, 0.97)
        XCTAssertEqual(legend["0"], "low")
    }

    func testEncodeRequestShape() throws {
        struct S: Encodable { let clause: String }
        let request = SystemOneRequest(
            model: "jev-latest",
            state: S(clause: "open chrome"),
            questions: [
                "action": .choice(
                    instructions: "pick",
                    criteria: ["openApp": "Open an app", "none": nil]
                ),
                "mentions": .noul(instructions: "mentions url?"),
                "lvl": .score(instructions: "rate", levels: ["low", "high"]),
            ]
        )
        let data = try JSONEncoder().encode(request)
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(obj["model"] as? String, "jev-latest")
        let state = obj["state"] as! [String: Any]
        XCTAssertEqual(state["clause"] as? String, "open chrome")

        let questions = obj["questions"] as! [String: [String: Any]]
        let action = questions["action"]!
        XCTAssertEqual(action["type"] as? String, "choice")
        let criteria = action["criteria"] as! [String: Any]
        XCTAssertEqual(criteria["openApp"] as? String, "Open an app")
        XCTAssertTrue(criteria.keys.contains("none"))

        XCTAssertEqual(questions["mentions"]?["type"] as? String, "noul")

        let score = questions["lvl"]!
        XCTAssertEqual(score["type"] as? String, "score")
        XCTAssertEqual(score["criteria"] as? [String], ["low", "high"])
    }
}
