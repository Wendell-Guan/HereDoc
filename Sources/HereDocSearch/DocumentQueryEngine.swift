import Foundation
import HereDocModels
import HereDocStorage

public struct DocumentQueryEngine: Sendable {
    private let classifier = QuestionIntentClassifier()
    private let normalizer = SearchNormalizer()

    public init() {}

    public func previewPlan(for question: String) -> QueryPlan {
        classifier.plan(for: question)
    }

    public func answer(question: String, using store: LocalDocumentStore) async throws -> QueryExecutionResult {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let emptyPlan = classifier.plan(for: trimmed)

        guard trimmed.isEmpty == false else {
            return QueryExecutionResult(
                plan: emptyPlan,
                answer: nil,
                hits: [],
                status: "Enter a question first."
            )
        }

        let plan = classifier.plan(for: trimmed)

        if let fieldHint = plan.fieldHint {
            let matches = try await store.findFields(named: fieldHint, limit: 5)
            if let first = matches.first {
                return QueryExecutionResult(
                    plan: plan,
                    answer: GroundedAnswer(
                        answer: answerText(for: fieldHint, match: first),
                        sources: [
                            SourceAnchor(
                                documentID: first.documentID,
                                pageNumber: first.pageNumber,
                                snippet: "\(first.documentTitle): \(first.fieldValue)",
                                boundingBox: first.boundingBox
                            )
                        ]
                    ),
                    hits: [],
                    status: "Resolved with structured fields."
                )
            }
        }

        let hits = try await store.search(
            query: trimmed,
            normalizedQuery: normalizer.normalizeQuery(trimmed),
            limit: 8
        )

        guard let first = hits.first else {
            return QueryExecutionResult(
                plan: plan,
                answer: nil,
                hits: [],
                status: "No evidence found yet. Try importing a document or using a more specific query."
            )
        }

        let answerText: String
        if plan.requiresAI {
            answerText = "Collected \(hits.count) grounded passages. Retrieval and source grounding are ready; the final summarizer provider is the next layer to plug in."
        } else {
            let title = first.title ?? "an imported document"
            answerText = "I found supporting evidence in \(title), page \(first.pageNumber): \(plainSnippet(from: first.snippet))."
        }

        return QueryExecutionResult(
            plan: plan,
            answer: GroundedAnswer(
                answer: answerText,
                sources: hits.prefix(3).map {
                    SourceAnchor(
                        documentID: $0.documentID,
                        pageNumber: $0.pageNumber,
                        snippet: $0.snippet,
                        boundingBox: $0.boundingBox
                    )
                }
            ),
            hits: hits,
            status: "Found \(hits.count) matching passage(s)."
        )
    }

    public func upcomingExpirations(
        withinDays days: Int,
        using store: LocalDocumentStore,
        referenceDate: Date = Date(),
        limit: Int = 12
    ) async throws -> [ExpiringDocumentHit] {
        let safeDays = max(days, 1)
        let start = Calendar.current.startOfDay(for: referenceDate)
        guard let deadline = Calendar.current.date(byAdding: .day, value: safeDays, to: start) else {
            return []
        }

        let candidates = try await store.findFields(named: .expiryDate, limit: max(limit * 8, 32))

        return candidates
            .compactMap { match -> ExpiringDocumentHit? in
                guard let expiryDate = parseDate(match.normalizedValue, fallback: match.fieldValue) else {
                    return nil
                }

                let normalizedExpiry = Calendar.current.startOfDay(for: expiryDate)
                guard normalizedExpiry >= start, normalizedExpiry <= deadline else {
                    return nil
                }

                let daysRemaining = Calendar.current.dateComponents([.day], from: start, to: normalizedExpiry).day ?? 0

                return ExpiringDocumentHit(
                    documentID: match.documentID,
                    documentTitle: match.documentTitle,
                    pageNumber: match.pageNumber,
                    expiryDate: normalizedExpiry,
                    displayValue: match.fieldValue,
                    daysRemaining: daysRemaining,
                    boundingBox: match.boundingBox
                )
            }
            .sorted {
                if $0.expiryDate == $1.expiryDate {
                    return $0.documentTitle.localizedCaseInsensitiveCompare($1.documentTitle) == .orderedAscending
                }
                return $0.expiryDate < $1.expiryDate
            }
            .prefix(limit)
            .map { $0 }
    }

    private func answerText(for fieldHint: FieldHint, match: FieldMatch) -> String {
        switch fieldHint {
        case .passportNumber:
            return "The passport number is \(match.fieldValue), from \(match.documentTitle) page \(match.pageNumber)."
        case .expiryDate:
            return "The expiration date is \(match.fieldValue), from \(match.documentTitle) page \(match.pageNumber)."
        case .birthDate:
            return "The birth date is \(match.fieldValue), from \(match.documentTitle) page \(match.pageNumber)."
        case .issueDate:
            return "The issue date is \(match.fieldValue), from \(match.documentTitle) page \(match.pageNumber)."
        case .penaltyAmount:
            return "The penalty-related amount is \(match.fieldValue), from \(match.documentTitle) page \(match.pageNumber)."
        case .amount:
            return "The amount is \(match.fieldValue), from \(match.documentTitle) page \(match.pageNumber)."
        default:
            return "\(match.fieldValue), from \(match.documentTitle) page \(match.pageNumber)."
        }
    }

    private func plainSnippet(from snippet: String) -> String {
        snippet
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseDate(_ normalizedValue: String, fallback rawValue: String) -> Date? {
        let posix = Locale(identifier: "en_US_POSIX")
        let calendar = Calendar(identifier: .gregorian)

        let normalizedFormatter = DateFormatter()
        normalizedFormatter.locale = posix
        normalizedFormatter.calendar = calendar
        normalizedFormatter.dateFormat = "yyyy-MM-dd"
        if let date = normalizedFormatter.date(from: normalizedValue) {
            return date
        }

        let rawFormatter = DateFormatter()
        rawFormatter.locale = posix
        rawFormatter.calendar = calendar
        rawFormatter.dateFormat = "dd MMM yyyy"
        if let date = rawFormatter.date(from: rawValue.uppercased()) {
            return date
        }

        let slashFormatter = DateFormatter()
        slashFormatter.locale = posix
        slashFormatter.calendar = calendar
        slashFormatter.dateFormat = "MM/dd/yyyy"
        return slashFormatter.date(from: rawValue)
    }
}
