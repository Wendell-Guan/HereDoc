import Foundation

public struct ImportedDocumentPayload: Sendable {
    public var document: Document
    public var pages: [DocumentPage]
    public var blocks: [DocumentBlock]
    public var fields: [ExtractedField]

    public init(
        document: Document,
        pages: [DocumentPage],
        blocks: [DocumentBlock],
        fields: [ExtractedField]
    ) {
        self.document = document
        self.pages = pages
        self.blocks = blocks
        self.fields = fields
    }
}

public struct DocumentLibraryItem: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var type: DocumentType
    public var createdAt: Date
    public var updatedAt: Date
    public var pageCount: Int
    public var fileLocalPath: String

    public init(
        id: UUID,
        title: String,
        type: DocumentType,
        createdAt: Date,
        updatedAt: Date,
        pageCount: Int,
        fileLocalPath: String
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.pageCount = pageCount
        self.fileLocalPath = fileLocalPath
    }
}

public struct FieldMatch: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var documentID: UUID
    public var documentTitle: String
    public var pageNumber: Int
    public var fieldName: FieldHint
    public var fieldValue: String
    public var normalizedValue: String
    public var confidence: Double?
    public var boundingBox: BoundingBox?

    public init(
        id: UUID = UUID(),
        documentID: UUID,
        documentTitle: String,
        pageNumber: Int,
        fieldName: FieldHint,
        fieldValue: String,
        normalizedValue: String,
        confidence: Double? = nil,
        boundingBox: BoundingBox? = nil
    ) {
        self.id = id
        self.documentID = documentID
        self.documentTitle = documentTitle
        self.pageNumber = pageNumber
        self.fieldName = fieldName
        self.fieldValue = fieldValue
        self.normalizedValue = normalizedValue
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}
