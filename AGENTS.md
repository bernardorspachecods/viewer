---
bkf: document
description: "Agent rules for this repository: structural rules for code and documents, and the `scripts/restart-app.sh` step that ends a work round changing app use."
tags: [agents, workflow]
---

[Repository map](/MAP.md)

Document rules in more depth: [documentation](/repo-library/modules/documentacao.md).

# Repository-specific instructions

## Structural rules (all work)

- Swift files stay at most 500 lines and functions at most 150 lines. Both limits are enforced by `scripts/check-file-size.sh` and `scripts/check-function-size.sh`, each with a baseline (`scripts/file-size-baseline.json`, `scripts/function-size-baseline.json`) that can only go down: never raise or add a pin to pass.
- Anything used in more than one place is defined once. Split files by cohesion, not by count.
- Every new feature or behavior change that is logic (Core, coordination testable without real windows) ships with a test, so earlier behavior does not break. Exempt for now: SwiftUI and AppKit views and the editor view (`SourceTextView` and its extension files). Editing logic in Core (`MarkdownEditing`, merge) is not exempt.
- Docs keep only what would turn false if the intent changed: rules, reasons, boundaries, known gaps. Each topic has one owner document; the others link to it. Update the owner document in the same change as the behavior.

## End of a work round that affects app use 
(doesn’t apply for commits, or documentation changes that dont touch the code)

Do not run this in the middle of a round of changes. Run it only after you have finished working:

```bash
./scripts/restart-app.sh
```

Do not hand off the round until you have confirmed that the script completed the build and opened the app. Explicitly report if the command fails. A failure is not a reason to change another agent's work.
