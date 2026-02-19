import Foundation

/// Queries yabai for windows, focuses windows by ID
enum WindowManager {
    static func queryWindows(completion: @escaping ([WindowInfo]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let output = ShellExecutor.runSync("/opt/homebrew/bin/yabai", args: ["-m", "query", "--windows"])

            guard let data = output.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                DispatchQueue.main.async { completion([]) }
                return
            }

            var windows: [WindowInfo] = []
            for win in json {
                let isVisible = win["is-visible"] as? Bool ?? false
                let isMinimized = win["is-minimized"] as? Bool ?? false
                let title = win["title"] as? String ?? ""

                guard (isVisible || !isMinimized), !title.isEmpty else { continue }

                let id = win["id"] as? Int ?? 0
                let app = win["app"] as? String ?? ""
                let space = win["space"] as? Int ?? 0

                windows.append(WindowInfo(id: id, title: title, app: app, space: space))
            }

            DispatchQueue.main.async { completion(windows) }
        }
    }

    static func focusWindow(id: Int) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Small delay for reliable focus (matching Lua version)
            usleep(50_000)
            _ = ShellExecutor.runSync("/opt/homebrew/bin/yabai", args: ["-m", "window", "--focus", "\(id)"])
        }
    }
}
