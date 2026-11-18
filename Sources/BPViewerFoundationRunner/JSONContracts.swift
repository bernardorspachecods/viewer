import BPViewerCore
import Foundation

extension Runner {
    mutating func runJSONFormatContracts() {
        do {
            let formatted = try JSONPreviewAdapter().format(source: "{\"z\": 1, \"a\": [true, null]}")
            expect(formatted == "{\n  \"z\": 1,\n  \"a\": [\n    true,\n    null\n  ]\n}", "JSON is validated and formatted")
        } catch {
            expect(false, "JSON is validated and formatted")
        }

        do {
            _ = try JSONPreviewAdapter().format(source: "{\"missing\": }")
            expect(false, "invalid JSON is rejected for editing")
        } catch is JSONPreviewError {
            expect(true, "invalid JSON is rejected for editing")
        } catch {
            expect(false, "invalid JSON is rejected for editing")
        }

        do {
            _ = try JSONPreviewAdapter().format(source: "{\"value\": \"texto”\n}")
            expect(false, "JSON errors report line and character")
        } catch let error as JSONPreviewError {
            expect(
                error.localizedDescription.contains("line")
                    && error.localizedDescription.contains("character"),
                "JSON errors report line and character"
            )
        } catch {
            expect(false, "JSON errors report line and character")
        }
    }

    mutating func runJSONSyntaxContracts() {
        let syntaxTokens = JSONSyntaxHighlighter().tokenize(
            "{\"name\": \"bp\", \"count\": 2, \"active\": true, \"missing\": null}"
        )
        let syntaxKinds = Set(syntaxTokens.map(\.kind))
        expect(
            syntaxKinds.isSuperset(of: [.punctuation, .key, .string, .number, .boolean, .null]),
            "JSON syntax highlighting tokenizes JSON values"
        )
        let invalidSyntaxTokens = JSONSyntaxHighlighter().tokenize("{\"value\": \"bad\n\"}")
        expect(
            invalidSyntaxTokens.contains(where: { $0.kind == .invalid }),
            "JSON syntax highlighting marks invalid characters"
        )
    }

    mutating func runJSONPreviewContracts() {
        do {
            let formatted = try JSONPreviewAdapter().format(
                source: "{\"z\":0,\"a\":1,\"middle\":2,\"nested\":{\"last\":3,\"first\":4}}"
            )
            expect(
                formatted == "{\n  \"z\": 0,\n  \"a\": 1,\n  \"middle\": 2,\n  \"nested\": {\n    \"last\": 3,\n    \"first\": 4\n  }\n}",
                "JSON preview preserves source key order"
            )
        } catch {
            expect(false, "JSON preview preserves source key order")
        }

        do {
            _ = try JSONPreviewAdapter().format(source: """
            {
              "schema_version": "1.1.0",
              "status": "in_progress",
              "title": "Discovering and Forecasting Emerging AI Capabilities from Patent Data: A Reproducible Data Science Pipeline",
              "supervisor": "Bruno Damásio",
              "deadline": null,
              "created_at": "2026-04-17",
              "last_updated": "2026-09-13"
            }
            """)
            expect(true, "valid JSON with accented text can be corrected and saved")
        } catch {
            expect(false, "valid JSON with accented text can be corrected and saved")
        }

        let originalJSON = "{\"title\":\"A\",\"value\":1}"
        let formattedJSON = (try? JSONPreviewAdapter().format(source: originalJSON)) ?? ""
        if let valueRange = formattedJSON.range(of: "\"value\"") {
            let formattedOffset = formattedJSON.utf8.distance(
                from: formattedJSON.utf8.startIndex,
                to: valueRange.lowerBound.samePosition(in: formattedJSON.utf8)!
            )
            let originalOffset = JSONPreviewAdapter().sourceOffset(
                forFormattedUTF8Offset: formattedOffset,
                source: originalJSON,
                formattedSource: formattedJSON
            )
            let expectedOffset = originalJSON.utf8.distance(
                from: originalJSON.utf8.startIndex,
                to: originalJSON.range(of: "\"value\"")!.lowerBound.samePosition(in: originalJSON.utf8)!
            )
            expect(originalOffset == expectedOffset, "JSON preview clicks map to raw source offsets")
        } else {
            expect(false, "JSON preview clicks map to raw source offsets")
        }
    }
}
