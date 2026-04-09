//
//  HereDocAppModel.swift
//  HereDoc
//
//  Created by Codex on 4/8/26.
//

import AppIntents
import Foundation
import HereDocAI
import HereDocModels
import HereDocSearch
import HereDocStorage
import Observation

@MainActor
@Observable
final class HereDocAppModel {
    var databaseStatus = "Booting"
    var databasePath: URL
    var providerProfiles: [AIProviderProfile] = []
    var documents: [DocumentLibraryItem] = []
    var expiringDocuments: [ExpiringDocumentHit] = []
    var latestAnswer: GroundedAnswer?
    var latestSearchHits: [SearchHit] = []
    var importStatus = "Ready to import PDF or image files."
    var searchStatus = "Ask a question after importing at least one document."
    var isImporting = false
    var isSearching = false

    private let queryEngine = HereDocRuntime.queryEngine
    private let importer = AppleDocumentImportPipeline()
    private var documentStore: LocalDocumentStore?

    init() {
        self.databasePath = HereDocRuntime.databaseURL()
        bootstrap()
    }

    func previewPlan(for question: String) -> QueryPlan {
        queryEngine.previewPlan(for: question)
    }

    func importFiles(from urls: [URL]) async {
        guard let documentStore else {
            importStatus = "Database is not ready yet."
            return
        }

        isImporting = true
        importStatus = "Importing \(urls.count) file(s)..."
        defer { isImporting = false }

        do {
            var importedTitles: [String] = []

            for url in urls {
                let scoped = url.startAccessingSecurityScopedResource()
                defer {
                    if scoped {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                let payload = try await importer.makePayload(from: url)
                try await documentStore.saveImportedDocument(payload)
                importedTitles.append(payload.document.title)
            }

            await refreshLibrary()
            await refreshExpiringDocuments()
            HereDocShortcuts.updateAppShortcutParameters()
            importStatus = "Imported \(importedTitles.joined(separator: ", "))."
        } catch {
            importStatus = error.localizedDescription
        }
    }

    func ask(_ question: String) async {
        guard let documentStore else {
            searchStatus = "Database is not ready yet."
            return
        }

        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            latestAnswer = nil
            latestSearchHits = []
            searchStatus = "Enter a question first."
            return
        }

        isSearching = true
        searchStatus = "Searching imported evidence..."
        defer { isSearching = false }

        do {
            let result = try await queryEngine.answer(question: trimmed, using: documentStore)
            latestAnswer = result.answer
            latestSearchHits = result.hits
            searchStatus = result.status
        } catch {
            searchStatus = error.localizedDescription
        }
    }

    func pages(for documentID: UUID) async -> [DocumentPage] {
        guard let documentStore else { return [] }
        do {
            return try await documentStore.fetchPages(for: documentID)
        } catch {
            return []
        }
    }

    func fields(for documentID: UUID) async -> [ExtractedField] {
        guard let documentStore else { return [] }
        do {
            return try await documentStore.fetchFields(for: documentID)
        } catch {
            return []
        }
    }

    private func bootstrap() {
        do {
            let folder = databasePath.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            documentStore = try LocalDocumentStore(databaseURL: databasePath)
            databaseStatus = "Ready"
        } catch {
            databaseStatus = "Failed"
            importStatus = "Database failed to initialize."
        }

        providerProfiles = [
            AIProviderProfile(
                name: "OpenAI",
                kind: .openAI,
                baseURL: URL(string: "https://api.openai.com/v1")!,
                model: "gpt-5-mini",
                credentialSource: .keychain(account: "openai_api_key"),
                supportsStructuredOutput: true,
                supportsVision: true
            ),
            AIProviderProfile(
                name: "Anthropic",
                kind: .anthropic,
                baseURL: URL(string: "https://api.anthropic.com")!,
                model: "claude-sonnet",
                credentialSource: .keychain(account: "anthropic_api_key"),
                supportsStructuredOutput: true,
                supportsVision: true
            ),
            AIProviderProfile(
                name: "OpenAI-compatible",
                kind: .openAICompatible,
                baseURL: URL(string: "http://localhost:11434/v1")!,
                model: "custom-endpoint",
                credentialSource: .none,
                supportsStructuredOutput: false,
                supportsVision: false
            ),
        ]

        Task {
            await refreshLibrary()
            await refreshExpiringDocuments()
            HereDocShortcuts.updateAppShortcutParameters()
        }
    }

    private func refreshLibrary() async {
        guard let documentStore else { return }
        do {
            documents = try await documentStore.fetchDocuments()
            if documents.isEmpty {
                importStatus = "Import a PDF or image to build your local document library."
            }
        } catch {
            importStatus = "Failed to load local documents."
        }
    }

    private func refreshExpiringDocuments() async {
        guard let documentStore else { return }
        do {
            expiringDocuments = try await queryEngine.upcomingExpirations(withinDays: 90, using: documentStore)
        } catch {
            expiringDocuments = []
        }
    }
}
