# Apple Official Capabilities Plan

This document narrows the HereDoc Apple-only MVP toward Apple's built-in frameworks wherever that reduces code and long-term maintenance.

## Bottom Line

If the goal is "ship faster with less custom code", the official-first stack should be:

- `SwiftUI` for app structure and import UI.
- `fileImporter` for file intake.
- `VisionKit.VNDocumentCameraViewController` for multi-page document scanning.
- `Vision.VNRecognizeTextRequest` for OCR.
- `PDFKit` for source preview, page navigation, and evidence highlighting.
- `App Intents` for Siri / Shortcuts / Spotlight entry points.
- `Core Data + CloudKit` or `SwiftData + CloudKit` if we want the smallest sync layer.

What should stay optional:

- `DataScannerViewController`: good for live capture, but not the main import path.
- `Foundation Models`: useful as an enhancement, not a core dependency.
- `MCP`: better as a later bridge layer than an iPhone MVP dependency.

## Current Status

Already implemented in the current app:

- `fileImporter`
- `VisionKit.VNDocumentCameraViewController`
- `Vision.VNRecognizeTextRequest`
- `PDFKit.PDFView` preview for PDF sources
- `App Intents` shortcuts for asking documents and checking expiring documents

Still pending:

- more precise PDF evidence highlighting from page ranges / annotations
- CloudKit sync decision and implementation
- final AI summarizer provider plugged into the retrieval pipeline
- MCP bridge beyond the current local skeleton

## Official Capability Map

### 1. File Import

Use:

- `SwiftUI.fileImporter(isPresented:allowedContentTypes:allowsMultipleSelection:onCompletion:)`

Why:

- Lowest-code path for importing PDFs and images from Files, iCloud Drive, or third-party file providers.
- Already a good fit for our current architecture.

Implication for HereDoc:

- Keep this as the default intake path for MVP.
- No need to build a custom picker.

### 2. Camera Scanning

Use:

- `VisionKit.VNDocumentCameraViewController`
- `VNDocumentCameraScan`

Why:

- Apple already provides document edge detection, multi-page capture, and page images.
- The scan result gives `pageCount` and `imageOfPage(at:)`, which maps directly to our `pages` table.

Implication for HereDoc:

- This should become the official "Scan Document" path.
- We should export the captured pages into a PDF or store the page images directly.
- This is a better primary scan UX than writing our own camera + crop flow.

### 3. OCR

Use:

- `Vision.VNRecognizeTextRequest`

Recommended configuration:

- `recognitionLevel = .accurate`
- `usesLanguageCorrection = true` for English-heavy docs
- `recognitionLanguages` set explicitly when we know the expected language mix
- `minimumTextHeight` tuned to skip tiny noise

Important Apple caveat:

- Apple documents note that Chinese text recognition is supported, but language correction and `customWords` aren't supported for Chinese.

Implication for HereDoc:

- This should remain our core OCR engine for iPhone MVP.
- Keep OCR on-device first.
- For passports, receipts, invoices, contracts, use deterministic field extraction after OCR before any AI call.

### 4. Live Camera Recognition

Use:

- `VisionKit.DataScannerViewController`

Why:

- Good for instant capture UX, live text, and quick extraction.

Why not make it the main path:

- Apple documents expose `isSupported` and `isAvailable`, which means support depends on device capability and camera access.
- Better as a "quick scan" enhancement, not the foundation of document ingestion.

Implication for HereDoc:

- Add later as a premium-feeling fast path.
- Do not base the main product pipeline on it.

### 5. Source Preview and Evidence Navigation

Use:

- `PDFKit.PDFView`
- `PDFKit.PDFDocument`
- `PDFKit.PDFSelection`
- `PDFKit.PDFPage`
- `PDFKit.PDFAnnotation` / markup graphics

Why:

- `PDFView` already handles rendering, zoom, selection, and page navigation.
- `PDFDocument` supports search operations like `findString`.
- `PDFPage.selection(for:)` and annotations give us a path to visible source highlighting.

Implication for HereDoc:

- For PDF documents, we should stop thinking in terms of a custom page viewer.
- The best official path is: jump to page -> build selection/highlight -> show evidence context in `PDFView`.

### 6. Cross-Device Sync

Most official / least-code option:

- `Core Data + NSPersistentCloudKitContainer`
- or `SwiftData` with CloudKit sync

Why:

- Apple explicitly documents that changes synchronize automatically in the background when using CloudKit-backed persistent stores.
- This is much less code than writing our own GRDB-to-CloudKit sync layer.

Tradeoff:

- Our current GRDB + SQLite FTS setup is stronger for deterministic local search control.
- But it is not the lowest-code path for sync.

Recommendation:

- If the top priority is "open-source Apple MVP with the least sync code", we should strongly consider moving primary storage to `SwiftData` or `Core Data + CloudKit`.
- If the top priority is "best local search control right now", keep GRDB for the MVP and treat CloudKit sync as phase 2.

My honest recommendation:

