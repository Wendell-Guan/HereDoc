# Xcode Integration Next

You already have a starter app project at:

- `/Users/a123456/Downloads/HereDoc/HereDoc/HereDoc.xcodeproj`

Keep it.

## Recommended integration path

1. Open `HereDoc.xcodeproj`
2. Add the local package at the repo root:
   - `File` -> `Add Package Dependencies...`
   - choose local package: `/Users/a123456/Downloads/HereDoc`
3. Link these package products to the app target:
   - `HereDocModels`
   - `HereDocStorage`
   - `HereDocSearch`
   - `HereDocAI`
   - `HereDocMCP` only if you want desktop or tooling experiments later

## What to build first inside the app target

### Screen 1

- document library
- import button
- scan button

### Screen 2

- document detail
- extracted fields card
- source page preview

### Screen 3

- ask screen
- result card
- source chips

## First app services to wire

1. `OCRService`
   - wraps Vision OCR
2. `ImportService`
   - saves local files and page assets
3. `DatabaseService`
   - opens the GRDB database through `HereDocStorage`
4. `QueryService`
   - uses `QuestionIntentClassifier` and `SearchNormalizer`

## Honest recommendation

Do not wire CloudKit or external AI into the app target on day one.

Build order should be:

1. local import
2. local OCR
3. local fields
4. local search
5. source highlighting
6. optional AI
7. CloudKit sync
