# Agent Instructions & Workflow Protocol

## 1. Requirement & Progress Synchronization (MANDATORY)
- **Always update `PROGRESS.md`**: For every new request or requirement given by the user, immediately log and track it in [PROGRESS.md](file:///Users/jasonkhaw/Documents/Coding/FinanceTracker/PROGRESS.md).
- Document new phases with structured task IDs (e.g., Phase XX), files modified, key architectural decisions, and mark completed items with `(DONE)`.
- Always maintain and update the `## 📍 CURRENT STATUS` section at the bottom of [PROGRESS.md](file:///Users/jasonkhaw/Documents/Coding/FinanceTracker/PROGRESS.md) with `Last Completed`, `Next Task`, and `Last updated version/date`.
- This ensures any new agent or new conversation thread can instantly read [PROGRESS.md](file:///Users/jasonkhaw/Documents/Coding/FinanceTracker/PROGRESS.md) and understand the full project history.

## 2. Version Bump & GitHub Synchronization (MANDATORY)
- **Automatic GitHub Sync on Version Changes**:
  - Whenever an iteration or feature set causes a version change (e.g. updating `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `project.yml` and `SettingsView.swift`):
    1. Regenerate Xcode project: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodegen generate`
    2. Run full test suite: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project FinanceTracker.xcodeproj -scheme FinanceTracker -destination 'platform=iOS Simulator,name=iPhone 17'`
    3. Stage all non-ignored changes: `git add .`
    4. Commit with descriptive release message: `git commit -m "chore: release vX.Y.Z - <summary>"`
    5. Create git tag: `git tag vX.Y.Z`
    6. Push commits and tags to GitHub: `git push origin main --tags`
- The remote repository is: `https://github.com/ado0330/FinanceTracker.git`

## 3. API Key & Security Guarantee (MANDATORY)
- **Strictly Keep Secrets Safe**:
  - `Secrets.local.plist` is git-ignored and MUST NEVER be staged or committed.
  - `AppSecrets.swift` resolves the Gemini API key dynamically from `Secrets.local.plist` during local runs/tests, and falls back cleanly without compilation error.
  - NEVER commit hardcoded API keys or personal credentials to git.

## 4. UI Design & Localization Standards
- **100% English UI**: All user-facing texts, labels, buttons, navigation titles, and dialogs in the iOS app must be in English (0 Chinese characters).
- **Luxury Monochrome Aesthetic**: Follow strict black, white, and dark graphite minimalist palette (`Color.primary`, `.systemBackground`, `.secondarySystemGroupedBackground`).
