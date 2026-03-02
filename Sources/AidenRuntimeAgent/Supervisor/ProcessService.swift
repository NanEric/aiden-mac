import Foundation

final class ProcessService {
    private var process: Process?
    private let executable: URL
    private let arguments: [String]
    private(set) var lastError: String?

    init(executable: URL, arguments: [String]) {
        self.executable = executable
        self.arguments = arguments
    }

    func startIfNeeded() {
        guard process?.isRunning != true else { return }
        guard FileManager.default.isExecutableFile(atPath: executable.path) else {
            lastError = "Not executable: \(executable.path)"
            return
        }

        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.terminationHandler = { [weak self, weak stderrPipe] terminated in
            let stderrData = stderrPipe?.fileHandleForReading.readDataToEndOfFile() ?? Data()
            let stderrText = String(data: stderrData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if terminated.terminationStatus != 0 {
                self?.lastError = "Process exited (\(terminated.terminationStatus)): \(self?.executable.path ?? "unknown") \(self?.arguments.joined(separator: " ") ?? ""). \(stderrText)"
            }
        }
        do {
            try process.run()
            self.process = process
            lastError = nil
        } catch {
            let renderedArgs = arguments.joined(separator: " ")
            lastError = "Failed to start \(executable.path) \(renderedArgs): \(error.localizedDescription)"
        }
    }

    func stop() {
        guard let process else { return }
        if process.isRunning {
            process.terminate()
        }
        self.process = nil
    }

    func restart() {
        stop()
        startIfNeeded()
    }

    var isRunning: Bool {
        process?.isRunning == true
    }
}
