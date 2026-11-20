---
bkf: document
description: "User-visible behavior of the image previews (PNG, JPEG, WebP, HEIC/HEIF) and the Word (.docx) preview: read-only display, fit and zoom, refresh, and search."
tags: [behavior, images, word]
---

# Images and Word

## Images

- PNG, JPG and JPEG, WebP, and HEIC and HEIF files open in a read-only preview.
- The image fits the window by default and scrolls when enlarged. It uses the tab
  zoom and supports manual refresh.
- The preview updates automatically when the file changes, and supports snapshot
  capture.

## Word

- Text in a Word preview is not copied on select: the preview runs no scripts. See
  [view-controls.md](/docs/behavior/view-controls.md#selection).

- `.docx` files are converted locally to rich HTML and shown on a page with a
  background and a responsive zoom. The zoom is the tab's zoom.
- The Word preview takes part in search for the active tab.
