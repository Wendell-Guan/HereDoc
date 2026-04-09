import Foundation
import GRDB

public enum HereDocDatabase {
    public static func makeQueue(at url: URL) throws -> DatabaseQueue {
        var configuration = Configuration()
        configuration.foreignKeysEnabled = true
        configuration.label = "HereDocDatabase"

        let queue = try DatabaseQueue(path: url.path, configuration: configuration)
        try migrator.migrate(queue)
        return queue
    }

    public static let migrator: DatabaseMigrator = {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("create_core_tables") { db in
            try db.create(table: "documents") { t in
                t.column("id", .text).primaryKey()
                t.column("title", .text).notNull()
                t.column("document_type", .text).notNull()
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
                t.column("page_count", .integer).notNull().defaults(to: 0)
                t.column("checksum", .text)
                t.column("cloud_kit_record_name", .text)
                t.column("file_local_path", .text).notNull()
            }

            try db.create(table: "pages") { t in
                t.column("id", .text).primaryKey()
                t.column("document_id", .text).notNull().references("documents", onDelete: .cascade)
                t.column("page_number", .integer).notNull()
                t.column("image_local_path", .text)
                t.column("text", .text).notNull().defaults(to: "")
                t.column("width", .double)
                t.column("height", .double)
                t.column("cloud_kit_record_name", .text)
                t.uniqueKey(["document_id", "page_number"])
            }

            try db.create(table: "blocks") { t in
                t.column("id", .text).primaryKey()
                t.column("document_id", .text).notNull().references("documents", onDelete: .cascade)
                t.column("page_id", .text).notNull().references("pages", onDelete: .cascade)
                t.column("page_number", .integer).notNull()
                t.column("block_type", .text).notNull()
                t.column("text", .text).notNull()
                t.column("normalized_text", .text).notNull()
                t.column("confidence", .double)
                t.column("bbox_x", .double)
                t.column("bbox_y", .double)
                t.column("bbox_width", .double)
                t.column("bbox_height", .double)
            }

            try db.create(table: "extracted_fields") { t in
                t.column("id", .text).primaryKey()
                t.column("document_id", .text).notNull().references("documents", onDelete: .cascade)
                t.column("page_number", .integer).notNull()
                t.column("field_name", .text).notNull()
                t.column("field_value", .text).notNull()
                t.column("normalized_value", .text).notNull()
                t.column("confidence", .double)
                t.column("bbox_x", .double)
                t.column("bbox_y", .double)
                t.column("bbox_width", .double)
                t.column("bbox_height", .double)
            }

            try db.execute(sql: """
                CREATE VIRTUAL TABLE block_search USING fts5(
                    text,
                    normalized_text,
                    content='blocks',
                    content_rowid='rowid',
                    tokenize='unicode61'
                )
                """)

            try db.execute(sql: """
                CREATE TRIGGER blocks_ai AFTER INSERT ON blocks BEGIN
                    INSERT INTO block_search(rowid, text, normalized_text)
                    VALUES (new.rowid, new.text, new.normalized_text);
                END
                """)

            try db.execute(sql: """
                CREATE TRIGGER blocks_ad AFTER DELETE ON blocks BEGIN
                    INSERT INTO block_search(block_search, rowid, text, normalized_text)
                    VALUES('delete', old.rowid, old.text, old.normalized_text);
                END
                """)

            try db.execute(sql: """
                CREATE TRIGGER blocks_au AFTER UPDATE ON blocks BEGIN
                    INSERT INTO block_search(block_search, rowid, text, normalized_text)
                    VALUES('delete', old.rowid, old.text, old.normalized_text);
                    INSERT INTO block_search(rowid, text, normalized_text)
                    VALUES (new.rowid, new.text, new.normalized_text);
                END
                """)

            try db.create(index: "idx_pages_document_id", on: "pages", columns: ["document_id"])
            try db.create(index: "idx_blocks_document_id", on: "blocks", columns: ["document_id"])
            try db.create(index: "idx_blocks_page_id", on: "blocks", columns: ["page_id"])
            try db.create(index: "idx_fields_document_id", on: "extracted_fields", columns: ["document_id"])
            try db.create(index: "idx_fields_field_name", on: "extracted_fields", columns: ["field_name"])
        }

        return migrator
    }()
}
