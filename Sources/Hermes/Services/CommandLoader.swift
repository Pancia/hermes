import Foundation

/// Loads commands from JSON config, handling generators and nested menus
enum CommandLoader {
    static func load() -> [String: CommandEntry] {
        guard let url = Bundle.module.url(forResource: "commands", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return parseMenu(json)
    }

    static func parseMenu(_ dict: [String: Any]) -> [String: CommandEntry] {
        var result: [String: CommandEntry] = [:]
        for (key, value) in dict {
            if key.hasPrefix("_") { continue }
            if let entry = parseEntry(value) {
                result[key] = entry
            }
        }
        return result
    }

    static func parseEntry(_ value: Any) -> CommandEntry? {
        // Array: [title, command] — action
        if let arr = value as? [Any], arr.count >= 2,
           let title = arr[0] as? String {
            if let cmd = arr[1] as? String {
                return .action(title: title, command: cmd)
            }
            // Array command (direct execution) — treat as action with joined command
            if let cmdArr = arr[1] as? [String] {
                return .action(title: title, command: cmdArr.joined(separator: " "))
            }
            return nil
        }

        // Dict with _desc: submenu
        if let dict = value as? [String: Any] {
            let desc = dict["_desc"] as? String ?? "+"
            let items = parseMenu(dict)
            if !items.isEmpty {
                return .submenu(desc: desc, items: items)
            }
        }

        // String with "generator:" prefix
        if let gen = value as? String, gen.hasPrefix("generator:") {
            let name = String(gen.dropFirst("generator:".count))
            return loadGenerator(name)
        }

        return nil
    }

    static func loadGenerator(_ name: String) -> CommandEntry? {
        switch name {
        case "snippets": return buildSnippetsMenu()
        case "services": return buildServicesMenu()
        case "vpc": return buildVpcMenu()
        default: return nil
        }
    }

    // MARK: - Dynamic Generators

    static func buildVpcMenu() -> CommandEntry {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let vpcDir = "\(home)/dotfiles/vpc"
        var items: [String: CommandEntry] = [:]

        guard let files = try? FileManager.default.contentsOfDirectory(atPath: vpcDir) else {
            return .submenu(desc: "VPC Workspaces", items: ["x": .action(title: "No VPC files found", command: "echo 'No .vpc files'")])
        }

        let vpcFiles = files.filter { $0.hasSuffix(".vpc") }
            .map { ($0.replacingOccurrences(of: ".vpc", with: ""), "\(vpcDir)/\($0)") }
            .sorted { $0.0 < $1.0 }

        var used: Set<Character> = []
        for (name, path) in vpcFiles {
            if let key = assignKey(from: name, used: &used) {
                items[String(key)] = .action(title: name, command: "\(home)/dotfiles/bin/vpc.py '\(path)'")
            }
        }

        return .submenu(desc: "VPC Workspaces", items: items)
    }

    static func buildServicesMenu() -> CommandEntry {
        var items: [String: CommandEntry] = [:]

        let output = ShellExecutor.runSync("/usr/bin/env", args: ["launchctl", "list"])
        let lines = output.components(separatedBy: "\n").filter { $0.contains("org.pancia") }

        var services: [(name: String, running: Bool)] = []
        for line in lines {
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
            if parts.count >= 3 {
                let fullName = String(parts[2])
                if let svcName = fullName.components(separatedBy: "org.pancia.").last, !svcName.isEmpty {
                    let running = parts[0] != "-"
                    services.append((name: svcName, running: running))
                }
            }
        }

        services.sort { $0.name < $1.name }

        var used: Set<Character> = ["n"]
        for svc in services {
            if let key = assignKey(from: svc.name, used: &used) {
                let indicator = svc.running ? "\u{25CF}" : "\u{25CB}"
                let svcItems: [String: CommandEntry] = [
                    "s": .action(title: "Start", command: "service start \(svc.name)"),
                    "t": .action(title: "Stop", command: "service stop \(svc.name)"),
                    "r": .action(title: "Restart", command: "service restart \(svc.name)"),
                    "l": .action(title: "Log", command: "service log \(svc.name)"),
                    "e": .action(title: "Edit", command: "service edit \(svc.name)"),
                ]
                items[String(key)] = .submenu(desc: "\(svc.name) \(indicator)", items: svcItems)
            }
        }

        items["n"] = .action(title: "New Service", command: "service create")
        return .submenu(desc: "+services", items: items)
    }

    static func buildSnippetsMenu() -> CommandEntry {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let snippetsFile = "\(home)/ProtonDrive/_config/snippets.txt"
        var items: [String: CommandEntry] = [:]

        items["e"] = .action(title: "Edit Snippets", command: "nvim '\(snippetsFile)'")

        guard let content = try? String(contentsOfFile: snippetsFile, encoding: .utf8) else {
            return .submenu(desc: "+snippets", items: items)
        }

        struct Snippet {
            let title: String
            let content: String
            let trigger: String?
        }

        var snippets: [Snippet] = []
        var currentTitle: String?
        var currentContent = ""
        var currentTrigger: String?

        for line in content.components(separatedBy: "\n") {
            if let range = line.range(of: "^([^:]+):(.*)$", options: .regularExpression) {
                // Save previous snippet
                if let title = currentTitle {
                    snippets.append(Snippet(title: title, content: currentContent.trimmingCharacters(in: .whitespaces), trigger: currentTrigger))
                }

                let colonIdx = line.firstIndex(of: ":")!
                let rawTitle = String(line[line.startIndex..<colonIdx])
                currentContent = String(line[line.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)

                // Parse optional trigger: "My Snippet [;ms]"
                if let bracketRange = rawTitle.range(of: "\\[([^\\]]+)\\]\\s*$", options: .regularExpression) {
                    currentTrigger = String(rawTitle[bracketRange]).replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "").trimmingCharacters(in: .whitespaces)
                    currentTitle = String(rawTitle[rawTitle.startIndex..<bracketRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                } else {
                    currentTitle = rawTitle.trimmingCharacters(in: .whitespaces)
                    currentTrigger = nil
                }
            } else if currentTitle != nil && !line.isEmpty {
                currentContent += "\n" + line
            }
        }
        if let title = currentTitle {
            snippets.append(Snippet(title: title, content: currentContent.trimmingCharacters(in: .whitespaces), trigger: currentTrigger))
        }

        var used: Set<Character> = ["e"]
        for snippet in snippets {
            if let key = assignKey(from: snippet.title, used: &used) {
                let display = snippet.trigger != nil ? "\(snippet.title) [\(snippet.trigger!)]" : snippet.title
                let escaped = snippet.content.replacingOccurrences(of: "'", with: "'\\''")
                items[String(key)] = .action(
                    title: display,
                    command: "echo '\(escaped)' | pbcopy && echo 'Copied: \(snippet.title)'"
                )
            }
        }

        return .submenu(desc: "+snippets", items: items)
    }

    // MARK: - Helpers

    /// Assign a unique single-char key based on first available alphanumeric char in name
    static func assignKey(from name: String, used: inout Set<Character>) -> Character? {
        for char in name.lowercased() {
            if char.isLetter || char.isNumber, !used.contains(char) {
                used.insert(char)
                return char
            }
        }
        // Fallback to digits
        for i in 0...9 {
            let c = Character("\(i)")
            if !used.contains(c) {
                used.insert(c)
                return c
            }
        }
        return nil
    }

    /// Flatten command tree for search
    static func flattenCommands(_ menu: [String: CommandEntry], path: [String] = []) -> [FlatCommand] {
        var results: [FlatCommand] = []
        for (key, entry) in menu {
            switch entry {
            case .action(let title, let command):
                results.append(FlatCommand(key: key, label: title, command: command, path: path))
            case .submenu(let desc, let items):
                results.append(contentsOf: flattenCommands(items, path: path + [desc]))
            }
        }
        return results
    }
}
