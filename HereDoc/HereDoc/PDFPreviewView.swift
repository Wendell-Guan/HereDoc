//
//  PDFPreviewView.swift
//  HereDoc
//
//  Created by Codex on 4/8/26.
//

import PDFKit
import SwiftUI

struct PDFPreviewView: UIViewRepresentable {
    let url: URL
    var initialPageNumber: Int?
    var highlightedSnippet: String?

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        pdfView.backgroundColor = .secondarySystemBackground
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        if pdfView.document?.documentURL != url {
            pdfView.document = PDFDocument(url: url)
        }

        guard let document = pdfView.document else { return }

        pdfView.highlightedSelections = nil

        if let snippet = cleanedSnippet(highlightedSnippet),
           !snippet.isEmpty,
           let selection = document.findString(snippet, withOptions: [.caseInsensitive, .diacriticInsensitive]).first {
            pdfView.highlightedSelections = [selection]
            pdfView.go(to: selection)
            return
        }

        if let initialPageNumber {
            let index = max(0, min(initialPageNumber - 1, document.pageCount - 1))
            if let page = document.page(at: index) {
                pdfView.go(to: page)
            }
        }
    }

    private func cleanedSnippet(_ rawSnippet: String?) -> String? {
        rawSnippet?
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .replacingOccurrences(of: " … ", with: " ")
            .replacingOccurrences(of: "…", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
