import ViewerCore
import Foundation

/// Chooses where a captured reply is saved: a per-CLI folder in Downloads,
/// created when needed, with the file name from `TerminalReplyRules`.
enum TerminalReplyFiles {
    static func nextReplyURL(for client: TerminalReplyClient) throws -> URL {
        guard let downloadsURL = FileManager.default.urls(
            for: .downloadsDirectory,
            in: .userDomainMask
        ).first else {
            throw CocoaError(.fileNoSuchFile)
        }

        let responsesURL = downloadsURL.appendingPathComponent(client.folderName, isDirectory: true)
        try FileManager.default.createDirectory(
            at: responsesURL,
            withIntermediateDirectories: true
        )

        let name = TerminalReplyRules.nextFileName(for: client) { candidate in
            FileManager.default.fileExists(atPath: responsesURL.appendingPathComponent(candidate).path)
        }
        return responsesURL.appendingPathComponent(name)
    }
}
