import Foundation
import HereDocModels

public struct QuestionIntentClassifier: Sendable {
    public init() {}

    public func plan(for question: String) -> QueryPlan {
        let q = question.lowercased()

        if matchesAny(q, ["护照号", "passport number", "passport no", "证件号", "号码"]) {
            return QueryPlan(
                intent: .exactField(.passportNumber),
                primaryRoute: .fieldsOnly,
                fallbackRoutes: [.fieldsThenFullText],
                requiresAI: false,
                fieldHint: .passportNumber
            )
        }

        if matchesAny(q, ["到期", "过期", "expires", "expiry", "expiration", "有效期"]) {
            return QueryPlan(
                intent: .exactField(.expiryDate),
                primaryRoute: .fieldsOnly,
                fallbackRoutes: [.fieldsThenFullText],
                requiresAI: false,
                fieldHint: .expiryDate
            )
        }

        if matchesAny(q, ["生日", "出生", "birth", "date of birth"]) {
            return QueryPlan(
                intent: .exactField(.birthDate),
                primaryRoute: .fieldsOnly,
                fallbackRoutes: [.fieldsThenFullText],
                requiresAI: false,
                fieldHint: .birthDate
            )
        }

        if matchesAny(q, ["违约金", "penalty", "deductible", "金额", "amount", "押金"]) {
            return QueryPlan(
                intent: .exactField(.penaltyAmount),
                primaryRoute: .fieldsThenFullText,
                fallbackRoutes: [.fullTextThenAI],
                requiresAI: false,
                fieldHint: .penaltyAmount
            )
        }

        if matchesAny(q, ["总结", "概括", "summary", "summarize"]) {
            return QueryPlan(
                intent: .summarization,
                primaryRoute: .fullTextThenAI,
                requiresAI: true
            )
        }

        if matchesAny(q, ["比较", "区别", "差异", "compare", "difference"]) {
            return QueryPlan(
                intent: .comparison,
                primaryRoute: .fullTextThenAI,
                requiresAI: true
            )
        }

        if matchesAny(q, ["条款", "哪里提到", "mention", "section", "clause", "在哪一页"]) {
            return QueryPlan(
                intent: .clauseLookup,
                primaryRoute: .fullTextOnly,
                fallbackRoutes: [.fullTextThenAI],
                requiresAI: false
            )
        }

        return QueryPlan(
            intent: .unknown,
            primaryRoute: .fieldsThenFullText,
            fallbackRoutes: [.fullTextThenAI],
            requiresAI: false
        )
    }

    private func matchesAny(_ query: String, _ phrases: [String]) -> Bool {
        phrases.contains { query.contains($0) }
    }
}
