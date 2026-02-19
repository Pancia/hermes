import Foundation

/// Resolves dynamic titles (e.g. #!fish:command) by running shell commands
enum CommandResolver {
    static func resolve(_ commands: [String: CommandEntry]) -> [String: CommandEntry] {
        var result: [String: CommandEntry] = [:]
        for (key, entry) in commands {
            result[key] = resolveEntry(entry)
        }
        return result
    }

    private static func resolveEntry(_ entry: CommandEntry) -> CommandEntry {
        switch entry {
        case .action(let title, let command):
            let resolved = resolveDynamicTitle(title)
            return .action(title: resolved, command: command)
        case .submenu(let desc, let items):
            let resolvedDesc = resolveDynamicTitle(desc)
            var resolvedItems: [String: CommandEntry] = [:]
            for (k, v) in items {
                resolvedItems[k] = resolveEntry(v)
            }
            return .submenu(desc: resolvedDesc, items: resolvedItems)
        }
    }

    static func resolveDynamicTitle(_ title: String) -> String {
        guard title.hasPrefix("#!fish:") else { return title }
        let cmd = String(title.dropFirst("#!fish:".count))
        let output = ShellExecutor.runSync("/opt/homebrew/bin/fish", args: ["-c", cmd])
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "(?)" : trimmed
    }
}
