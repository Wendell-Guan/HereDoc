import Foundation

public enum DocumentType: String, Codable, Sendable, CaseIterable {
    case passport
    case contract
    case invoice
    case certificate
    case receipt
    case genericPDF
    case genericImage
    case unknown
}

public struct BoundingBox: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct Document: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var type: DocumentType
    public var createdAt: Date
    public var updatedAt: Date
    public var pageCount: Int
    public var checksum: String?
    public var cloudKitRecordName: String?
    public var fileLocalPath: String

    public init(
        id: UUID = UUID(),
        title: String,
        type: DocumentType,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        pageCount: Int = 0,
        checksum: String? = nil,
        cloudKitRecordName: String? = nil,
        fileLocalPath: String
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.pageCount = pageCount
        self.checksum = checksum
        self.cloudKitRecordName = cloudKitRecordName
        self.fileLocalPath = fileLocalPath
    }
}

public struct DocumentPage: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var documentID: UUID
    public var pageNumber: Int
    public var imageLocalPath: String?
    public var text: String
    public var width: Double?
    public var height: Double?
    public var cloudKitRecordName: String?

    public init(
        id: UUID = UUID(),
        documentID: UUID,
        pageNumber: Int,
        imageLocalPath: String? = nil,
        text: String = "",
        width: Double? = nil,
        height: Double? = nil,
        cloudKitRecordName: String? = nil
    ) {
        self.id = id
        self.documentID = documentID
        self.pageNumber = pageNumber
        self.imageLocalPath = imageLocalPath
        self.text = text
        self.width = width
        self.height = height
        self.cloudKitRecordName = cloudKitRecordName
    }
}

public enum BlockType: String, Codable, Sendable, CaseIterable {
    case line
    case paragraph
    case table
    case title
    case keyValue
    case unknown
}

public struct DocumentBlock: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var documentID: UUID
    public var pageID: UUID
    public var pageNumber: Int
    public var blockType: BlockType
    public var text: String
    public var normalizedText: String
    public var confidence: Double?
    public var boundingBox: BoundingBox?

    public init(
        id: UUID = UUID(),
        documentID: UUID,
        pageID: UUID,
        pageNumber: Int,
        blockType: BlockType,
        text: String,
        normalizedText: String,
        confidence: Double? = nil,
        boundingBox: BoundingBox? = nil
    ) {
        self.id = id
        self.documentID = documentID
        self.pageID = pageID
        self.pageNumber = pageNumber
        self.blockType = blockType
        self.text = text
        self.normalizedText = normalizedText
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}

public struct FieldHint: RawRepresentable, Codable, Hashable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    public static let passportNumber: Self = "passport_number"
    public static let expiryDate: Self = "expiry_date"
    public static let issueDate: Self = "issue_date"
    public static let birthDate: Self = "birth_date"
    public static let amount: Self = "amount"
    public static let penaltyAmount: Self = "penalty_amount"
    public static let counterparty: Self = "counterparty"
    public static let genericDate: Self = "date"
}

public struct ExtractedField: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var documentID: UUID
    public var pageNumber: Int
    public var fieldName: FieldHint
    public var fieldValue: String
    public var normalizedValue: String
    public var confidence: Double?
    public var boundingBox: BoundingBox?

    public init(
        id: UUID = UUID(),
        documentID: UUID,
        pageNumber: Int,
        fieldName: FieldHint,
        fieldValue: String,
        normalizedValue: String,
        confidence: Double? = nil,
        boundingBox: BoundingBox? = nil
    ) {
        self.id = id
        self.documentID = documentID
        self.pageNumber = pageNumber
        self.fieldName = fieldName
        self.fieldValue = fieldValue
        self.normalizedValue = normalizedValue
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}
