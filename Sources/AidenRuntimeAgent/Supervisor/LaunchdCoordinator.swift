import Foundation

struct LaunchdCoordinator {
    func restart(label: String = "com.aiden.runtimeagent") {
        let uid = String(getuid())
        _ = run("/bin/launchctl", ["kickstart", "-k", "gui/\(uid)/\(label)"])
    }

    private func run(_ bin: String, _ args: [String]) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: bin)
        p.arguments = args
        do {
            try p.run()
            p.waitUntilExit()
            return p.terminationStatus
        } catch {
            return -1
        }
    }
}
