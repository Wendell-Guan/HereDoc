//
//  ContentView.swift
//  HereDoc
//
//  Created by 123456 on 4/8/26.
//

import HereDocAI
import HereDocModels
import HereDocSearch
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var appModel: HereDocAppModel
    @State private var prompt = "我的护照什么时候过期？"

    var body: some View {
        TabView {
            NavigationStack {
                LibraryHomeView(appModel: appModel)
            }
            .tabItem {
                Label("Library", systemImage: "books.vertical")
            }

            NavigationStack {
                AskHomeView(appModel: appModel, prompt: $prompt)
            }
            .tabItem {
                Label("Ask", systemImage: "bubble.left.and.text.bubble.right")
            }

            NavigationStack {
                StackHomeView(appModel: appModel)
            }
            .tabItem {
                Label("Stack", systemImage: "square.3.layers.3d")
            }
        }
        .tint(.teal)
    }
}

private struct LibraryHomeView: View {
    @Bindable var appModel: HereDocAppModel
    @State private var showingImporter = false
    @State private var showingScanner = false

    var body: some View {
        List {
            Section {
                heroCard
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section("Runtime") {
                InfoTile(title: "Database", value: appModel.databaseStatus, systemImage: "internaldrive")
                InfoTile(title: "Storage Path", value: appModel.databasePath.lastPathComponent, systemImage: "folder")
                InfoTile(title: "Providers", value: "\(appModel.providerProfiles.count)", systemImage: "sparkles")
            }

            Section("Import Status") {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: appModel.isImporting ? "arrow.trianglehead.2.clockwise" : "checkmark.shield")
                        .foregroundStyle(appModel.isImporting ? .teal : .secondary)
                    Text(appModel.importStatus)
                        .font(.callout)
                }
                .padding(.vertical, 4)
            }

            if !appModel.expiringDocuments.isEmpty {
                Section("Expiring Soon") {
                    ForEach(appModel.expiringDocuments) { hit in
                        if let item = appModel.documents.first(where: { $0.id == hit.documentID }) {
                            NavigationLink {
                                DocumentDetailView(
                                    appModel: appModel,
                                    item: item,
                                    initialPageNumber: hit.pageNumber
                                )
                            } label: {
                                ExpiringDocumentRow(hit: hit)
                            }
                        } else {
                            ExpiringDocumentRow(hit: hit)
                        }
                    }
                }
            }

            Section("Documents") {
                if appModel.documents.isEmpty {
                    Text("Your local library is empty. Import a PDF or image to start building searchable evidence.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appModel.documents) { item in
                        NavigationLink {
                            DocumentDetailView(appModel: appModel, item: item)
                        } label: {
                            DocumentRow(item: item)
                        }
                    }
                }
            }
        }
        .navigationTitle("HereDoc")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingScanner = true
                } label: {
                    Label("Scan", systemImage: "camera.viewfinder")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingImporter = true
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.pdf, .image],
            allowsMultipleSelection: true
        ) { result in
            guard case let .success(urls) = result else { return }
            Task {
                await appModel.importFiles(from: urls)
            }
        }
        .sheet(isPresented: $showingScanner) {
            DocumentScannerView { result in
                switch result {
                case let .success(url):
                    Task {
                        await appModel.importFiles(from: [url])
                    }
                case let .failure(error):
                    appModel.importStatus = error.localizedDescription
                }
            } onCancel: {
                appModel.importStatus = "Scan cancelled."
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Local-first document copilot")
                .font(.system(.title2, design: .rounded, weight: .bold))
            Text("Import a PDF or image, extract searchable blocks and fields on-device, then ground every answer back to the page that supports it.")
                .font(.callout)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                CapsuleLabel(title: "Vision OCR", systemImage: "text.viewfinder")
                CapsuleLabel(title: "SQLite FTS5", systemImage: "magnifyingglass")
                CapsuleLabel(title: "Source Cards", systemImage: "paperclip")
            }
            HStack(spacing: 12) {
                Button {
                    showingScanner = true
                } label: {
                    Label("Scan Paper", systemImage: "camera.viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .disabled(appModel.isImporting)

                Button {
                    showingImporter = true
                } label: {
                    Label(appModel.isImporting ? "Importing..." : "Import Files", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.teal)
                .disabled(appModel.isImporting)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.teal.opacity(0.16), .blue.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
}

private struct AskHomeView: View {
    @Bindable var appModel: HereDocAppModel
    @Binding var prompt: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Ask imported documents")
                        .font(.headline)
                    TextField("Ask a document question", text: $prompt, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)

                    Button {
                        Task {
                            await appModel.ask(prompt)
                        }
                    } label: {
                        Label(appModel.isSearching ? "Searching..." : "Search Evidence", systemImage: "magnifyingglass")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)
                    .disabled(appModel.isSearching)

                    Text(appModel.searchStatus)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Query plan")
                        .font(.headline)
                    PlanCard(plan: appModel.previewPlan(for: prompt))
                }

                if let answer = appModel.latestAnswer {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Grounded answer")
                            .font(.headline)
                        Text(answer.answer)
                            .font(.body)
                        ForEach(Array(answer.sources.enumerated()), id: \.offset) { _, source in
                            SourceCard(appModel: appModel, source: source)
                        }
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                }

                if !appModel.latestSearchHits.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Matching passages")
                            .font(.headline)
                        ForEach(appModel.latestSearchHits) { hit in
                            SearchHitRow(appModel: appModel, hit: hit)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Registered AI providers")
                        .font(.headline)
                    ForEach(appModel.providerProfiles) { profile in
                        ProviderCard(profile: profile)
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Ask")
    }
}

private struct StackHomeView: View {
    let appModel: HereDocAppModel

    var body: some View {
        List {
            Section("Core packages") {
                Label("HereDocModels", systemImage: "shippingbox")
                Label("HereDocStorage", systemImage: "internaldrive")
                Label("HereDocSearch", systemImage: "magnifyingglass")
                Label("HereDocAI", systemImage: "cpu")
            }

            Section("Current workflow") {
                Text("Import or OCR first, then search exact fields and full text, and only then hand a small evidence set to AI.")
                Text("The iPhone app currently runs import, OCR, field extraction, indexing, and source-grounded search locally.")
            }

            Section("Next integrations") {
                Label("CloudKit sync", systemImage: "icloud")
                Label("MCP bridge", systemImage: "server.rack")
                Label("Final AI summarizer", systemImage: "sparkles.rectangle.stack")
            }

            Section("Current direction") {
                Text("Deterministic retrieval first, AI last. VisionKit scan capture, Vision OCR, PDFKit source preview, and App Intents shortcuts are the official-first backbone.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Stack")
    }
}

private struct PlanCard: View {
    let plan: QueryPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Primary route: \(plan.primaryRoute.rawValue)", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
            Label("Requires AI: \(plan.requiresAI ? "Yes" : "No")", systemImage: "brain")
            if let fieldHint = plan.fieldHint?.rawValue {
                Label("Field hint: \(fieldHint)", systemImage: "tag")
            }
            if !plan.fallbackRoutes.isEmpty {
                Label("Fallback: \(plan.fallbackRoutes.map(\.rawValue).joined(separator: ", "))", systemImage: "arrow.triangle.branch")
            }
        }
        .font(.callout)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

private struct ProviderCard: View {
    let profile: AIProviderProfile

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name)
                    .font(.headline)
                Text("\(profile.kind.rawValue) · \(profile.model)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if profile.supportsStructuredOutput {
                CapsuleLabel(title: "Structured", systemImage: "checkmark.seal")
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

private struct SearchHitRow: View {
    let appModel: HereDocAppModel
    let hit: SearchHit

    var body: some View {
        if let item = appModel.documents.first(where: { $0.id == hit.documentID }) {
            NavigationLink {
                DocumentDetailView(
                    appModel: appModel,
                    item: item,
                    initialPageNumber: hit.pageNumber,
                    highlightedSnippet: hit.snippet
                )
            } label: {
                SearchResultBody(title: hit.title ?? item.title, subtitle: "Page \(hit.pageNumber)", snippet: hit.snippet)
            }
            .buttonStyle(.plain)
        } else {
            SearchResultBody(title: hit.title ?? "Imported document", subtitle: "Page \(hit.pageNumber)", snippet: hit.snippet)
        }
    }
}

private struct SourceCard: View {
    let appModel: HereDocAppModel
    let source: SourceAnchor

    var body: some View {
        if let item = appModel.documents.first(where: { $0.id == source.documentID }) {
            NavigationLink {
                DocumentDetailView(
                    appModel: appModel,
                    item: item,
                    initialPageNumber: source.pageNumber,
                    highlightedSnippet: source.snippet
                )
            } label: {
                SearchResultBody(title: item.title, subtitle: "Page \(source.pageNumber)", snippet: source.snippet)
            }
            .buttonStyle(.plain)
        } else {
            SearchResultBody(title: "Source", subtitle: "Page \(source.pageNumber)", snippet: source.snippet)
        }
    }
}

private struct SearchResultBody: View {
    let title: String
    let subtitle: String
    let snippet: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(snippet)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

private struct DocumentRow: View {
    let item: DocumentLibraryItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName(for: item.type))
                .font(.title3)
                .frame(width: 34, height: 34)
                .foregroundStyle(.teal)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                Text("\(displayName(for: item.type)) · \(item.pageCount) page\(item.pageCount == 1 ? "" : "s")")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(item.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func iconName(for type: DocumentType) -> String {
        switch type {
        case .passport:
            return "globe.desk"
        case .contract:
            return "doc.text"
        case .invoice, .receipt:
            return "receipt"
        case .certificate:
            return "rosette"
        case .genericImage:
            return "photo"
        default:
            return "doc.richtext"
        }
    }

    private func displayName(for type: DocumentType) -> String {
        switch type {
        case .genericPDF:
            return "PDF"
        case .genericImage:
            return "Image"
        default:
            return type.rawValue.capitalized
        }
    }
}

private struct ExpiringDocumentRow: View {
    let hit: ExpiringDocumentHit

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(hit.documentTitle)
                    .font(.headline)
                Spacer()
                Text(expiryBadgeText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(badgeColor)
            }

            Text("Expires \(hit.displayValue) · Page \(hit.pageNumber)")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var expiryBadgeText: String {
        switch hit.daysRemaining {
        case ..<0:
            return "Expired"
        case 0:
            return "Today"
        case 1:
            return "1 day"
        default:
            return "\(hit.daysRemaining) days"
        }
    }

    private var badgeColor: Color {
        hit.daysRemaining <= 7 ? .red : .orange
    }
}

private struct InfoTile: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.teal)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct CapsuleLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.white.opacity(0.75), in: Capsule())
    }
}

#Preview {
    ContentView(appModel: HereDocAppModel())
}
