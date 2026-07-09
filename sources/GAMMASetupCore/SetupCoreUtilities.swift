import Foundation

public enum SetupPathTools {
    public static func appendWords(_ value: String) -> [String] {
        value
            .replacingOccurrences(of: ",", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
    }

    public static func pathIsUnder(_ child: String, parent: String) -> Bool {
        if parent == "/" {
            return child.hasPrefix("/")
        }
        return child == parent || child.hasPrefix(parent + "/")
    }

    public static func commonParent(_ first: String, _ second: String) -> String {
        let a = first.split(separator: "/").map(String.init)
        let b = second.split(separator: "/").map(String.init)
        var parts: [String] = []
        for (left, right) in zip(a, b) {
            guard left == right else { break }
            parts.append(left)
        }
        return parts.isEmpty ? "/" : "/" + parts.joined(separator: "/")
    }

    public static func decodeModOrganizerIniValue(_ value: String) -> String {
        var value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\r"))
        if value.hasPrefix("@ByteArray("), value.hasSuffix(")") {
            value = String(value.dropFirst("@ByteArray(".count).dropLast())
        }
        if value.hasPrefix("\"") {
            value.removeFirst()
        }
        if value.hasSuffix("\"") {
            value.removeLast()
        }
        return value
    }

    public static func windowsPathDrive(_ path: String) -> String {
        let normalized = path.replacingOccurrences(of: #"\\\\"#, with: #"\"#)
        guard normalized.count >= 3,
              normalized[normalized.index(after: normalized.startIndex)] == ":",
              normalized[normalized.index(normalized.startIndex, offsetBy: 2)] == "\\" || normalized[normalized.index(normalized.startIndex, offsetBy: 2)] == "/" else {
            return ""
        }
        return String(normalized.prefix(1)).lowercased()
    }

    public static func windowsPathRelative(_ path: String) -> String {
        var normalized = path.replacingOccurrences(of: #"\\\\"#, with: #"\"#)
        guard normalized.count >= 3, normalized[normalized.index(after: normalized.startIndex)] == ":" else {
            return ""
        }
        normalized = String(normalized.dropFirst(2))
        normalized = normalized.trimmingCharacters(in: CharacterSet(charactersIn: "\\/"))
        return normalized.replacingOccurrences(of: "\\", with: "/")
    }

    public static func nativeToWindowsPath(_ native: String, driveRoot: String, driveLetter: String) throws -> String {
        guard pathIsUnder(native, parent: driveRoot) else {
            throw SetupEngineError.message("cannot convert native path to Wine path under mounted root \(driveRoot): \(native)")
        }
        let relative = driveRoot == "/"
            ? native.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            : String(native.dropFirst(driveRoot.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return "\(driveLetter.uppercased()):/\(relative)"
    }

    public static func windowsDirectoryPath(_ path: String) -> String {
        let normalized = path.replacingOccurrences(of: "\\", with: "/")
        guard let separator = normalized.lastIndex(of: "/") else {
            return normalized
        }
        let directory = String(normalized[..<separator])
        if directory.count == 2, directory.hasSuffix(":") {
            return directory + "/"
        }
        return directory
    }
}

public enum WinetricksTools {
    public static func listedVerbs(_ output: String) -> Set<String> {
        Set(output.split(whereSeparator: \.isNewline).compactMap { line in
            line.split(whereSeparator: \.isWhitespace).first.map(String.init)
        })
    }

    public static func supports(_ requiredVerbs: [String], listOutput: String) -> Bool {
        let available = listedVerbs(listOutput)
        return requiredVerbs.allSatisfy(available.contains)
    }

    public static func missingVerbs(_ requiredVerbs: [String], installedOutput: String) -> [String] {
        let installed = listedVerbs(installedOutput)
        return requiredVerbs.filter { !installed.contains($0) }
    }
}

public enum SetupLaunchBatchTools {
    public static func modOrganizerCommandLines(executableWindowsPath: String) -> [String] {
        let workingDirectory = SetupPathTools.windowsDirectoryPath(executableWindowsPath)
        return [
            "@echo off",
            #"set "QT_OPENGL=software""#,
            #"set "QT_QUICK_BACKEND=software""#,
            #"set "QTWEBENGINE_CHROMIUM_FLAGS=--disable-gpu""#,
            "",
            #"cd /d "\#(workingDirectory.replacingOccurrences(of: "/", with: "\\"))""#,
            #"start "" "\#(executableWindowsPath.replacingOccurrences(of: "/", with: "\\"))""#
        ]
    }

    public static func isDefaultModOrganizerBatch(_ text: String) -> Bool {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard lines.count == 6 else { return false }
        return lines[0].caseInsensitiveCompare("@echo off") == .orderedSame
            && lines[1].caseInsensitiveCompare(#"set "QT_OPENGL=software""#) == .orderedSame
            && lines[2].caseInsensitiveCompare(#"set "QT_QUICK_BACKEND=software""#) == .orderedSame
            && lines[3].caseInsensitiveCompare(#"set "QTWEBENGINE_CHROMIUM_FLAGS=--disable-gpu""#) == .orderedSame
            && lines[4].range(of: "cd /d ", options: [.caseInsensitive, .anchored]) != nil
            && lines[5].range(of: #"start "" "#, options: [.caseInsensitive, .anchored]) != nil
            && lines[5].localizedCaseInsensitiveContains(#"\ModOrganizer.exe""#)
    }

    public static func commandLines(
        executableWindowsPath: String,
        workingDirectoryWindowsPath: String,
        usesModOrganizerEnvironment: Bool
    ) -> [String] {
        var lines = ["@echo off"]
        if usesModOrganizerEnvironment {
            lines += [
                #"set "QT_OPENGL=software""#,
                #"set "QT_QUICK_BACKEND=software""#,
                #"set "QTWEBENGINE_CHROMIUM_FLAGS=--disable-gpu""#
            ]
            lines.append("")
        }
        lines.append(#"start "" /D "\#(workingDirectoryWindowsPath)" "\#(executableWindowsPath)""#)
        return lines
    }
}

public enum SetupTextEditor {
    public static func ensureSectionKeyValues(text: String, section: String, entries: [String: String]) -> String {
        var lines = text.components(separatedBy: .newlines)
        editSection(lines: &lines, section: section) { body in
            var seen: Set<String> = []
            var output: [String] = []
            for line in body {
                if let key = quotedRegistryKey(line), let value = entries[key] {
                    output.append("\"\(key)\"=\"\(value)\"")
                    seen.insert(key)
                } else {
                    output.append(line)
                }
            }
            for key in entries.keys.sorted() where !seen.contains(key) {
                output.append("\"\(key)\"=\"\(entries[key]!)\"")
            }
            return output
        }
        return lines.joined(separator: "\n")
    }

    public static func ensureSectionRawLines(text: String, section: String, lines desiredLines: [String]) -> String {
        var lines = text.components(separatedBy: .newlines)
        let desired = Dictionary(uniqueKeysWithValues: desiredLines.map { (rawLineKey($0), $0) })
        editSection(lines: &lines, section: section) { body in
            var seen: Set<String> = []
            var output: [String] = []
            for line in body {
                let key = rawLineKey(line)
                if let replacement = desired[key] {
                    output.append(replacement)
                    seen.insert(key)
                } else {
                    output.append(line)
                }
            }
            for key in desired.keys.sorted() where !seen.contains(key) {
                output.append(desired[key]!)
            }
            return output
        }
        return lines.joined(separator: "\n")
    }

    private static func editSection(lines: inout [String], section: String, bodyEdit: ([String]) -> [String]) {
        var start: Int?
        var end = lines.count
        for index in lines.indices {
            if sectionName(lines[index]) == section {
                start = index
                continue
            }
            if let start, index > start, sectionName(lines[index]) != nil {
                end = index
                break
            }
        }
        if let start {
            let body = Array(lines[(start + 1)..<end])
            lines.replaceSubrange((start + 1)..<end, with: bodyEdit(body))
        } else {
            if lines.last?.isEmpty == false {
                lines.append("")
            }
            lines.append("[\(section)]")
            lines.append(contentsOf: bodyEdit([]))
        }
    }

    private static func quotedRegistryKey(_ line: String) -> String? {
        guard line.hasPrefix("\""), let end = line.dropFirst().firstIndex(of: "\"") else {
            return nil
        }
        return String(line[line.index(after: line.startIndex)..<end])
    }

    private static func rawLineKey(_ line: String) -> String {
        String(line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false).first ?? "")
    }

    private static func sectionName(_ line: String) -> String? {
        guard line.hasPrefix("["),
              let end = line.firstIndex(of: "]") else {
            return nil
        }
        return String(line[line.index(after: line.startIndex)..<end])
    }
}