- Keep the current GRDB storage for the immediate MVP only because it is already wired.
- Before we go deep on sync, make an explicit decision:
  - `Option A`: stay with GRDB and accept more sync code later.
  - `Option B`: migrate primary storage to official CloudKit mirroring and reduce long-term app code.

### 7. Siri / Shortcuts / Spotlight

Use:

- `App Intents`
- `App Shortcuts`

Why:

- Apple exposes app actions directly to Siri, Spotlight, Shortcuts, and the Action button.
- This aligns very closely with your "future IM / invisible agent" goal, but in Apple-native form first.

Best HereDoc intents to add:

- `AskDocumentsIntent`
- `OpenDocumentIntent`
- `ShowExpiringDocumentsIntent`
- `ImportRecentScanIntent`

Implication for HereDoc:

- We should add App Intents earlier than MCP on iPhone.
- This gives us an official native agent surface with less infrastructure.

### 8. On-Device Generation

Use cautiously:

- `Foundation Models`

Why not core:

- Apple documents say the on-device model has a per-session context limit of 4,096 tokens.
- Apple Support documents also constrain availability by device, OS, and region.

Implication for HereDoc:

- Good for short local rewrite / summarization tasks.
- Not good enough to replace retrieval, indexing, or a full document QA pipeline.
- Treat as optional enhancement only.

## Best-Fit Product Workflow

The best official-first workflow for HereDoc is:

1. `fileImporter` or `VNDocumentCameraViewController`
2. `VNRecognizeTextRequest`
3. deterministic field extraction
4. local persistence
5. local search
6. `PDFView` source jump / highlight
7. optional AI answer generation
8. `App Intents` exposure

That means:

- Apple should handle scanning.
- Apple should handle OCR.
- Apple should handle PDF viewing and source navigation.
- Apple should handle system-level entry points.
- We only write custom code for:
  - field extraction
  - indexing
  - retrieval logic
  - evidence assembly
  - provider abstraction

## What We Should Change Next

### Immediate

1. Improve PDF evidence highlighting so source jumps can mark exact passages, not just page + snippet search.
2. Keep refining `VNRecognizeTextRequest` language configuration and document-type heuristics.

### Soon After

1. Extend `App Intents` with:
   - open latest imported document
   - open expiring document from shortcut context
2. Add a dedicated evidence preview model for PDF page highlighting.

### Decision Checkpoint

Before building CloudKit sync:

- Decide whether we stay with `GRDB` as the primary store
- or pivot to `SwiftData/Core Data + CloudKit` for an official sync path with less custom code.

## Official Docs To Follow

- `fileImporter`: <https://developer.apple.com/documentation/swiftui/view/fileimporter%28ispresented%3Aallowedcontenttypes%3Aallowsmultipleselection%3Aoncompletion%3A%29>
- `VNDocumentCameraViewController`: <https://developer.apple.com/documentation/visionkit/vndocumentcameraviewcontroller>
- `VNDocumentCameraScan`: <https://developer.apple.com/documentation/visionkit/vndocumentcamerascan>
- `Scanning data with the camera`: <https://developer.apple.com/documentation/visionkit/scanning-data-with-the-camera>
- `DataScannerViewController`: <https://developer.apple.com/documentation/visionkit/datascannerviewcontroller>
- `VNRecognizeTextRequest`: <https://developer.apple.com/documentation/vision/vnrecognizetextrequest>
- `Recognizing Text in Images`: <https://developer.apple.com/documentation/vision/recognizing-text-in-images>
- `PDFView`: <https://developer.apple.com/documentation/pdfkit/pdfview>
- `PDFDocument`: <https://developer.apple.com/documentation/pdfkit/pdfdocument>
- `Search Operations`: <https://developer.apple.com/documentation/pdfkit/search-operations>
- `selection(for:)`: <https://developer.apple.com/documentation/pdfkit/pdfpage/selection%28for%3A%29-2ckpi>
- `Adding Custom Graphics to a PDF`: <https://developer.apple.com/documentation/pdfkit/custom-graphics>
- `App Intents`: <https://developer.apple.com/documentation/appintents/app-intents>
- `Creating your first app intent`: <https://developer.apple.com/documentation/appintents/creating-your-first-app-intent>
- `Accelerating app interactions with App Intents`: <https://developer.apple.com/documentation/appintents/acceleratingappinteractionswithappintents>
- `Setting Up Core Data with CloudKit`: <https://developer.apple.com/documentation/coredata/setting-up-core-data-with-cloudkit>
- `Syncing a Core Data Store with CloudKit`: <https://developer.apple.com/documentation/coredata/syncing-a-core-data-store-with-cloudkit>
- `Syncing model data across a person's devices`: <https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices>
- `Foundation Models`: <https://developer.apple.com/documentation/technologyoverviews/foundation-models>
- `Generating content and performing tasks with Foundation Models`: <https://developer.apple.com/documentation/FoundationModels/generating-content-and-performing-tasks-with-foundation-models>
- `How to get Apple Intelligence`: <https://support.apple.com/en-afri/121115>
