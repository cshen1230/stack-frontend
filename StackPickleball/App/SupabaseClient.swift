import Foundation
import Supabase

enum SupabaseConfig {
    /// Configure via environment variables in your Run Scheme:
    /// - `SUPABASE_URL`
    /// - `SUPABASE_ANON_KEY` (preferred) or `SUPABASE_PUBLISHABLE_KEY`
    ///
    /// You can also provide a `.env` file (not committed) by adding it to your app target's
    /// "Copy Bundle Resources" build phase. See `.env.example` at the repo root.
    ///
    /// If not provided, we fall back to local Supabase dev defaults.
    private static func env(_ key: String) -> String? {
        let value = ProcessInfo.processInfo.environment[key]
            ?? DotEnv.value(for: key)
        let trimmed = value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty == false) ? trimmed : nil
    }

    static var url: URL {
        if let raw = env("SUPABASE_URL"), let parsed = URL(string: raw) {
            return parsed
        }
        // Local Supabase dev default — update after running `supabase status`
        return URL(string: "http://127.0.0.1:54321")!
    }

    static var anonKey: String {
        if let key = env("SUPABASE_ANON_KEY") ?? env("SUPABASE_PUBLISHABLE_KEY") {
            return key
        }
        // Local Supabase dev default key
        return "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
    }
}

private enum DotEnv {
    static func value(for key: String) -> String? {
        values[key]
    }

    private static let values: [String: String] = load()

    private static func load() -> [String: String] {
        // Prefer `.env` in the app bundle if the developer adds it to Copy Bundle Resources.
        let bundleCandidates: [URL] = [
            Bundle.main.url(forResource: ".env", withExtension: nil),
            Bundle.main.url(forResource: "StackPickleball", withExtension: "env"),
        ].compactMap { $0 }

        for url in bundleCandidates {
            if let contents = try? String(contentsOf: url, encoding: .utf8) {
                return parse(contents)
            }
        }

        return [:]
    }

    private static func parse(_ contents: String) -> [String: String] {
        var out: [String: String] = [:]

        for rawLine in contents.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line.hasPrefix("#") { continue }

            let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            if parts.count != 2 { continue }

            let key = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            var value = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)

            if value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") {
                value = String(value.dropFirst().dropLast())
            }

            if !key.isEmpty {
                out[key] = value
            }
        }

        return out
    }
}

let supabase = SupabaseClient(
    supabaseURL: SupabaseConfig.url,
    supabaseKey: SupabaseConfig.anonKey
)
