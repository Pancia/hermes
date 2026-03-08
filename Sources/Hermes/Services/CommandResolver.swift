import Foundation

/// Resolves dynamic titles by running shell commands
enum CommandResolver {
    private static let shells: [String: String] = [
        "fish": "/opt/homebrew/bin/fish",
        "bash": "/bin/bash",
        "zsh": "/bin/zsh",
    ]

    static func resolve(_ commands: [String: CommandEntry]) -> [String: CommandEntry] {
        var result: [String: CommandEntry] = [:]
        for (key, entry) in commands {
            result[key] = resolveEntry(entry)
        }
        return result
    }

    private static func resolveEntry(_ entry: CommandEntry) -> CommandEntry {
        switch entry {
        case .action(_, let command, let dynamicTitle):
            let resolved = dynamicTitle.map { resolveDynamicTitle($0) } ?? entry.title
            return .action(title: resolved, command: command)
        case .submenu(let desc, let items):
            var resolvedItems: [String: CommandEntry] = [:]
            for (k, v) in items {
                resolvedItems[k] = resolveEntry(v)
            }
            return .submenu(desc: desc, items: resolvedItems)
        }
    }

    static func resolveDynamicTitle(_ dt: DynamicTitle) -> String {
        guard let shellPath = shells[dt.shell] else { return "(?)" }
        let output = ShellExecutor.runSync(shellPath, args: ["-c", dt.cmd])
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "(?)" : trimmed
    }
}
