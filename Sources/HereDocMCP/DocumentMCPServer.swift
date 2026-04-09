import Foundation
import HereDocModels
import MCP

public protocol DocumentToolService: Sendable {
    func searchDocuments(query: String, limit: Int) async throws -> [SearchHit]
    func getExtractedFields(documentID: UUID?) async throws -> [ExtractedField]
    func readSourcePage(documentID: UUID, pageNumber: Int) async throws -> SourceAnchor?
    func answerDocuments(question: String, limit: Int) async throws -> GroundedAnswer
}

public enum DocumentMCPTools {
    public static func makeServer(using service: any DocumentToolService) async -> Server {
        let server = Server(
            name: "HereDoc",
            version: "0.1.0",
            capabilities: .init(
                tools: .init(listChanged: false)
            )
        )

        await server.withMethodHandler(ListTools.self) { _ in
            .init(tools: [
                Tool(
                    name: "search_documents",
                    description: "Search documents locally and return grounded hits",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "query": .object([
                                "type": .string("string"),
                                "description": .string("Search query")
                            ]),
                            "limit": .object([
                                "type": .string("number"),
                                "description": .string("Maximum number of hits to return")
                            ]),
                        ]),
                        "required": .array([.string("query")]),
                    ]),
                    annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false)
                ),
                Tool(
                    name: "get_extracted_fields",
                    description: "Read extracted fields such as dates, ids, and amounts",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "document_id": .object([
                                "type": .string("string"),
                                "description": .string("Optional UUID of one document")
                            ])
                        ])
                    ]),
                    annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false)
                ),
                Tool(
                    name: "read_source_page",
                    description: "Resolve one source page and snippet for a document answer",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "document_id": .object([
                                "type": .string("string")
                            ]),
                            "page_number": .object([
                                "type": .string("number")
                            ]),
                        ]),
                        "required": .array([.string("document_id"), .string("page_number")]),
                    ]),
                    annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false)
                ),
                Tool(
                    name: "answer_documents",
                    description: "Answer a document question using grounded evidence",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "question": .object([
                                "type": .string("string")
                            ]),
                            "limit": .object([
                                "type": .string("number")
                            ]),
                        ]),
                        "required": .array([.string("question")]),
                    ]),
                    annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false)
                ),
            ])
        }

        await server.withMethodHandler(CallTool.self) { params in
            do {
                switch params.name {
                case "search_documents":
                    let query = params.arguments?["query"]?.stringValue ?? ""
                    let limit = params.arguments?["limit"]?.intValue ?? 8
                    let hits = try await service.searchDocuments(query: query, limit: limit)
                    return .init(content: [.text(text: try encode(hits), annotations: nil, _meta: nil)])

                case "get_extracted_fields":
                    let documentID = params.arguments?["document_id"]?.stringValue.flatMap(UUID.init(uuidString:))
                    let fields = try await service.getExtractedFields(documentID: documentID)
                    return .init(content: [.text(text: try encode(fields), annotations: nil, _meta: nil)])

                case "read_source_page":
                    guard
                        let documentIDString = params.arguments?["document_id"]?.stringValue,
                        let documentID = UUID(uuidString: documentIDString),
                        let pageNumber = params.arguments?["page_number"]?.intValue
                    else {
                        return .init(content: [.text(text: "Missing document_id or page_number", annotations: nil, _meta: nil)], isError: true)
                    }

                    let source = try await service.readSourcePage(documentID: documentID, pageNumber: pageNumber)
                    return .init(content: [.text(text: try encode(source), annotations: nil, _meta: nil)])

                case "answer_documents":
                    let question = params.arguments?["question"]?.stringValue ?? ""
                    let limit = params.arguments?["limit"]?.intValue ?? 8
                    let answer = try await service.answerDocuments(question: question, limit: limit)
                    return .init(content: [.text(text: try encode(answer), annotations: nil, _meta: nil)])

                default:
                    return .init(content: [.text(text: "Unknown tool '\(params.name)'", annotations: nil, _meta: nil)], isError: true)
                }
            } catch {
                return .init(content: [.text(text: "Tool error: \(error.localizedDescription)", annotations: nil, _meta: nil)], isError: true)
            }
        }

        return server
    }

    private static func encode<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }
}
