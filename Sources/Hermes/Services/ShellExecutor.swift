import Foundation

/// Executes shell commands — interactive ones in Ghostty, background ones via fish
enum ShellExecutor {
    static func execute(_ spec: CommandSpec) {
        switch spec.mode {
        case .background:
            executeBackground(spec.cmd)
        case .shell:
            executeShell(spec.cmd)
        case .interactive:
            executeInteractive(spec.cmd)
        }
    }

    /// Run in background, discard output
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

    /// Open terminal, exit when command finishes
    static func executeShell(_ command: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-na", "ghostty", "--args", "-e", "/opt/homebrew/bin/fish", "-c", command]
        try? task.run()
    }

    /// Open terminal, drop into interactive shell after command runs
    static func executeInteractive(_ command: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-na", "ghostty", "--args", "-e", "/opt/homebrew/bin/fish", "-C", command]
        try? task.run()
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
