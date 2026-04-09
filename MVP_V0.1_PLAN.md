# MVP v0.1 Plan

This milestone turns the current Apple-first scaffold into a usable open-source release candidate.

Milestone:

- `MVP v0.1`
- GitHub milestone: <https://github.com/Wendell-Guan/HereDoc/milestone/1>

## Goal

Ship a local-first iPhone/iPad document copilot that can:

- import files or scan paper documents
- run OCR on-device
- extract key fields deterministically
- search local evidence quickly
- answer with grounded source references
- preview the source page in-app
- support user-configured AI providers and OpenAI-compatible relay endpoints

## Scope

### In scope

- Apple-native scan and import flow
- local OCR and field extraction
- local GRDB persistence
- SQLite FTS retrieval
- PDF source preview
- App Intents shortcuts
- Chinese-first shell and settings UX
- API key and provider settings management

### Out of scope

- enterprise multi-tenant backend
- Android support
- server-side document ingestion
- production MCP bridge
- collaborative sharing

## Workstreams

### 1. Import and OCR hardening

Target:

- make scan/import stable enough for daily personal use

Done when:

- image import works reliably
- PDF import works with text-layer fallback
- camera scan flow creates clean multi-page PDFs
- OCR handles English + Simplified Chinese + Traditional Chinese

### 2. Retrieval and grounded answers

Target:

- make the query path feel trustworthy and explainable

Done when:

- exact-field questions resolve from structured fields first
- clause lookup and passage search return source-backed hits
- grounded answers always cite page-level evidence
- empty-state and no-match behavior are clear

### 3. PDF evidence preview

Target:

- make source navigation feel like a real product, not a debug view

Done when:

- users can jump to the cited page
- matched text is highlighted more precisely
- document detail view clearly marks the cited page and source snippet

### 4. Provider settings and relay support

Target:

- let users bring their own model endpoint without editing code

Done when:

- API keys are stored in Keychain
- provider list is editable in-app
- OpenAI-compatible relay endpoints like `aimixhub` can be configured with custom base URL and model
- answer generation can use the selected provider

### 5. Chinese-first UX polish

Target:

- make the first-run experience feel native for Chinese-speaking users

Done when:

- main tabs and key actions use Chinese copy
- settings and provider screens use Chinese-first labels
- status messages are understandable without English-only terminology

### 6. Release readiness

Target:

- make the repo understandable and runnable by outside developers

Done when:

- README reflects the actual app state
- setup steps are current
- milestone issues are linked and scoped
- build and test commands are documented

## Proposed Issue Breakdown

1. Harden VisionKit import and OCR pipeline
2. Improve retrieval planner and grounded answer behavior
3. Add precise PDF source highlighting
4. Add provider settings UI and Keychain-backed API keys
5. Support OpenAI-compatible relay endpoints for final answers
6. Translate the app shell and settings into Chinese-first copy
7. Refresh README and release checklist for open-source MVP

## Suggested Order

1. Provider settings and relay support
2. Final-answer provider integration
3. Chinese-first app shell
4. PDF highlighting polish
5. README and release cleanup

## Definition of Done

`MVP v0.1` is complete when a new user can:

1. clone the repo
2. build the app in Xcode
3. import or scan a document
4. ask a basic question
5. see the source page
6. optionally configure their own API endpoint and key
