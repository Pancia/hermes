import Foundation

/// Executes shell commands — interactive ones in Ghostty, background ones via fish
enum ShellExecutor {
    private static let interactivePatterns: [String] = [
        "^n?vim\\s", "^v\\s", "^v$", "&&\\s*v$", "&&\\s*v\\s",
        "^htop", "^less\\s", "^man\\s", "^cmus", "^ytdl$", "^ytdl\\s",
    ]

    static func execute(_ command: String) {
        if needsTerminal(command) {
            executeInteractive(command)
        } else {
            executeBackground(command)
        }
    }

    static func needsTerminal(_ command: String) -> Bool {
        for pattern in interactivePatterns {
            if command.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }

    static func executeInteractive(_ command: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-na", "ghostty", "--args", "-e", "/opt/homebrew/bin/fish", "-c", command]
        try? task.run()
    }

    static func executeBackground(_ command: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/fish")
            task.arguments = ["-c", command]
            task.standardOutput = FileHandle.nullDevice
            task.standardError = FileHandle.nullDevice
            try? task.run()
            task.waitUntilExit()
        }
    }

    static func launchApp(_ name: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-a", name]
        try? task.run()
    }

    /// Run a command synchronously and return stdout
    static func runSync(_ executable: String, args: [String]) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
}
