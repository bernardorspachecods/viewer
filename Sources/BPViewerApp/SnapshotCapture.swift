import AppKit
import PDFKit

struct SnapshotImageSegment {
    let documentRect: CGRect
    let image: NSImage
}

@MainActor
enum SnapshotImageComposer {
    static func compose(segments: [SnapshotImageSegment], documentRect: CGRect) -> NSImage? {
        let image = NSImage(size: documentRect.size)
        image.lockFocusFlipped(false)
        for segment in segments {
            let destination = CGRect(
                x: segment.documentRect.minX - documentRect.minX,
                y: segment.documentRect.minY - documentRect.minY,
                width: segment.documentRect.width,
                height: segment.documentRect.height
            )
            segment.image.draw(in: destination, from: .zero, operation: .copy, fraction: 1)
        }
        image.unlockFocus()
        return image
    }
}

@MainActor
enum SnapshotPDFCapture {
    static func image(of documentRect: CGRect, in scrollView: NSScrollView) -> NSImage? {
        guard let pdfView = ancestorPDFView(of: scrollView),
              let document = pdfView.document,
              let documentView = scrollView.documentView,
              !documentRect.isNull,
              documentRect.width > 1,
              documentRect.height > 1 else {
            return nil
        }

        let selectionInPDFView = documentView.convert(documentRect, to: pdfView)
        guard !selectionInPDFView.isNull,
              selectionInPDFView.width > 1,
              selectionInPDFView.height > 1 else {
            return nil
        }

        let image = NSImage(size: selectionInPDFView.size)
        image.lockFocusFlipped(false)
        NSColor.white.setFill()
        CGRect(origin: .zero, size: selectionInPDFView.size).fill()

        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return nil
        }

        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }

            let pageBounds = page.bounds(for: .cropBox)
            let pageRectInPDFView = pdfView.convert(pageBounds, from: page)
            let intersection = selectionInPDFView.intersection(pageRectInPDFView)
            guard !intersection.isNull,
                  intersection.width > 0,
                  intersection.height > 0,
                  pageBounds.width > 0,
                  pageBounds.height > 0 else {
                continue
            }

            let destination = CGRect(
                x: intersection.minX - selectionInPDFView.minX,
                y: intersection.minY - selectionInPDFView.minY,
                width: intersection.width,
                height: intersection.height
            )
            let scaleX = pageRectInPDFView.width / pageBounds.width
            let scaleY = pageRectInPDFView.height / pageBounds.height
            guard scaleX > 0, scaleY > 0 else { continue }

            context.saveGState()
            context.clip(to: destination)
            context.translateBy(
                x: pageRectInPDFView.minX - selectionInPDFView.minX,
                y: pageRectInPDFView.minY - selectionInPDFView.minY
            )
            context.scaleBy(x: scaleX, y: scaleY)
            context.translateBy(x: -pageBounds.minX, y: -pageBounds.minY)
            page.draw(with: .cropBox, to: context)
            context.restoreGState()
        }

        image.unlockFocus()
        return image
    }

    private static func ancestorPDFView(of view: NSView) -> PDFView? {
        var candidate: NSView? = view
        while let current = candidate {
            if let pdfView = current as? PDFView {
                return pdfView
            }
            candidate = current.superview
        }
        return nil
    }
}

@MainActor
enum SnapshotWindowCapture {
    static func image(of rectInView: CGRect, in view: NSView) -> NSImage? {
        guard let contentView = view.window?.contentView,
              let representation = contentView.bitmapImageRepForCachingDisplay(in: contentView.bounds) else {
            return nil
        }

        contentView.cacheDisplay(in: contentView.bounds, to: representation)
        let contentRect = view.convert(rectInView, to: contentView)
            .intersection(contentView.bounds)
        guard !contentRect.isNull, contentRect.width > 1, contentRect.height > 1 else {
            return nil
        }

        // The SwiftUI/AppKit view hierarchy may be flipped, while the bitmap
        // representation uses a bottom-left origin. Convert the selected view
        // rect before drawing it out of the cached window image.
        let bitmapRect = CGRect(
            x: contentRect.minX,
            y: contentView.bounds.maxY - contentRect.maxY,
            width: contentRect.width,
            height: contentRect.height
        )

        let scaleX = CGFloat(representation.pixelsWide) / max(contentView.bounds.width, 1)
        let scaleY = CGFloat(representation.pixelsHigh) / max(contentView.bounds.height, 1)
        let pixelRect = CGRect(
            x: floor(bitmapRect.minX * scaleX),
            // NSBitmapImageRep's source rect is bottom-left based; CGImage's
            // crop rect addresses the raw pixel rows from the opposite edge.
            y: floor(CGFloat(representation.pixelsHigh) - bitmapRect.maxY * scaleY),
            width: ceil(bitmapRect.width * scaleX),
            height: ceil(bitmapRect.height * scaleY)
        ).intersection(CGRect(
            x: 0,
            y: 0,
            width: representation.pixelsWide,
            height: representation.pixelsHigh
        ))

        if let sourceImage = representation.cgImage,
           let croppedImage = sourceImage.cropping(to: pixelRect) {
            let croppedRepresentation = NSBitmapImageRep(cgImage: croppedImage)
            croppedRepresentation.size = contentRect.size
            let image = NSImage(size: contentRect.size)
            image.addRepresentation(croppedRepresentation)
            return image
        }

        // Keep the working AppKit path as a fallback if a bitmap cannot be cropped.
        let image = NSImage(size: contentRect.size)
        image.lockFocusFlipped(false)
        representation.draw(
            in: CGRect(origin: .zero, size: contentRect.size),
            from: bitmapRect,
            operation: .copy,
            fraction: 1,
            respectFlipped: false,
            hints: nil
        )
        image.unlockFocus()
        return image
    }
}
