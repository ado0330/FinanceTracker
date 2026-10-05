import Foundation

/// Application secrets and API configuration.
public enum AppSecrets {

    /// Google Gemini API key provided for multimodal receipt scanning.
    /// Safely resolved from local git-ignored Secrets.local.plist, ProcessInfo, or UserDefaults.
    public static var geminiApiKey: String {
        // 1. Check local Secrets.local.plist (git-ignored, kept on developer's machine)
        if let key = localSecretValue(forKey: "GEMINI_API_KEY"), !key.isEmpty {
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

    /// Supabase Project URL for cross-device real-time sync (e.g. https://xyz.supabase.co).
    /// Safely resolved from local git-ignored Secrets.local.plist, ProcessInfo, or UserDefaults.
    public static var supabaseURL: String {
        if let url = localSecretValue(forKey: "SUPABASE_URL"), !url.isEmpty {
            return url
        }
        if let env = ProcessInfo.processInfo.environment["SUPABASE_URL"], !env.isEmpty {
            return env
        }
        if let userURL = UserDefaults.standard.string(forKey: "supabase_project_url"), !userURL.isEmpty {
            return userURL
        }
        return ""
    }

    /// Supabase Anon Public Key for cross-device real-time sync.
    /// Safely resolved from local git-ignored Secrets.local.plist, ProcessInfo, or UserDefaults.
    public static var supabaseAnonKey: String {
        if let key = localSecretValue(forKey: "SUPABASE_ANON_KEY"), !key.isEmpty {
            return key
        }
        if let env = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"], !env.isEmpty {
            return env
        }
        if let userKey = UserDefaults.standard.string(forKey: "supabase_anon_key"), !userKey.isEmpty {
            return userKey
        }
        return ""
    }

    /// Indicates whether Supabase sync credentials are provided via local Secrets.local.plist file.
    public static var isSupabaseConfiguredLocally: Bool {
        guard let plist = loadSecretPlist() else { return false }
        let url = (plist["SUPABASE_URL"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let key = (plist["SUPABASE_ANON_KEY"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !url.isEmpty && !key.isEmpty
    }

    /// Default Gemini model to use for scanning receipts.
    public static let defaultGeminiModel: String = "gemini-3.5-flash-lite"

    // MARK: - Private Local Key Resolver

    private static func localSecretValue(forKey targetKey: String) -> String? {
        guard let plist = loadSecretPlist() else { return nil }
        if let value = plist[targetKey] as? String,
           !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private static func loadSecretPlist() -> [String: Any]? {
        // 1. Direct project directory lookup during development & local testing (instant)
        let localSourcePath = #filePath
        let dir = URL(fileURLWithPath: localSourcePath).deletingLastPathComponent()
        let directFile = dir.appendingPathComponent("Secrets.local.plist")
        if let data = try? Data(contentsOf: directFile),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            return plist
        }

        // 2. Main app bundle lookup if bundled onto an iOS device
        if let url = Bundle.main.url(forResource: "Secrets.local", withExtension: "plist"),
           let data = try? Data(contentsOf: url),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            return plist
        }

        return nil
    }
}
