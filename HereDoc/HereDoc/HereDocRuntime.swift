import Foundation
import HereDocSearch
import HereDocStorage

enum HereDocRuntime {
    nonisolated(unsafe) static let queryEngine = DocumentQueryEngine()

    nonisolated static func databaseURL() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return support
            .appending(path: "HereDoc", directoryHint: .isDirectory)
            .appending(path: "HereDoc.sqlite", directoryHint: .notDirectory)
    }

    nonisolated static func makeDocumentStore() throws -> LocalDocumentStore {
        try LocalDocumentStore(databaseURL: databaseURL())
    }
}
