//
//  DocumentDetailView.swift
//  HereDoc
//
//  Created by Codex on 4/8/26.
//

import HereDocModels
import SwiftUI

struct DocumentDetailView: View {
    @Bindable var appModel: HereDocAppModel
    let item: DocumentLibraryItem
    var initialPageNumber: Int? = nil
    var highlightedSnippet: String? = nil

    @State private var pages: [DocumentPage] = []
    @State private var fields: [ExtractedField] = []

    var body: some View {
        List {
            Section("Overview") {
                LabeledContent("Type", value: item.type.rawValue)
                LabeledContent("Pages", value: "\(item.pageCount)")
                LabeledContent("Updated", value: item.updatedAt.formatted(date: .abbreviated, time: .shortened))
            }

            if let pdfURL {
                Section("Source Preview") {
                    PDFPreviewView(
                        url: pdfURL,
                        initialPageNumber: initialPageNumber,
                        highlightedSnippet: highlightedSnippet
                    )
                    .frame(minHeight: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }

            if !fields.isEmpty {
                Section("Extracted fields") {
                    ForEach(fields) { field in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(field.fieldName.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(field.fieldValue)
                                .font(.body.weight(.medium))
                            Text("Page \(field.pageNumber)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("Pages") {
                ForEach(pages) { page in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Page \(page.pageNumber)")
                                .font(.headline)
                            if page.pageNumber == initialPageNumber {
                                Capsule()
                                    .fill(.teal.opacity(0.18))
                                    .frame(width: 68, height: 26)
                                    .overlay {
                                        Text("Source")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.teal)
                                    }
                            }
                        }
                        Text(page.text.isEmpty ? "No extracted text yet." : page.text)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle(item.title)
        .task(id: item.id) {
            async let loadedPages = appModel.pages(for: item.id)
            async let loadedFields = appModel.fields(for: item.id)
            pages = await loadedPages
            fields = await loadedFields
        }
    }

    private var pdfURL: URL? {
        let url = URL(fileURLWithPath: item.fileLocalPath)
        return url.pathExtension.lowercased() == "pdf" ? url : nil
    }
}
