import Testing
import Foundation
import Darwin
import AppKit
@testable import ViewerApp
@testable import ViewerCore

@Test("recognizes common image documents as supported preview files")
func recognizesCommonImageDocuments() {
    #expect(DocumentKind(url: URL(fileURLWithPath: "/tmp/project/figure.png")) == .image)
    #expect(DocumentKind(url: URL(fileURLWithPath: "/tmp/project/PHOTO.JPEG")) == .image)
    #expect(DocumentKind(url: URL(fileURLWithPath: "/tmp/project/hero.webp")) == .image)
    #expect(DocumentKind(url: URL(fileURLWithPath: "/tmp/project/photo.HEIC")) == .image)
    #expect(DocumentKind(url: URL(fileURLWithPath: "/tmp/project/photo.tiff")) == .other)
}

@Test("resolves existing image documents to an in-app preview")
func resolvesImageDocumentsToPreview() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("viewer-image-open-\(UUID().uuidString)", isDirectory: true)
    let imageURL = root.appendingPathComponent("figure.webp")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data("image fixture".utf8).write(to: imageURL)
    defer { try? FileManager.default.removeItem(at: root) }

    let result = DocumentOpenCoordinator().resolve(imageURL, workspaceRoot: root)

    #expect(result == .preview(documentURL: imageURL.standardizedFileURL, kind: .image, contextURL: nil))
}

@Test("renders a valid image into preview data")
@MainActor
func rendersValidImageIntoPreviewData() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("viewer-image-render-\(UUID().uuidString)", isDirectory: true)
    let imageURL = root.appendingPathComponent("figure.png")
    let imageData = try #require(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="))
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try imageData.write(to: imageURL)
    defer { try? FileManager.default.removeItem(at: root) }

    var renderedOutput: DocumentPreviewOutput?
    let coordinator = DocumentRenderCoordinator { event in
        if case let .ready(_, output) = event {
            renderedOutput = output
        }
    }
    coordinator.render(DocumentRenderRequest(
        tabID: imageURL.path,
        url: imageURL,
        kind: .image,
        projectRoot: root,
        markdownSourceOverride: nil,
        latexRootURL: nil,
        latexShellEscapeMode: .disabled,
        approvedLatexExternalPaths: [:],
        force: false
    ))

    for _ in 0..<20 where renderedOutput == nil {
        try await Task.sleep(for: .milliseconds(10))
    }

    #expect(renderedOutput?.kind == .image)
    #expect(renderedOutput?.imageData == imageData)
}

@Test("image previews support snapshot capture")
@MainActor
func imagePreviewsSupportSnapshotCapture() {
    let url = URL(fileURLWithPath: "/tmp/project/figure.png")
    let model = AppModel()
    model.tabs = [DocumentTab(
        id: url.path,
        url: url,
        kind: .image,
        previewImageData: Data([1])
    )]
    model.activeTabID = url.path

    #expect(model.canCaptureActivePreview)
    model.startSnapshotCapture()
    #expect(model.isSnapshotCaptureActive)
}

@Test("refreshes image previews through the common refresh action")
@MainActor
func refreshesImagePreviewsThroughCommonRefreshAction() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("viewer-image-refresh-\(UUID().uuidString)", isDirectory: true)
    let url = root.appendingPathComponent("figure.png")
    let imageData = try #require(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="))
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try imageData.write(to: url)
    defer { try? FileManager.default.removeItem(at: root) }

    let model = AppModel()
    model.tabs = [DocumentTab(
        id: url.path,
        url: url,
        kind: .image,
        status: .ready,
        previewImageData: imageData
    )]
    model.activeTabID = url.path
    model.refreshActiveTab()

    for _ in 0..<20 where model.tabs[0].status != .ready {
        try await Task.sleep(for: .milliseconds(10))
    }

    #expect(model.tabs[0].status == .ready)
    #expect(model.tabs[0].previewImageData == imageData)
}
