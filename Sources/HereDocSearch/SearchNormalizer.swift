import Foundation
import NaturalLanguage

public struct SearchNormalizer: Sendable {
    public init() {}

    public func normalizeForIndexing(_ text: String) -> String {
        normalize(text, keepNumbers: true)
    }

    public func normalizeQuery(_ text: String) -> String {
        normalize(text, keepNumbers: true)
    }

    private func normalize(_ text: String, keepNumbers: Bool) -> String {
        let folded = text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")

        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = folded

        var tokens: [String] = []
        tokenizer.enumerateTokens(in: folded.startIndex..<folded.endIndex) { range, _ in
            let token = folded[range]
                .trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))

            guard !token.isEmpty else { return true }

            if keepNumbers {
                tokens.append(token)
            } else if token.rangeOfCharacter(from: .decimalDigits) == nil {
                tokens.append(token)
            }

            return true
        }

        if tokens.isEmpty {
            return folded
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        }

        return tokens.joined(separator: " ")
    }
}
