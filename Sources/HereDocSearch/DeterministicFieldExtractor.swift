import Foundation
import HereDocModels

public struct DeterministicFieldExtractor: Sendable {
    private let normalizer = SearchNormalizer()
    private let detector: NSDataDetector?
    private let amountRegex: NSRegularExpression
    private let passportRegex: NSRegularExpression

    public init() {
        self.detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        self.amountRegex = try! NSRegularExpression(
            pattern: #"(?:(?:USD|CNY|RMB|EUR|HKD)\s*)?[$¥€£]?\s*\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?"#,
            options: [.caseInsensitive]
        )
        self.passportRegex = try! NSRegularExpression(
            pattern: #"\b[A-Z0-9]{7,12}\b"#,
            options: []
        )
    }

    public func extractFields(from text: String, documentID: UUID, pageNumber: Int) -> [ExtractedField] {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var results: [ExtractedField] = []

        for line in lines {
            results.append(contentsOf: extractPassport(in: line, documentID: documentID, pageNumber: pageNumber))
            results.append(contentsOf: extractDates(in: line, documentID: documentID, pageNumber: pageNumber))
            results.append(contentsOf: extractAmounts(in: line, documentID: documentID, pageNumber: pageNumber))
        }

        return deduplicated(results)
    }

    private func extractPassport(in line: String, documentID: UUID, pageNumber: Int) -> [ExtractedField] {
        guard containsAny(line.lowercased(), phrases: ["passport", "document no", "passport no", "passport number", "护照", "证件号", "号码"]) else {
            return []
        }

        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        let matches = passportRegex.matches(in: line, options: [], range: range)

        return matches.compactMap { match in
            guard let matchRange = Range(match.range, in: line) else { return nil }
            let value = String(line[matchRange])
            guard value.count >= 7 else { return nil }
            return ExtractedField(
                documentID: documentID,
                pageNumber: pageNumber,
                fieldName: .passportNumber,
                fieldValue: value,
                normalizedValue: normalizer.normalizeQuery(value),
                confidence: 0.96
            )
        }
    }

    private func extractDates(in line: String, documentID: UUID, pageNumber: Int) -> [ExtractedField] {
        guard let detector else { return [] }

        let lowered = line.lowercased()
        let fieldName: FieldHint?
        if containsAny(lowered, phrases: ["expiry", "expiration", "expires", "到期", "过期", "valid until"]) {
            fieldName = .expiryDate
        } else if containsAny(lowered, phrases: ["issue", "issued", "签发", "签署", "生效"]) {
            fieldName = .issueDate
        } else if containsAny(lowered, phrases: ["birth", "dob", "出生", "生日"]) {
            fieldName = .birthDate
        } else {
            fieldName = nil
        }

        guard let fieldName else { return [] }

        let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
        let matches = detector.matches(in: line, options: [], range: nsRange)

        return matches.compactMap { match in
            guard let range = Range(match.range, in: line) else { return nil }
            let raw = String(line[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedValue = normalizedDateString(from: match.date) ?? normalizer.normalizeQuery(raw)

            return ExtractedField(
                documentID: documentID,
                pageNumber: pageNumber,
                fieldName: fieldName,
                fieldValue: raw,
                normalizedValue: normalizedValue,
                confidence: 0.92
            )
        }
    }

    private func extractAmounts(in line: String, documentID: UUID, pageNumber: Int) -> [ExtractedField] {
        let lowered = line.lowercased()
        guard containsAny(lowered, phrases: ["违约金", "penalty", "termination", "fee", "amount", "金额", "押金", "deposit", "deductible"]) else {
            return []
        }

        let fieldName: FieldHint = containsAny(lowered, phrases: ["违约金", "penalty", "termination"]) ? .penaltyAmount : .amount
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        let matches = amountRegex.matches(in: line, options: [], range: range)

        return matches.compactMap { match in
            guard let matchRange = Range(match.range, in: line) else { return nil }
            let value = String(line[matchRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard value.rangeOfCharacter(from: .decimalDigits) != nil else { return nil }
            return ExtractedField(
                documentID: documentID,
                pageNumber: pageNumber,
                fieldName: fieldName,
                fieldValue: value,
                normalizedValue: normalizeAmount(value),
                confidence: 0.89
            )
        }
    }

    private func deduplicated(_ fields: [ExtractedField]) -> [ExtractedField] {
        var seen: Set<String> = []
        var output: [ExtractedField] = []

        for field in fields {
            let key = "\(field.pageNumber)|\(field.fieldName.rawValue)|\(field.normalizedValue)"
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            output.append(field)
        }

        return output
    }

    private func normalizeAmount(_ value: String) -> String {
        value
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedDateString(from date: Date?) -> String? {
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func containsAny(_ line: String, phrases: [String]) -> Bool {
        phrases.contains { line.contains($0) }
    }
}
