import Foundation
import GRDB
import HereDocModels

public struct DocumentRecord: Codable, FetchableRecord, PersistableRecord, TableRecord, Identifiable, Sendable {
    public static let databaseTableName = "documents"

    public var id: UUID
    public var title: String
    public var documentType: String
    public var createdAt: Date
    public var updatedAt: Date
    public var pageCount: Int
    public var checksum: String?
    public var cloudKitRecordName: String?
    public var fileLocalPath: String

    public init(document: Document) {
        self.id = document.id
        self.title = document.title
        self.documentType = document.type.rawValue
        self.createdAt = document.createdAt
        self.updatedAt = document.updatedAt
        self.pageCount = document.pageCount
        self.checksum = document.checksum
        self.cloudKitRecordName = document.cloudKitRecordName
        self.fileLocalPath = document.fileLocalPath
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case documentType = "document_type"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case pageCount = "page_count"
        case checksum
        case cloudKitRecordName = "cloud_kit_record_name"
        case fileLocalPath = "file_local_path"
    }

    public var document: Document {
        Document(
            id: id,
            title: title,
            type: DocumentType(rawValue: documentType) ?? .unknown,
            createdAt: createdAt,
            updatedAt: updatedAt,
            pageCount: pageCount,
            checksum: checksum,
            cloudKitRecordName: cloudKitRecordName,
            fileLocalPath: fileLocalPath
        )
    }
}

public struct PageRecord: Codable, FetchableRecord, PersistableRecord, TableRecord, Identifiable, Sendable {
    public static let databaseTableName = "pages"

    public var id: UUID
    public var documentID: UUID
    public var pageNumber: Int
    public var imageLocalPath: String?
    public var text: String
    public var width: Double?
    public var height: Double?
    public var cloudKitRecordName: String?

    public init(page: DocumentPage) {
        self.id = page.id
        self.documentID = page.documentID
        self.pageNumber = page.pageNumber
        self.imageLocalPath = page.imageLocalPath
        self.text = page.text
        self.width = page.width
        self.height = page.height
        self.cloudKitRecordName = page.cloudKitRecordName
    }

    enum CodingKeys: String, CodingKey {
        case id
        case documentID = "document_id"
        case pageNumber = "page_number"
        case imageLocalPath = "image_local_path"
        case text
        case width
        case height
        case cloudKitRecordName = "cloud_kit_record_name"
    }

    public var documentPage: DocumentPage {
        DocumentPage(
            id: id,
            documentID: documentID,
            pageNumber: pageNumber,
            imageLocalPath: imageLocalPath,
            text: text,
            width: width,
            height: height,
            cloudKitRecordName: cloudKitRecordName
        )
    }
}

public struct BlockRecord: Codable, FetchableRecord, PersistableRecord, TableRecord, Identifiable, Sendable {
    public static let databaseTableName = "blocks"

    public var id: UUID
    public var documentID: UUID
    public var pageID: UUID
    public var pageNumber: Int
    public var blockType: String
    public var text: String
    public var normalizedText: String
    public var confidence: Double?
    public var bboxX: Double?
    public var bboxY: Double?
    public var bboxWidth: Double?
    public var bboxHeight: Double?

    public init(block: DocumentBlock) {
        self.id = block.id
        self.documentID = block.documentID
        self.pageID = block.pageID
        self.pageNumber = block.pageNumber
        self.blockType = block.blockType.rawValue
        self.text = block.text
        self.normalizedText = block.normalizedText
        self.confidence = block.confidence
        self.bboxX = block.boundingBox?.x
        self.bboxY = block.boundingBox?.y
        self.bboxWidth = block.boundingBox?.width
        self.bboxHeight = block.boundingBox?.height
    }

    enum CodingKeys: String, CodingKey {
        case id
        case documentID = "document_id"
        case pageID = "page_id"
        case pageNumber = "page_number"
        case blockType = "block_type"
        case text
        case normalizedText = "normalized_text"
        case confidence
        case bboxX = "bbox_x"
        case bboxY = "bbox_y"
        case bboxWidth = "bbox_width"
        case bboxHeight = "bbox_height"
    }

    public var documentBlock: DocumentBlock {
        DocumentBlock(
            id: id,
            documentID: documentID,
            pageID: pageID,
            pageNumber: pageNumber,
            blockType: BlockType(rawValue: blockType) ?? .unknown,
            text: text,
            normalizedText: normalizedText,
            confidence: confidence,
            boundingBox: boundingBox
        )
    }

    private var boundingBox: BoundingBox? {
        guard
            let bboxX,
            let bboxY,
            let bboxWidth,
            let bboxHeight
        else {
            return nil
        }

        return BoundingBox(x: bboxX, y: bboxY, width: bboxWidth, height: bboxHeight)
    }
}

public struct ExtractedFieldRecord: Codable, FetchableRecord, PersistableRecord, TableRecord, Identifiable, Sendable {
    public static let databaseTableName = "extracted_fields"

    public var id: UUID
    public var documentID: UUID
    public var pageNumber: Int
    public var fieldName: String
    public var fieldValue: String
    public var normalizedValue: String
    public var confidence: Double?
    public var bboxX: Double?
    public var bboxY: Double?
    public var bboxWidth: Double?
    public var bboxHeight: Double?

    public init(field: ExtractedField) {
        self.id = field.id
        self.documentID = field.documentID
        self.pageNumber = field.pageNumber
        self.fieldName = field.fieldName.rawValue
        self.fieldValue = field.fieldValue
        self.normalizedValue = field.normalizedValue
        self.confidence = field.confidence
        self.bboxX = field.boundingBox?.x
        self.bboxY = field.boundingBox?.y
        self.bboxWidth = field.boundingBox?.width
        self.bboxHeight = field.boundingBox?.height
    }

    enum CodingKeys: String, CodingKey {
        case id
        case documentID = "document_id"
        case pageNumber = "page_number"
        case fieldName = "field_name"
        case fieldValue = "field_value"
        case normalizedValue = "normalized_value"
        case confidence
        case bboxX = "bbox_x"
        case bboxY = "bbox_y"
        case bboxWidth = "bbox_width"
        case bboxHeight = "bbox_height"
    }

    public var extractedField: ExtractedField {
        ExtractedField(
            id: id,
            documentID: documentID,
            pageNumber: pageNumber,
            fieldName: FieldHint(rawValue: fieldName),
            fieldValue: fieldValue,
            normalizedValue: normalizedValue,
            confidence: confidence,
            boundingBox: boundingBox
        )
    }

    private var boundingBox: BoundingBox? {
        guard
            let bboxX,
            let bboxY,
            let bboxWidth,
            let bboxHeight
        else {
            return nil
        }

        return BoundingBox(x: bboxX, y: bboxY, width: bboxWidth, height: bboxHeight)
    }
}
