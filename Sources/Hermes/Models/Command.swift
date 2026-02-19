import Foundation

/// Represents a command entry in the menu tree.
/// JSON format: key -> [title, command] for actions, key -> {_desc, ...} for submenus
enum CommandEntry {
    case action(title: String, command: String)
    case submenu(desc: String, items: [String: CommandEntry])

    var isSubmenu: Bool {
        if case .submenu = self { return true }
        return false
    }

    var title: String {
        switch self {
        case .action(let title, _): return title
        case .submenu(let desc, _): return desc
        }
    }
}

/// Flattened command for search
struct FlatCommand {
    let key: String
    let label: String
    let command: String
    let path: [String]
}
