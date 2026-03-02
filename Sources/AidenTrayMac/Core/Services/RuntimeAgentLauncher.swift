import Foundation
import Darwin

final class RuntimeAgentLauncher {
    private let label = "com.aiden.runtimeagent"

    func ensureStarted() -> String? {
        let uid = getuid()
        let domain = "gui/\(uid)"
        let plistPath = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
            .path

        guard FileManager.default.fileExists(atPath: plistPath) else {
            return "Runtime LaunchAgent plist not found: \(plistPath)"
        }

        // Safe to call repeatedly; bootstrap may fail if already loaded.
        _ = runLaunchctl(["bootstrap", domain, plistPath], allowFailure: true)

        let kickstart = runLaunchctl(["kickstart", "-k", "\(domain)/\(label)"], allowFailure: true)
        if kickstart.exitCode != 0 {
            return "Failed to start runtime agent: \(kickstart.output)"
        }

        return nil
    }

    private func runLaunchctl(_ arguments: [String], allowFailure: Bool) -> (exitCode: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !allowFailure && process.terminationStatus != 0 {
                return (process.terminationStatus, output.isEmpty ? "launchctl failed" : output)
            }
            return (process.terminationStatus, output)
        } catch {
            return (1, error.localizedDescription)
        }
    }
}
