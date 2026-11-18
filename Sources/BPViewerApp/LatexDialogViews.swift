import BPViewerCore
import SwiftUI

struct LatexRootSelectionView: View {
    @EnvironmentObject private var model: AppModel
    let request: LatexRootSelectionRequest
    @State private var selectedRoot: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: BPTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: BPTokens.Spacing.xxs) {
                Text("Choose Main LaTeX Document")
                    .font(.title2.weight(.semibold))
                Text(
                    request.candidates.isEmpty
                        ? "The main document could not be identified automatically. Your manual choice will be saved for future compilations."
                        : "Several main documents were found in this project. Your choice will be saved for future compilations."
                )
                    .font(BPTokens.Typography.body)
                    .foregroundStyle(BPTokens.Color.muted)
            }

            if request.candidates.isEmpty {
                VStack(alignment: .leading, spacing: BPTokens.Spacing.sm) {
                    Text("No main document was found automatically in this folder.")
                        .font(BPTokens.Typography.body)
                        .foregroundStyle(BPTokens.Color.muted)
                    Button("Choose Main File…") {
                        model.chooseLatexRootFile()
                    }
                    .buttonStyle(.borderedProminent)
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(spacing: BPTokens.Spacing.xs) {
                        ForEach(request.candidates, id: \.url) { candidate in
                            Button {
                                selectedRoot = candidate.url
                            } label: {
                                HStack(spacing: BPTokens.Spacing.sm) {
                                    Image(systemName: selectedRoot == candidate.url ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedRoot == candidate.url ? Color.accentColor : BPTokens.Color.muted)
                                    VStack(alignment: .leading, spacing: BPTokens.Spacing.xxs) {
                                        Text(candidate.url.lastPathComponent)
                                            .font(BPTokens.Typography.body.weight(.medium))
                                        Text(relativePath(candidate.url))
                                            .font(BPTokens.Typography.caption)
                                            .foregroundStyle(BPTokens.Color.muted)
                                    }
                                    Spacer()
                                }
                                .padding(BPTokens.Spacing.sm)
                                .background(
                                    selectedRoot == candidate.url
                                        ? BPTokens.Color.selection
                                        : BPTokens.Color.surface
                                )
                                .clipShape(RoundedRectangle(cornerRadius: BPTokens.Radius.sm))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    model.cancelLatexRootSelection()
                }
                Button("Choose") {
                    guard let selectedRoot else { return }
                    model.chooseLatexRoot(selectedRoot)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedRoot == nil || request.candidates.isEmpty)
            }
        }
        .padding(BPTokens.Spacing.lg)
        .frame(width: 560, height: 390)
        .onAppear {
            selectedRoot = request.candidates.first?.url
        }
    }

    private func relativePath(_ url: URL) -> String {
        let rootPath = request.projectRoot.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        return path == rootPath ? "." : String(path.dropFirst(rootPath.count + 1))
    }
}

struct LatexExternalDependencyView: View {
    @EnvironmentObject private var model: AppModel
    let request: LatexExternalDependencyRequest

    var body: some View {
        VStack(alignment: .leading, spacing: BPTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: BPTokens.Spacing.xxs) {
                Text("Confirm External Dependencies")
                    .font(.title2.weight(.semibold))
                Text("The main document references files outside the project folder. Compilation will continue only after you confirm.")
                    .font(BPTokens.Typography.body)
                    .foregroundStyle(BPTokens.Color.muted)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: BPTokens.Spacing.xs) {
                    ForEach(request.dependencies, id: \.url) { dependency in
                        VStack(alignment: .leading, spacing: BPTokens.Spacing.xxs) {
                            Text(dependency.url.path)
                                .font(BPTokens.Typography.code)
                                .textSelection(.enabled)
                            Text("Referenced by \(dependency.sourceURL.lastPathComponent)")
                                .font(BPTokens.Typography.caption)
                                .foregroundStyle(BPTokens.Color.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(BPTokens.Spacing.sm)
                        .background(BPTokens.Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: BPTokens.Radius.sm))
                    }
                }
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    model.cancelLatexExternalDependencies()
                }
                Button("Allow and Compile") {
                    model.approveLatexExternalDependencies()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(BPTokens.Spacing.lg)
        .frame(width: 620, height: 390)
    }
}
