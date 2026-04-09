import AppIntents
import Foundation
import HereDocModels
import HereDocSearch

struct AskDocumentsIntent: AppIntent {
    static let title: LocalizedStringResource = "Ask Documents"
    static let description = IntentDescription("Search imported HereDoc documents and answer using grounded local evidence.")
    static let openAppWhenRun = false

    @Parameter(
        title: "Question",
        requestValueDialog: IntentDialog("What would you like to know about your documents?")
    )
    var question: String

    static var parameterSummary: some ParameterSummary {
        Summary("Ask HereDoc \(\.$question)")
    }

    func perform() async -> some IntentResult & ProvidesDialog {
        do {
            let store = try HereDocRuntime.makeDocumentStore()
            let result = try await HereDocRuntime.queryEngine.answer(question: question, using: store)
            return .result(dialog: "\(result.answer?.answer ?? result.status)")
        } catch {
            return .result(dialog: "I couldn't search your local library yet.")
        }
    }
}

struct ShowExpiringDocumentsIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Expiring Documents"
    static let description = IntentDescription("Summarize which imported documents expire soon based on extracted dates.")
    static let openAppWhenRun = false

    @Parameter(
        title: "Days Ahead",
        default: 30,
        inclusiveRange: (1, 365),
        requestValueDialog: IntentDialog("How many days ahead should I check?")
    )
    var daysAhead: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Show documents expiring within \(\.$daysAhead) days")
    }

    func perform() async -> some IntentResult & ProvidesDialog {
        do {
            let store = try HereDocRuntime.makeDocumentStore()
            let hits = try await HereDocRuntime.queryEngine.upcomingExpirations(
                withinDays: daysAhead,
                using: store,
                limit: 5
            )

            guard hits.isEmpty == false else {
                return .result(dialog: "No imported documents expire in the next \(daysAhead) days.")
            }

            let preview = hits
                .prefix(3)
                .map { hit in
                    "\(hit.documentTitle) in \(max(hit.daysRemaining, 0)) day\(hit.daysRemaining == 1 ? "" : "s")"
                }
                .joined(separator: ", ")

            let suffix = hits.count > 3 ? ", plus \(hits.count - 3) more." : "."
            return .result(dialog: "\(hits.count) document(s) expire in the next \(daysAhead) days: \(preview)\(suffix)")
        } catch {
            return .result(dialog: "I couldn't read the expiring-document list yet.")
        }
    }
}

struct HereDocShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor { .teal }

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AskDocumentsIntent(),
            phrases: [
                "Ask \(.applicationName) about my documents",
                "Search my files with \(.applicationName)",
                "Ask my document library in \(.applicationName)"
            ],
            shortTitle: "Ask Documents",
            systemImageName: "text.magnifyingglass"
        )

        AppShortcut(
            intent: ShowExpiringDocumentsIntent(),
            phrases: [
                "Show expiring documents in \(.applicationName)",
                "What expires soon in \(.applicationName)",
                "Check deadlines in \(.applicationName)"
            ],
            shortTitle: "Expiring Soon",
            systemImageName: "calendar.badge.exclamationmark"
        )
    }
}
