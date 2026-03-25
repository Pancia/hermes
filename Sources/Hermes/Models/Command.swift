import Foundation

/// How to execute a command
enum ExecutionMode {
    case background    // run silently, discard output
    case shell         // open terminal, exit when done
    case interactive   // open terminal, drop into shell after
}

struct CommandSpec {
    let cmd: String
    let mode: ExecutionMode

    init(_ cmd: String, mode: ExecutionMode = .background) {
        self.cmd = cmd
        self.mode = mode
    }
}

/// How to resolve a dynamic title
struct DynamicTitle {
    let shell: String  // "fish", "bash", etc.
    let cmd: String
}

/// Represents a command entry in the menu tree.
/// JSON format: key -> [title, command] for actions, key -> {_desc, ...} for submenus
///
/// Title can be a string or object:  "calendar"  or  {"shell:fish": "some-cmd"}
/// Command can be a string or object:
///   "echo hi"                    — background (default)
///   {"shell": "vim foo"}         — terminal, exits when done
///   {"interactive": "agenda 24"} — terminal, drops into interactive shell after
enum CommandEntry {
    case action(title: String, command: CommandSpec, dynamicTitle: DynamicTitle? = nil)
    case submenu(desc: String, items: [String: CommandEntry], stayOpen: Bool = false)

    var isSubmenu: Bool {
        if case .submenu = self { return true }
        return false
    }

    var title: String {
        switch self {
        case .action(let title, _, _): return title
        case .submenu(let desc, _, _): return desc
        }
    }
}

/// Flattened command for search
struct FlatCommand {
    let key: String
    let label: String
    let command: CommandSpec
    let path: [String]
    let keyPath: [String]
}
