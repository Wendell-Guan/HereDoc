# HereDoc

Apple-only document copilot MVP preparation workspace.

## What is in this repo

- `APPLE_ONLY_ARCHITECTURE.md`
  - Apple-only MVP architecture, ingestion flow, query flow, and local data model
- `STACK_DECISIONS.md`
  - validated stack choices, why they were selected, and what is deferred
- `Package.swift`
  - shared Swift package for storage, query planning, and AI-provider abstraction

## Build note

- This repo now resolves package dependencies directly from GitHub.
- Local `refs/` folders were only used during research and are **not required** for cloning or building.

## Selected direction

- `SwiftUI + VisionKit + Vision + NaturalLanguage + PDFKit + CloudKit`
- `GRDB + SQLite FTS5` for local-first storage and search
- `MCP` is kept as a future bridge direction, not a build-time dependency for the iPhone MVP
- `Multi-provider AI adapter` instead of hard-wiring one SDK
- `AI only after deterministic retrieval`

## Why this shape

- Lowest-cost useful MVP
- Strong Apple-native UX
- Easy to open-source
- Future path to enterprise backend still exists

## Important truth

This first version is optimized for:

- personal Apple users
- local-first document understanding
- optional BYO-API-key AI features

It is **not** yet the enterprise backend architecture.

## Open in Xcode

1. Open this folder in Xcode.
2. Open `Package.swift`.
3. Review the shared modules.
4. Create the `HereDocApp` iOS target in Xcode and import these package targets as local dependencies.

## Suggested next build step

Build the app in this order:

1. Scan/import
2. OCR and local persistence
3. Search and source highlighting
4. AI answer step
5. CloudKit sync
