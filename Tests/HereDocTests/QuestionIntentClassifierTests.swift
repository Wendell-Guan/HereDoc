import Foundation
import HereDocAI
import HereDocMCP
import HereDocModels
import HereDocSearch
import HereDocStorage
import Testing

struct QuestionIntentClassifierTests {
    @Test
    func passportLookupUsesFieldRoute() {
        let classifier = QuestionIntentClassifier()
        let plan = classifier.plan(for: "我的护照号是多少？")

        #expect(plan.primaryRoute == .fieldsOnly)
        #expect(plan.fieldHint == .passportNumber)
        #expect(plan.requiresAI == false)
    }

    @Test
    func summarizationRequiresAI() {
        let classifier = QuestionIntentClassifier()
        let plan = classifier.plan(for: "帮我总结这两份合同的差异")

        #expect(plan.primaryRoute == .fullTextThenAI)
        #expect(plan.requiresAI == true)
    }
}

struct SearchNormalizerTests {
    @Test
    func normalizerCollapsesNoise() {
        let normalizer = SearchNormalizer()
        let result = normalizer.normalizeQuery(" Passport   Expiry:\n23 MAR 2034 ")

        #expect(result.contains("passport"))
        #expect(result.contains("2034"))
    }
}

struct DeterministicFieldExtractorTests {
    @Test
    func extractorFindsPassportAndExpiry() {
        let extractor = DeterministicFieldExtractor()
        let fields = extractor.extractFields(
            from: """
            Passport Number: X12345678
            Date of Expiration: 23 MAR 2034
            """,
            documentID: UUID(),
            pageNumber: 1
        )

        #expect(fields.contains(where: { $0.fieldName == .passportNumber && $0.fieldValue == "X12345678" }))
        #expect(fields.contains(where: { $0.fieldName == .expiryDate }))
    }
}

struct AIProviderRegistryTests {
    @Test
    func providerRegistryResolvesPreferredProvider() async {
        let registry = AIProviderRegistry()
        let profile = AIProviderProfile(
            name: "OpenAI",
            kind: .openAI,
            baseURL: URL(string: "https://api.openai.com/v1")!,
            model: "gpt-5-mini",
            credentialSource: .keychain(account: "openai"),
            supportsStructuredOutput: true,
            supportsVision: true
        )
        let provider = StubAIProvider(profile: profile)
        await registry.register(provider)

        let resolved = await registry.provider(for: .answer, preferredID: profile.id)
        #expect(resolved?.profile.id == profile.id)
    }
}

struct LocalDocumentStoreTests {
    @Test
    func storePersistsFieldsAndSearchHits() async throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .notDirectory)
            .appendingPathExtension("sqlite")
        let store = try LocalDocumentStore(databaseURL: tempURL)
        let normalizer = SearchNormalizer()

        let documentID = UUID()
        let pageID = UUID()
        let text = "Early termination fee is $5000."

        let payload = ImportedDocumentPayload(
            document: Document(
                id: documentID,
                title: "Lease Contract",
                type: .contract,
                createdAt: Date(),
                updatedAt: Date(),
                pageCount: 1,
                checksum: nil,
                cloudKitRecordName: nil,
                fileLocalPath: "/tmp/lease.pdf"
            ),
            pages: [
                DocumentPage(
                    id: pageID,
                    documentID: documentID,
                    pageNumber: 1,
                    imageLocalPath: nil,
                    text: text,
                    width: nil,
                    height: nil,
                    cloudKitRecordName: nil
                )
            ],
            blocks: [
                DocumentBlock(
                    documentID: documentID,
                    pageID: pageID,
                    pageNumber: 1,
                    blockType: .paragraph,
                    text: text,
                    normalizedText: normalizer.normalizeForIndexing(text),
                    confidence: nil,
                    boundingBox: nil
                )
            ],
            fields: [
                ExtractedField(
                    documentID: documentID,
                    pageNumber: 1,
                    fieldName: .penaltyAmount,
                    fieldValue: "$5000",
                    normalizedValue: "$5000",
                    confidence: 0.95,
                    boundingBox: nil
                )
            ]
        )

        try await store.saveImportedDocument(payload)

        let documents = try await store.fetchDocuments()
        let hits = try await store.search(
            query: "termination fee",
            normalizedQuery: normalizer.normalizeQuery("termination fee"),
            limit: 5
        )
        let fields = try await store.findFields(named: .penaltyAmount)

        #expect(documents.count == 1)
        #expect(hits.isEmpty == false)
        #expect(fields.first?.fieldValue == "$5000")

        try? FileManager.default.removeItem(at: tempURL)
    }
}

