# Antigravity Rules: Progress Logging & GitHub Synchronization

## Core Rules for FinanceTracker
1. **User Request Tracking**: Every user request must be reflected in `PROGRESS.md`. When starting work, add planned tasks; when finishing work, mark tasks with `(DONE)` and update `## 📍 CURRENT STATUS`.
2. **GitHub Auto-Sync on Version Changes**: Whenever `MARKETING_VERSION` or `CURRENT_PROJECT_VERSION` changes, commit the release and push to `origin main` along with the release tag (e.g. `git tag v1.8.4` and `git push origin main --tags`).
3. **Security**: Never commit raw API keys or tokens. `Secrets.local.plist` must remain git-ignored.
4. **Localization**: The app must remain 100% English.
