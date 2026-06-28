# Walkthrough — Phase 1-D: Template Selection, PDF Generation, and Cloudinary Upload

We have successfully implemented the Template selection grid, dual multi-page PDF generation renderers, local file writers, Cloudinary upload pipelines, and manual draggable bottom sheets.

## Changes Made

### 1. Cloudinary Upload Service
- **Unsigned Upload Preset:** Configured `CloudinaryPublic` client targeting cloud `dkrnhqhe9` and preset `resumind`.
- **Upload methods:** Implemented `uploadPdf` and `uploadImage` targeting the respective folder paths (`resumind/users/{userId}/cvs` and `resumind/users/{userId}/profile`).
- **Network Retries:** Added a recursive helper function retrying on exceptions.

### 2. Template Selection Grid
- **2-Column Grid:** Displays all 8 design templates (Clean, Simple, Basic, Professional, Modern, Europass, Executive, Nepal Special).
- **Pro Lock System:** Locked premium templates for free users, showing upgrade sheets on tap.
- **Firestore Synchronization:** Updates target document's `template` field with the chosen string before redirecting to previews.

### 3. PDF Service Renderers
- **Clean Template:** White canvas, vertical sections, and thin dividers.
- **Professional Template:** Colored header banner (`#6C63FF`), white contact row, and two-column layouts.
- **Save to Device:** Writes file bytes to documents directory utilizing timestamped name formats.

### 4. PDF Preview & Editing
- **PDF Preview inline:** Displays rendered PDF output immediately.
- **Color score chip:** Visualizes score with responsive green/orange/red badges.
- **Draggable bottom sheet:** Modular expandable sections containing editable text boxes.
- **AI Suggestions card:** Shows collapsible details containing improvement suggestions.

---

## Verification Results

### Automated Tests
- Running `flutter analyze` completed with **zero** warnings or errors.
- Running `flutter test` completes successfully.
- APK built successfully with `flutter build apk --debug`.
