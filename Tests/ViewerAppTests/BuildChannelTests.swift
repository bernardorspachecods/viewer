import Testing
import ViewerCore

@Test("a missing channel key counts as development")
func missingChannelIsDevelopment() {
    #expect(BuildChannel(infoValue: nil).isDevelopment)
}

@Test("the dev channel counts as development")
func devChannelIsDevelopment() {
    #expect(BuildChannel(infoValue: "dev").isDevelopment)
}

@Test("only the exact release value is the release channel")
func releaseChannelIsNotDevelopment() {
    #expect(!BuildChannel(infoValue: "release").isDevelopment)
}

@Test("an empty channel value counts as development")
func emptyChannelIsDevelopment() {
    #expect(BuildChannel(infoValue: "").isDevelopment)
}

@Test("the release value is case-sensitive: Release counts as development")
func releaseIsCaseSensitive() {
    #expect(BuildChannel(infoValue: "Release").isDevelopment)
}

@Test("an unknown channel value counts as development")
func unknownChannelIsDevelopment() {
    #expect(BuildChannel(infoValue: "unknown").isDevelopment)
}

@Test("a development window title gets the DEV marker")
func developmentTitleHasMarker() {
    #expect(BuildChannel(infoValue: "dev").windowTitle(base: "Notes") == "Notes — DEV")
}

@Test("a release window title is unchanged")
func releaseTitleIsUnchanged() {
    #expect(BuildChannel(infoValue: "release").windowTitle(base: "Notes") == "Notes")
}
