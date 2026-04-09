import Foundation

public enum QuestionIntent: Codable, Hashable, Sendable {
    case exactField(FieldHint?)
    case clauseLookup
    case summarization
    case comparison
    case unknown
}

public enum SearchRoute: String, Codable, Hashable, Sendable {
    case fieldsOnly
    case fieldsThenFullText
    case fullTextOnly
    case fullTextThenAI
}

public struct QueryPlan: Codable, Hashable, Sendable {
    public var intent: QuestionIntent
    public var primaryRoute: SearchRoute
    public var fallbackRoutes: [SearchRoute]
    public var requiresAI: Bool
    public var fieldHint: FieldHint?

    public init(
        intent: QuestionIntent,
        primaryRoute: SearchRoute,
        fallbackRoutes: [SearchRoute] = [],
        requiresAI: Bool,
        fieldHint: FieldHint? = nil
    ) {
        self.intent = intent
        self.primaryRoute = primaryRoute
        self.fallbackRoutes = fallbackRoutes
        self.requiresAI = requiresAI
        self.fieldHint = fieldHint
    }
}

public struct SourceAnchor: Codable, Hashable, Sendable {
    public var documentID: UUID
    public var pageNumber: Int
    public var snippet: String
    public var boundingBox: BoundingBox?

    public init(documentID: UUID, pageNumber: Int, snippet: String, boundingBox: BoundingBox?) {
        self.documentID = documentID
        self.pageNumber = pageNumber
        self.snippet = snippet
        self.boundingBox = boundingBox
    }
}

public struct Evidence: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var documentID: UUID
    public var pageNumber: Int
    public var snippet: String
    public var score: Double
    public var boundingBox: BoundingBox?

    public init(
        id: UUID = UUID(),
        documentID: UUID,
        pageNumber: Int,
        snippet: String,
        score: Double,
        boundingBox: BoundingBox? = nil
    ) {
        self.id = id
        self.documentID = documentID
        self.pageNumber = pageNumber
        self.snippet = snippet
        self.score = score
        self.boundingBox = boundingBox
    }
}

public struct SearchHit: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var documentID: UUID
    public var pageNumber: Int
    public var title: String?
    public var snippet: String
    public var score: Double
    public var boundingBox: BoundingBox?

    public init(
        id: UUID = UUID(),
        documentID: UUID,
        pageNumber: Int,
        title: String? = nil,
        snippet: String,
        score: Double,
        boundingBox: BoundingBox? = nil
    ) {
        self.id = id
        self.documentID = documentID
        self.pageNumber = pageNumber
        self.title = title
        self.snippet = snippet
        self.score = score
        self.boundingBox = boundingBox
    }
}

public struct GroundedAnswer: Codable, Hashable, Sendable {
    public var answer: String
    public var sources: [SourceAnchor]

    public init(answer: String, sources: [SourceAnchor]) {
        self.answer = answer
        self.sources = sources
    }
}

public struct QueryExecutionResult: Codable, Hashable, Sendable {
    public var plan: QueryPlan
    public var answer: GroundedAnswer?
    public var hits: [SearchHit]
    public var status: String

    public init(
        plan: QueryPlan,
        answer: GroundedAnswer?,
        hits: [SearchHit],
        status: String
    ) {
        self.plan = plan
        self.answer = answer
        self.hits = hits
        self.status = status
    }
}

public struct ExpiringDocumentHit: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var documentID: UUID
    public var documentTitle: String
    public var pageNumber: Int
    public var expiryDate: Date
    public var displayValue: String
    public var daysRemaining: Int
    public var boundingBox: BoundingBox?

    public init(
        id: UUID = UUID(),
        documentID: UUID,
        documentTitle: String,
        pageNumber: Int,
        expiryDate: Date,
        displayValue: String,
        daysRemaining: Int,
        boundingBox: BoundingBox? = nil
    ) {
        self.id = id
        self.documentID = documentID
        self.documentTitle = documentTitle
        self.pageNumber = pageNumber
        self.expiryDate = expiryDate
        self.displayValue = displayValue
        self.daysRemaining = daysRemaining
        self.boundingBox = boundingBox
    }
}
