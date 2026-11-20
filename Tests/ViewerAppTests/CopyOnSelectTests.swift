import Foundation
import Testing
import ViewerCore

@Test("copy on select writes a non-empty selection only when the setting is on")
func copyOnSelectRespectsSetting() {
    #expect(CopyOnSelectRule.textToCopy("hello", enabled: true) == "hello")
    #expect(CopyOnSelectRule.textToCopy("hello", enabled: false) == nil)
}

@Test("an empty or whitespace-only selection never reaches the pasteboard")
func emptySelectionIsNotCopied() {
    #expect(CopyOnSelectRule.textToCopy(nil, enabled: true) == nil)
    #expect(CopyOnSelectRule.textToCopy("", enabled: true) == nil)
    #expect(CopyOnSelectRule.textToCopy(" \n\t ", enabled: true) == nil)
}

@Test("older saved state without the copy-on-select key decodes to on")
func oldStateDefaultsCopyOnSelectOn() throws {
    let global = try JSONDecoder().decode(GlobalState.self, from: Data(#"{"theme":"light"}"#.utf8))
    #expect(global.copyOnSelect == true)
}

@Test("a saved copy-on-select choice survives a round trip")
func copyOnSelectRoundTrips() throws {
    var global = GlobalState()
    global.copyOnSelect = false
    let data = try JSONEncoder().encode(global)
    let decoded = try JSONDecoder().decode(GlobalState.self, from: data)
    #expect(decoded.copyOnSelect == false)
}
