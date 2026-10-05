import Foundation

/// Application secrets and API configuration.
public enum AppSecrets {

    /// Google Gemini API key provided for multimodal receipt scanning.
    /// Safely resolved from local git-ignored Secrets.local.plist, ProcessInfo, or UserDefaults.
    public static var geminiApiKey: String {
        // 1. Check local Secrets.local.plist (git-ignored, kept on developer's machine)
        if let key = localSecretApiKey, !key.isEmpty {
            return key
        }
        // 2. Check process environment (for CI/CD or custom schemes)
        if let env = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !env.isEmpty {
            return env
        }
        // 3. Check UserDefaults (for users who enter their key in app settings)
        if let userKey = UserDefaults.standard.string(forKey: "geminiApiKey"), !userKey.isEmpty {
            return userKey
        }
        return ""
    }

    /// Default Gemini model to use for scanning receipts.
    public static let defaultGeminiModel: String = "gemini-3.5-flash-lite"

    // MARK: - Private Local Key Resolver

    private static var localSecretApiKey: String? {
        // 1. Direct project directory lookup during development & local testing (instant)
        let localSourcePath = #filePath
        let dir = URL(fileURLWithPath: localSourcePath).deletingLastPathComponent()
        let directFile = dir.appendingPathComponent("Secrets.local.plist")
        if let data = try? Data(contentsOf: directFile),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
           let key = plist["GEMINI_API_KEY"] as? String,
           !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return key.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // 2. Main app bundle lookup if bundled
        if let url = Bundle.main.url(forResource: "Secrets.local", withExtension: "plist"),
           let data = try? Data(contentsOf: url),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
           let key = plist["GEMINI_API_KEY"] as? String,
           !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return key.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }
}
