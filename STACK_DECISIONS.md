# Stack Decisions

## 1. Final Recommendation

For the open-source first release, use:

- `SwiftUI` for app UI
- `VisionKit` for scan/import UX
- `Vision` for OCR and bounding boxes
- `NaturalLanguage` for tokenization and lightweight text understanding
- `GRDB + SQLite FTS5` for local database and search
- `CloudKit` for Apple-only sync
- `PDFKit` for source-page rendering and highlight overlays
- `MCP Swift SDK` for future MCP tool exposure
- `URLSession-based AI provider adapters` for OpenAI, Anthropic, Gemini, Ollama, and OpenAI-compatible endpoints

## 2. What We Adopt Directly

### GRDB.swift

Status:

- actively maintained
- latest local shallow clone commit: `2026-02-15`
- MIT license

Why selected:

- mature, battle-tested SQLite toolkit
- strong migrations and concurrency story
- direct control over schema and FTS setup
- better fit than higher-level persistence abstractions for a search-heavy app

Decision:

- `Adopt directly`

Reference:

- `refs/GRDB.swift`

### Apple sample-cloudkit-sync-engine

Status:

- official Apple sample
- latest local shallow clone commit: `2023-12-07`
- MIT-style license

Why selected:

- uses `CKSyncEngine`, which is the right direction for custom sync logic
- shows conflict handling and remote-notification-driven sync
- good architectural reference even if we do not copy it line-for-line

Decision:

- `Use as reference architecture`, not as a direct dependency

Reference:

- `refs/sample-cloudkit-sync-engine`

### modelcontextprotocol/swift-sdk

Status:

- official Swift SDK for MCP
- latest local shallow clone commit: `2026-03-24`
- Apache 2.0 transition / mixed MIT + Apache licensing in repo history

Why selected:

- official implementation
- supports both client and server
- supports stdio and HTTP transports
- avoids inventing our own tool protocol layer

Decision:

- `Adopt directly for future MCP integration`

Reference:

- `refs/mcp-swift-sdk`

## 3. What We Only Reference For Now

### SQLiteData

Status:

- latest local shallow clone commit: `2026-03-25`
- MIT license

Why not selected as the primary dependency:

- promising and modern
- includes CloudKit sync and sharing
- but newer and less battle-proven than GRDB itself
- for this project we need low-level control over FTS tables, custom search normalization, and explicit migration behavior

Decision:

- `Reference only`
- choose `GRDB directly` for first release

Reference:

- `refs/sqlite-data`

### Docling

Why it matters:

- strong future candidate for server-side document grounding and richer parsing
- especially relevant if later we add enterprise backend ingestion

Why not for day one:

- too heavy for on-device iPhone workflow
- better as phase-two backend enhancement

Decision:

- `Future backend reference`

### OCRmyPDF

Status:

- latest local shallow clone commit: `2026-04-06`
- MPL 2.0
- README explicitly says it is battle-tested on millions of PDFs

Why it matters:

- great for macOS-side batch import and searchable PDF generation
- useful for power users importing old scanned PDFs

Why not core dependency for the iPhone app:

- Python/CLI oriented
- not suitable as the primary mobile OCR path

Decision:

- `Optional desktop companion / import helper`

Reference:

- `refs/OCRmyPDF`

## 4. Apple Framework Choices

### VisionKit + Vision

Use for:

- scan UI
- rectangle detection
- OCR
- bounding boxes

Decision:

- `Core day-one dependency`

### NaturalLanguage

Use for:

- tokenization
- search normalization
- cheap local language heuristics

Decision:

- `Core day-one dependency`

Reason:

- lets us improve Chinese and multilingual search without adding heavy external tokenizers

### CloudKit

Use for:

- Apple-only sync for documents, metadata, and extracted fields

Decision:

- `Use for the open-source Apple edition`

Truth:

- good for Apple-only sync
- not the final enterprise backend story

### PDFKit

Use for:

- source preview
- page navigation
- highlight rendering

Decision:

- `Core day-one dependency`

## 5. Multi-API Strategy

Do **not** couple the app to any one third-party SDK.

Instead:

- define one `AIProvider` protocol
- define one `AIProviderProfile`
- route workloads by capability

Workloads:

- `answer`
- `summary`
- `field extraction fallback`
- `vision reasoning` later

Recommended providers to support behind the same abstraction:

- `OpenAI`
- `Anthropic`
- `Gemini`
- `Ollama`
- `OpenAI-compatible custom endpoint`

Why this is better:

- no provider lock-in
- users can bring their own API key in the open-source edition
- enterprise edition can later replace the provider layer with a server-side gateway

## 6. MCP Strategy

Truthful recommendation:

- do **not** try to host a full MCP server inside the iPhone app as a primary architecture
- do build the document tool layer so it can be wrapped by an MCP server on macOS or a future backend

Recommended tools:

- `search_documents`
- `get_extracted_fields`
- `read_source_page`
- `answer_documents`

Recommended transports:

- `stdio` for local desktop/CLI use
- `stateful HTTP` for future backend or desktop companion

Why:

- realistic on macOS and backend
- awkward on iOS as a long-lived server process

## 7. Retrieval Workflow Decision

The chosen workflow is:

`scan/import -> OCR -> blocks/fields -> local FTS search -> evidence set -> optional AI -> cited answer`

Not chosen:

- full-document-to-LLM
- vector search first
- cloud-only OCR first
- local LLM as the primary answer engine

Reason:

- lower cost
- lower latency
- better explainability
- easier source grounding

## 8. Honest Risks

- CloudKit-first architecture is excellent for Apple personal sync, but not a clean enterprise permission system
- FTS-only search will be strong for exact and clause lookup, but later we may still want embeddings for semantic comparison
- user-supplied API keys are acceptable for open source, but not the final UX for paid enterprise

## 9. What We Should Build Next

1. Xcode iOS app shell
2. local DB and migrations
3. scan/import flow
4. OCR and field extraction
5. local search and source viewer
6. optional provider-based AI answer step
7. CloudKit sync
