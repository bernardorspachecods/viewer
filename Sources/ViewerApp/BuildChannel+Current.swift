import Foundation
import ViewerCore

extension BuildChannel {
    /// The channel of the running bundle. The only place the Info.plist key is read.
    static let current = BuildChannel(
        infoValue: Bundle.main.object(forInfoDictionaryKey: infoPlistKey) as? String
    )
}
