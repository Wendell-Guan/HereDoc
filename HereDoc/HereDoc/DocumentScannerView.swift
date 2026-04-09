//
//  DocumentScannerView.swift
//  HereDoc
//
//  Created by Codex on 4/8/26.
//

import SwiftUI
import UIKit
import VisionKit

struct DocumentScannerView: UIViewControllerRepresentable {
    let onResult: (Result<URL, Error>) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onResult: onResult, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let onResult: (Result<URL, Error>) -> Void
        private let onCancel: () -> Void

        init(onResult: @escaping (Result<URL, Error>) -> Void, onCancel: @escaping () -> Void) {
            self.onResult = onResult
            self.onCancel = onCancel
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            do {
                let url = try ScannedPDFBuilder.makeTemporaryPDF(from: scan)
                controller.dismiss(animated: true) {
                    self.onResult(.success(url))
                }
            } catch {
                controller.dismiss(animated: true) {
                    self.onResult(.failure(error))
                }
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true) {
                self.onCancel()
            }
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            controller.dismiss(animated: true) {
                self.onResult(.failure(error))
            }
        }
    }
}

private enum ScannedPDFBuilder {
    static func makeTemporaryPDF(from scan: VNDocumentCameraScan) throws -> URL {
        let tempFolder = FileManager.default.temporaryDirectory
            .appending(path: "HereDocScans", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: tempFolder, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "Scan_\(formatter.string(from: Date())).pdf"
        let outputURL = tempFolder.appending(path: filename, directoryHint: .notDirectory)

        let images = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
        try renderPDF(images: images, to: outputURL)
        return outputURL
    }

    private static func renderPDF(images: [UIImage], to outputURL: URL) throws {
        guard let first = images.first else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let baseBounds = CGRect(origin: .zero, size: normalizedPageSize(for: first))
        let renderer = UIGraphicsPDFRenderer(bounds: baseBounds)
        try renderer.writePDF(to: outputURL) { context in
            for image in images {
                let pageBounds = CGRect(origin: .zero, size: normalizedPageSize(for: image))
                context.beginPage(withBounds: pageBounds, pageInfo: [:])
                image.draw(in: fittedRect(for: image.size, inside: pageBounds.insetBy(dx: 12, dy: 12)))
            }
        }
    }

    private static func normalizedPageSize(for image: UIImage) -> CGSize {
        let size = image.size
        if size.width <= 0 || size.height <= 0 {
            return CGSize(width: 1000, height: 1400)
        }
        return size
    }

    private static func fittedRect(for imageSize: CGSize, inside bounds: CGRect) -> CGRect {
        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let drawSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(
            x: bounds.midX - drawSize.width / 2,
            y: bounds.midY - drawSize.height / 2
        )
        return CGRect(origin: origin, size: drawSize)
    }
}