struct DocumentQueryEngineTests {
    @Test
    func queryEngineUsesStructuredFieldBeforeFullText() async throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .notDirectory)
            .appendingPathExtension("sqlite")
        let store = try LocalDocumentStore(databaseURL: tempURL)
        let documentID = UUID()
        let pageID = UUID()

        let payload = ImportedDocumentPayload(
            document: Document(
                id: documentID,
                title: "Passport Copy",
                type: .passport,
                pageCount: 1,
                fileLocalPath: "/tmp/passport.pdf"
            ),
            pages: [
                DocumentPage(
                    id: pageID,
                    documentID: documentID,
                    pageNumber: 1,
                    text: "Passport Number: X12345678"
                )
            ],
            blocks: [],
            fields: [
                ExtractedField(
                    documentID: documentID,
                    pageNumber: 1,
                    fieldName: .passportNumber,
                    fieldValue: "X12345678",
                    normalizedValue: "x12345678",
                    confidence: 0.98
                )
            ]
        )

        try await store.saveImportedDocument(payload)

        let engine = DocumentQueryEngine()
        let result = try await engine.answer(question: "我的护照号是多少？", using: store)

        #expect(result.status == "Resolved with structured fields.")
        #expect(result.answer?.answer.contains("X12345678") == true)
        #expect(result.hits.isEmpty)

        try? FileManager.default.removeItem(at: tempURL)
    }

    @Test
    func upcomingExpirationsReturnsOnlyDeadlinesInRange() async throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .notDirectory)
            .appendingPathExtension("sqlite")
        let store = try LocalDocumentStore(databaseURL: tempURL)
        let referenceDate = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 4, day: 8))!

        let nearDoc = UUID()
        let farDoc = UUID()
        let nearPage = UUID()
        let farPage = UUID()

        try await store.saveImportedDocument(
            ImportedDocumentPayload(
                document: Document(
                    id: nearDoc,
                    title: "US Passport",
                    type: .passport,
                    pageCount: 1,
                    fileLocalPath: "/tmp/passport.pdf"
                ),
                pages: [
                    DocumentPage(id: nearPage, documentID: nearDoc, pageNumber: 1, text: "Date of Expiration: 2026-04-20")
                ],
                blocks: [],
                fields: [
                    ExtractedField(
                        documentID: nearDoc,
                        pageNumber: 1,
                        fieldName: .expiryDate,
                        fieldValue: "2026-04-20",
                        normalizedValue: "2026-04-20",
                        confidence: 0.95
                    )
                ]
            )
        )

        try await store.saveImportedDocument(
            ImportedDocumentPayload(
                document: Document(
                    id: farDoc,
                    title: "Old Contract",
                    type: .contract,
                    pageCount: 1,
                    fileLocalPath: "/tmp/contract.pdf"
                ),
                pages: [
                    DocumentPage(id: farPage, documentID: farDoc, pageNumber: 1, text: "Expiration date: 2026-10-20")
                ],
                blocks: [],
                fields: [
                    ExtractedField(
                        documentID: farDoc,
                        pageNumber: 1,
                        fieldName: .expiryDate,
                        fieldValue: "2026-10-20",
                        normalizedValue: "2026-10-20",
                        confidence: 0.85
                    )
                ]
            )
        )

        let engine = DocumentQueryEngine()
        let expiring = try await engine.upcomingExpirations(withinDays: 30, using: store, referenceDate: referenceDate)

        #expect(expiring.count == 1)
        #expect(expiring.first?.documentTitle == "US Passport")
        #expect(expiring.first?.daysRemaining == 12)

        try? FileManager.default.removeItem(at: tempURL)
    }
}
