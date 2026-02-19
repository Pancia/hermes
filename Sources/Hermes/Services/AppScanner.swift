import AppKit

/// Scans /Applications dirs, extracts icons, caches results
enum AppScanner {
    static let iconCacheDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".cache/app-icons").path
    static let appCacheFile = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".cache/hermes/apps.json").path
    static let appDirs = [
        "/Applications",
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path,
        "/System/Applications",
        "/System/Library/CoreServices/Applications",
    ]

    /// Load apps — returns cached immediately, refreshes recency in background
    static func loadApps(completion: @escaping ([AppInfo]) -> Void) {
        // Try cache first
        if let cached = loadCache() {
            completion(cached)
            // Refresh recency in background
            refreshRecency(cached) { updated in
                DispatchQueue.main.async { completion(updated) }
            }
            return
        }

        // Full scan
        DispatchQueue.global(qos: .userInitiated).async {
            let apps = scanApps()
            DispatchQueue.main.async { completion(apps) }

            refreshRecency(apps) { updated in
                DispatchQueue.main.async { completion(updated) }
            }
        }
    }

    static func scanApps() -> [AppInfo] {
        let fm = FileManager.default
        var apps: [AppInfo] = []
        var seen: Set<String> = []

        for dir in appDirs {
            guard let contents = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for file in contents where file.hasSuffix(".app") {
                let name = file.replacingOccurrences(of: ".app", with: "")
                guard !seen.contains(name) else { continue }
                seen.insert(name)
                let path = "\(dir)/\(file)"
                let iconPath = getIconPath(name)
                apps.append(AppInfo(name: name, path: path, icon: iconPath, lastUsed: nil))
            }
        }

        apps.sort { $0.name.lowercased() < $1.name.lowercased() }
        return apps
    }

    static func getIconPath(_ appName: String) -> String {
        let safeName = appName.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: " ", with: "_")
        return "\(iconCacheDir)/\(safeName).png"
    }

    /// Extract icon from app bundle to cache (async)
    static func extractIcon(appPath: String, appName: String, completion: ((String?) -> Void)? = nil) {
        let iconPath = getIconPath(appName)
        let fm = FileManager.default

        // Already cached
        if fm.fileExists(atPath: iconPath) {
            completion?(iconPath)
            return
        }

        DispatchQueue.global(qos: .utility).async {
            // Find .icns file
            let resourcesDir = "\(appPath)/Contents/Resources"
            guard let files = try? fm.contentsOfDirectory(atPath: resourcesDir) else {
                completion?(nil)
                return
            }

            guard let icnsFile = files.first(where: { $0.hasSuffix(".icns") }) else {
                completion?(nil)
                return
            }

            let icnsPath = "\(resourcesDir)/\(icnsFile)"

            // Ensure cache dir exists
            try? fm.createDirectory(atPath: iconCacheDir, withIntermediateDirectories: true)

            // Extract with sips
            let output = ShellExecutor.runSync("/usr/bin/sips", args: [
                "-s", "format", "png",
                "-z", "96", "96",
                icnsPath, "--out", iconPath
            ])

            DispatchQueue.main.async {
                completion?(fm.fileExists(atPath: iconPath) ? iconPath : nil)
            }
        }
    }

    /// Load icon as NSImage
    static func loadIcon(for app: AppInfo) -> NSImage? {
        guard let iconPath = app.icon else { return nil }
        if FileManager.default.fileExists(atPath: iconPath) {
            return NSImage(contentsOfFile: iconPath)
        }
        // Try NSWorkspace icon
        return NSWorkspace.shared.icon(forFile: app.path)
    }

    // MARK: - Cache

    static func loadCache() -> [AppInfo]? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: appCacheFile)),
              let apps = try? JSONDecoder().decode([AppInfo].self, from: data) else {
            return nil
        }
        return apps
    }

    static func saveCache(_ apps: [AppInfo]) {
        let cacheDir = (appCacheFile as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: cacheDir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(apps) {
            try? data.write(to: URL(fileURLWithPath: appCacheFile))
        }
    }

    static func refreshRecency(_ apps: [AppInfo], completion: @escaping ([AppInfo]) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            var updated = apps
            let group = DispatchGroup()

            for i in updated.indices {
                group.enter()
                queryLastUsed(path: updated[i].path) { timestamp in
                    updated[i].lastUsed = timestamp
                    group.leave()
                }
            }

            group.wait()

            // Sort by recency
            updated.sort { a, b in
                if let la = a.lastUsed, let lb = b.lastUsed { return la > lb }
                if a.lastUsed != nil { return true }
                if b.lastUsed != nil { return false }
                return a.name.lowercased() < b.name.lowercased()
            }

            saveCache(updated)
            completion(updated)
        }
    }

    static func queryLastUsed(path: String, completion: @escaping (Double?) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            let output = ShellExecutor.runSync("/usr/bin/mdls", args: ["-name", "kMDItemLastUsedDate", path])
            if output.contains("(null)") {
                completion(nil)
                return
            }
            // Parse "kMDItemLastUsedDate = 2024-01-15 10:30:00 +0000"
            if let range = output.range(of: "\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}", options: .regularExpression) {
                let dateStr = String(output[range])
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                formatter.timeZone = TimeZone(identifier: "UTC")
                if let date = formatter.date(from: dateStr) {
                    completion(date.timeIntervalSince1970)
                    return
                }
            }
            completion(nil)
        }
    }
}
