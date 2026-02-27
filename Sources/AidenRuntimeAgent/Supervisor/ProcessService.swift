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
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            self.process = process
            lastError = nil
        } catch {
            lastError = error.localizedDescription
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
