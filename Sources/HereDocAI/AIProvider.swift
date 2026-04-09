import Foundation
import HereDocModels

public enum AIProviderKind: String, Codable, Sendable, CaseIterable {
    case openAI
    case anthropic
    case gemini
    case ollama
    case openAICompatible
}

public enum CredentialSource: Codable, Hashable, Sendable {
    case keychain(account: String)
    case environment(variable: String)
    case none
}

public struct AIProviderProfile: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var kind: AIProviderKind
    public var baseURL: URL
    public var model: String
    public var credentialSource: CredentialSource
    public var supportsStructuredOutput: Bool
    public var supportsVision: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        kind: AIProviderKind,
        baseURL: URL,
        model: String,
        credentialSource: CredentialSource,
        supportsStructuredOutput: Bool,
        supportsVision: Bool
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.baseURL = baseURL
        self.model = model
        self.credentialSource = credentialSource
        self.supportsStructuredOutput = supportsStructuredOutput
        self.supportsVision = supportsVision
    }
}

public enum AIWorkload: String, Codable, Sendable {
    case answer
    case summary
    case extractionFallback
}

public struct AIAnswerRequest: Codable, Hashable, Sendable {
    public var question: String
    public var evidence: [Evidence]
    public var workload: AIWorkload

    public init(question: String, evidence: [Evidence], workload: AIWorkload) {
        self.question = question
        self.evidence = evidence
        self.workload = workload
    }
}

public protocol AIProvider: Sendable {
    var profile: AIProviderProfile { get }
    func canHandle(_ workload: AIWorkload) -> Bool
    func generateAnswer(for request: AIAnswerRequest) async throws -> GroundedAnswer
}

public struct StubAIProvider: AIProvider {
    public let profile: AIProviderProfile

    public init(profile: AIProviderProfile) {
        self.profile = profile
    }

    public func canHandle(_ workload: AIWorkload) -> Bool {
        switch workload {
        case .answer, .summary, .extractionFallback:
            true
        }
    }

    public func generateAnswer(for request: AIAnswerRequest) async throws -> GroundedAnswer {
        let summary = request.evidence
            .prefix(3)
            .map(\.snippet)
            .joined(separator: "\n")

        return GroundedAnswer(
            answer: "Stub answer for '\(request.question)'.\n\nEvidence:\n\(summary)",
            sources: request.evidence.map {
                SourceAnchor(
                    documentID: $0.documentID,
                    pageNumber: $0.pageNumber,
                    snippet: $0.snippet,
                    boundingBox: $0.boundingBox
                )
            }
        )
    }
}
