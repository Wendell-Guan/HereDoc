//
//  DocumentImportPipeline.swift
//  HereDoc
//
//  Created by Codex on 4/8/26.
//

import CryptoKit
import Foundation
import HereDocModels
import HereDocSearch
import PDFKit
import UIKit
import UniformTypeIdentifiers
import Vision

enum DocumentImportError: LocalizedError {
    case unsupportedType
    case failedToLoadImage
    case failedToLoadPDF

    var errorDescription: String? {
        switch self {
        case .unsupportedType:
            return "Only PDF and image files are supported right now."
        case .failedToLoadImage:
            return "The imported image could not be read."
        case .failedToLoadPDF:
            return "The imported PDF could not be opened."
        }
    }
}

actor AppleDocumentImportPipeline {
    private let normalizer = SearchNormalizer()
    private let fieldExtractor = DeterministicFieldExtractor()
    private let fileManager = FileManager.default
    private let libraryRoot: URL

    init(libraryRoot: URL? = nil) {
        self.libraryRoot = libraryRoot ?? Self.defaultLibraryRoot()
    }

    func makePayload(from sourceURL: URL) async throws -> ImportedDocumentPayload {
        let documentID = UUID()
        let documentFolder = libraryRoot
            .appending(path: documentID.uuidString, directoryHint: .isDirectory)

        try fileManager.createDirectory(at: documentFolder, withIntermediateDirectories: true)

        let storedURL = try copyImportedFile(
            from: sourceURL,
            to: documentFolder,
            preferredFilename: "source"
        )
        let title = sourceURL.deletingPathExtension().lastPathComponent
        let checksum = try fileChecksum(for: storedURL)

        let pageBundle: ([DocumentPage], [DocumentBlock], [ExtractedField], String) =
            if isPDF(sourceURL) {
                try await processPDF(
                    documentID: documentID,
                    storedURL: storedURL
                )
            } else if isImage(sourceURL) {
                try await processImage(
                    documentID: documentID,
                    storedURL: storedURL
                )
            } else {
                throw DocumentImportError.unsupportedType
            }

        let combinedText = pageBundle.3
        let document = Document(
            id: documentID,
            title: title,
            type: inferDocumentType(title: title, content: combinedText, fallbackPDF: isPDF(sourceURL)),
            createdAt: Date(),
            updatedAt: Date(),
            pageCount: pageBundle.0.count,
            checksum: checksum,
            cloudKitRecordName: nil,
            fileLocalPath: storedURL.path
        )

        return ImportedDocumentPayload(
            document: document,
            pages: pageBundle.0,
            blocks: pageBundle.1,
            fields: pageBundle.2
        )
    }

    private func processImage(
        documentID: UUID,
        storedURL: URL
    ) async throws -> ([DocumentPage], [DocumentBlock], [ExtractedField], String) {
        guard let image = UIImage(contentsOfFile: storedURL.path) else {
            throw DocumentImportError.failedToLoadImage
        }

        let pageID = UUID()
        let recognition = try await recognizeText(in: image)
        let text = recognition.blocks.map(\.text).joined(separator: "\n")
        let page = DocumentPage(
            id: pageID,
            documentID: documentID,
            pageNumber: 1,
            imageLocalPath: storedURL.path,
            text: text,
            width: image.size.width,
            height: image.size.height
        )

        let blocks = recognition.blocks.map { block in
            DocumentBlock(
                documentID: documentID,
                pageID: pageID,
                pageNumber: 1,
                blockType: .line,
                text: block.text,
                normalizedText: normalizer.normalizeForIndexing(block.text),
                confidence: block.confidence,
                boundingBox: block.boundingBox
            )
        }

        let fields = fieldExtractor.extractFields(from: text, documentID: documentID, pageNumber: 1)
        return ([page], blocks, fields, text)
    }

    private func processPDF(
        documentID: UUID,
        storedURL: URL
    ) async throws -> ([DocumentPage], [DocumentBlock], [ExtractedField], String) {
        guard let pdfDocument = PDFDocument(url: storedURL) else {
            throw DocumentImportError.failedToLoadPDF
        }

        var pages: [DocumentPage] = []
        var blocks: [DocumentBlock] = []
        var fields: [ExtractedField] = []
        var joinedText: [String] = []

        for index in 0..<pdfDocument.pageCount {
            guard let pdfPage = pdfDocument.page(at: index) else { continue }

            let pageID = UUID()
            let pageNumber = index + 1
            let bounds = pdfPage.bounds(for: .mediaBox)
            let rawText = pdfPage.string?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            let pageText: String
            let pageBlocks: [DocumentBlock]

            if rawText.isEmpty {
                let preview = renderPreviewImage(for: pdfPage)
                let recognition = try await recognizeText(in: preview)
                pageText = recognition.blocks.map(\.text).joined(separator: "\n")
                pageBlocks = recognition.blocks.map { block in
                    DocumentBlock(
                        documentID: documentID,
                        pageID: pageID,
                        pageNumber: pageNumber,
                        blockType: .line,
                        text: block.text,
                        normalizedText: normalizer.normalizeForIndexing(block.text),
                        confidence: block.confidence,
                        boundingBox: block.boundingBox
                    )
                }
            } else {
                pageText = rawText
                pageBlocks = makeParagraphBlocks(
                    from: rawText,
                    documentID: documentID,
                    pageID: pageID,
                    pageNumber: pageNumber
                )
            }

            pages.append(
                DocumentPage(
                    id: pageID,
                    documentID: documentID,
                    pageNumber: pageNumber,
                    imageLocalPath: nil,
                    text: pageText,
                    width: bounds.width,
                    height: bounds.height
                )
            )
            blocks.append(contentsOf: pageBlocks)
            fields.append(contentsOf: fieldExtractor.extractFields(from: pageText, documentID: documentID, pageNumber: pageNumber))
            joinedText.append(pageText)
        }

        return (pages, blocks, fields, joinedText.joined(separator: "\n"))
    }

    private func makeParagraphBlocks(
        from rawText: String,
        documentID: UUID,
        pageID: UUID,
        pageNumber: Int
    ) -> [DocumentBlock] {
        rawText
            .components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { segment in
                let blockType: BlockType
                if segment.count < 48, segment == segment.uppercased() {
                    blockType = .title
                } else {
                    blockType = .paragraph
                }

                return DocumentBlock(
                    documentID: documentID,
                    pageID: pageID,
                    pageNumber: pageNumber,
                    blockType: blockType,
                    text: segment,
                    normalizedText: normalizer.normalizeForIndexing(segment),
                    confidence: nil,
                    boundingBox: nil
                )
            }
    }

    private func renderPreviewImage(for page: PDFPage) -> UIImage {
        let bounds = page.bounds(for: .mediaBox)
        let maxDimension = max(bounds.width, bounds.height)
        let scale = maxDimension > 1800 ? 1800 / maxDimension : 1
        let size = CGSize(width: max(bounds.width * scale, 800), height: max(bounds.height * scale, 1000))
        return page.thumbnail(of: size, for: .mediaBox)
    }

    private func copyImportedFile(from sourceURL: URL, to directory: URL, preferredFilename: String) throws -> URL {
        let ext = sourceURL.pathExtension.isEmpty ? "bin" : sourceURL.pathExtension
        let destinationURL = directory.appending(path: "\(preferredFilename).\(ext)", directoryHint: .notDirectory)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }

    private func fileChecksum(for fileURL: URL) throws -> String {
        let data = try Data(contentsOf: fileURL)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func recognizeText(in image: UIImage) async throws -> OCRPageResult {
        try await Task.detached(priority: .userInitiated) {
            guard let cgImage = Self.normalizedCGImage(from: image) else {
                throw DocumentImportError.failedToLoadImage
            }

            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.minimumTextHeight = 0.015
            request.recognitionLanguages = ["en-US", "zh-Hans", "zh-Hant"]

            let handler = VNImageRequestHandler(cgImage: cgImage)
            try handler.perform([request])

            let observations = request.results ?? []
            let blocks = observations.compactMap { observation -> OCRBlock? in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return nil }

                let box = observation.boundingBox
                return OCRBlock(
                    text: text,
                    confidence: Double(candidate.confidence),
                    boundingBox: BoundingBox(
                        x: box.origin.x,
                        y: box.origin.y,
                        width: box.width,
                        height: box.height
                    )
                )
            }

            return OCRPageResult(blocks: blocks)
        }.value
    }

    private static func normalizedCGImage(from image: UIImage) -> CGImage? {
        if let cgImage = image.cgImage {
            return cgImage
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        return rendered.cgImage
    }

    private func inferDocumentType(title: String, content: String, fallbackPDF: Bool) -> DocumentType {
        let corpus = "\(title) \(content)".lowercased()

        if corpus.contains("passport") || corpus.contains("护照") {
            return .passport
        }
        if corpus.contains("contract") || corpus.contains("agreement") || corpus.contains("合同") {
            return .contract
        }
        if corpus.contains("invoice") || corpus.contains("发票") {
            return .invoice
        }
        if corpus.contains("certificate") || corpus.contains("证书") {
            return .certificate
        }
        if corpus.contains("receipt") || corpus.contains("收据") {
            return .receipt
        }
        return fallbackPDF ? .genericPDF : .genericImage
    }

    private func isPDF(_ url: URL) -> Bool {
        if let contentType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
            return contentType.conforms(to: .pdf)
        }
        return UTType(filenameExtension: url.pathExtension)?.conforms(to: .pdf) == true
    }

    private func isImage(_ url: URL) -> Bool {
        if let contentType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
            return contentType.conforms(to: .image)
        }
        return UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true
    }

    private static func defaultLibraryRoot() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return support
            .appending(path: "HereDoc", directoryHint: .isDirectory)
            .appending(path: "ImportedDocuments", directoryHint: .isDirectory)
    }
}

private struct OCRPageResult {
    var blocks: [OCRBlock]
}

private struct OCRBlock {
    var text: String
    var confidence: Double
    var boundingBox: BoundingBox
}
