import Foundation
import GRDB
import HereDocModels

public actor LocalDocumentStore {
    private let dbQueue: DatabaseQueue

    public init(databaseURL: URL) throws {
        self.dbQueue = try HereDocDatabase.makeQueue(at: databaseURL)
    }

    public func saveImportedDocument(_ payload: ImportedDocumentPayload) throws {
        try dbQueue.write { db in
            try DocumentRecord(document: payload.document).insert(db)

            for page in payload.pages {
                try PageRecord(page: page).insert(db)
            }

            for block in payload.blocks {
                try BlockRecord(block: block).insert(db)
            }

            for field in payload.fields {
                try ExtractedFieldRecord(field: field).insert(db)
            }
        }
    }

    public func fetchDocuments() throws -> [DocumentLibraryItem] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT id, title, document_type, created_at, updated_at, page_count, file_local_path
                    FROM documents
                    ORDER BY updated_at DESC, created_at DESC
                    """
            )

            return rows.compactMap { row in
                guard
                    let id: UUID = row["id"],
                    let typeRaw: String = row["document_type"]
                else {
                    return nil
                }

                return DocumentLibraryItem(
                    id: id,
                    title: row["title"] ?? "Untitled",
                    type: DocumentType(rawValue: typeRaw) ?? .unknown,
                    createdAt: row["created_at"] ?? .distantPast,
                    updatedAt: row["updated_at"] ?? .distantPast,
                    pageCount: row["page_count"] ?? 0,
                    fileLocalPath: row["file_local_path"] ?? ""
                )
            }
        }
    }

    public func fetchDocument(id: UUID) throws -> DocumentLibraryItem? {
        try dbQueue.read { db in
            let row = try Row.fetchOne(
                db,
                sql: """
                    SELECT id, title, document_type, created_at, updated_at, page_count, file_local_path
                    FROM documents
                    WHERE id = ?
                    LIMIT 1
                    """,
                arguments: [id.uuidString]
            )

            guard let row else { return nil }

            guard
                let documentID: UUID = row["id"],
                let typeRaw: String = row["document_type"]
            else {
                return nil
            }

            return DocumentLibraryItem(
                id: documentID,
                title: row["title"] ?? "Untitled",
                type: DocumentType(rawValue: typeRaw) ?? .unknown,
                createdAt: row["created_at"] ?? .distantPast,
                updatedAt: row["updated_at"] ?? .distantPast,
                pageCount: row["page_count"] ?? 0,
                fileLocalPath: row["file_local_path"] ?? ""
            )
        }
    }

    public func fetchPages(for documentID: UUID) throws -> [DocumentPage] {
        try dbQueue.read { db in
            try PageRecord
                .filter(sql: "document_id = ?", arguments: [documentID.uuidString])
                .order(Column("page_number"))
                .fetchAll(db)
                .map(\.documentPage)
        }
    }

    public func fetchFields(for documentID: UUID) throws -> [ExtractedField] {
        try dbQueue.read { db in
            try ExtractedFieldRecord
                .filter(sql: "document_id = ?", arguments: [documentID.uuidString])
                .order(Column("page_number"))
                .fetchAll(db)
                .map(\.extractedField)
        }
    }

    public func findFields(named fieldHint: FieldHint, limit: Int = 5) throws -> [FieldMatch] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT f.id, f.document_id, d.title AS document_title, f.page_number,
                           f.field_name, f.field_value, f.normalized_value, f.confidence,
                           f.bbox_x, f.bbox_y, f.bbox_width, f.bbox_height
                    FROM extracted_fields f
                    JOIN documents d ON d.id = f.document_id
                    WHERE f.field_name = ?
                    ORDER BY COALESCE(f.confidence, 0) DESC, d.updated_at DESC
                    LIMIT ?
                    """,
                arguments: [fieldHint.rawValue, limit]
            )

            return rows.compactMap(Self.makeFieldMatch(from:))
        }
    }

    public func search(query: String, normalizedQuery: String, limit: Int = 12) throws -> [SearchHit] {
        try dbQueue.read { db in
            let matchQuery = makeMatchQuery(from: normalizedQuery)
            guard !matchQuery.isEmpty else { return [] }

            do {
                let rows = try Row.fetchAll(
                    db,
                    sql: """
                        SELECT b.id AS block_id, d.id AS document_id, d.title, b.page_number,
                               snippet(block_search, 0, "[", "]", " … ", 16) AS snippet,
                               bm25(block_search) AS rank,
                               b.bbox_x, b.bbox_y, b.bbox_width, b.bbox_height
                        FROM block_search
                        JOIN blocks b ON b.rowid = block_search.rowid
                        JOIN documents d ON d.id = b.document_id
                        WHERE block_search MATCH ?
                        ORDER BY rank
                        LIMIT ?
                        """,
                    arguments: [matchQuery, limit]
                )

                return rows.compactMap(Self.makeSearchHit(from:))
            } catch {
                let fallbackRows = try Row.fetchAll(
                    db,
                    sql: """
                        SELECT b.id AS block_id, d.id AS document_id, d.title, b.page_number,
                               b.text AS snippet,
                               0.0 AS rank,
                               b.bbox_x, b.bbox_y, b.bbox_width, b.bbox_height
                        FROM blocks b
                        JOIN documents d ON d.id = b.document_id
                        WHERE b.normalized_text LIKE ? OR b.text LIKE ?
                        ORDER BY d.updated_at DESC
                        LIMIT ?
                        """,
                    arguments: ["%\(normalizedQuery)%", "%\(query)%", limit]
                )
                return fallbackRows.compactMap(Self.makeSearchHit(from:))
            }
        }
    }

    private func makeMatchQuery(from normalizedQuery: String) -> String {
        normalizedQuery
            .split(separator: " ")
            .prefix(8)
            .map { token in
                token
                    .replacingOccurrences(of: "\"", with: "")
                    .replacingOccurrences(of: "'", with: "")
                    .replacingOccurrences(of: ":", with: "")
            }
            .filter { !$0.isEmpty }
            .map { "\($0)*" }
            .joined(separator: " AND ")
    }

    private static func makeSearchHit(from row: Row) -> SearchHit? {
        guard
            let id: UUID = row["block_id"],
            let documentID: UUID = row["document_id"]
        else {
            return nil
        }

        let boundingBox = makeBoundingBox(from: row)
        let rank: Double = row["rank"] ?? 0

        return SearchHit(
            id: id,
            documentID: documentID,
            pageNumber: row["page_number"] ?? 1,
            title: row["title"],
            snippet: row["snippet"] ?? "",
            score: rank == 0 ? 0 : -rank,
            boundingBox: boundingBox
        )
    }

    private static func makeFieldMatch(from row: Row) -> FieldMatch? {
        guard
            let id: UUID = row["id"],
            let documentID: UUID = row["document_id"],
            let fieldNameRaw: String = row["field_name"]
        else {
            return nil
        }

        return FieldMatch(
            id: id,
            documentID: documentID,
            documentTitle: row["document_title"] ?? "Untitled",
            pageNumber: row["page_number"] ?? 1,
            fieldName: FieldHint(rawValue: fieldNameRaw),
            fieldValue: row["field_value"] ?? "",
            normalizedValue: row["normalized_value"] ?? "",
            confidence: row["confidence"],
            boundingBox: makeBoundingBox(from: row)
        )
    }

    private static func makeBoundingBox(from row: Row) -> BoundingBox? {
        guard
            let x: Double = row["bbox_x"],
            let y: Double = row["bbox_y"],
            let width: Double = row["bbox_width"],
            let height: Double = row["bbox_height"]
        else {
            return nil
        }

        return BoundingBox(x: x, y: y, width: width, height: height)
    }
}
