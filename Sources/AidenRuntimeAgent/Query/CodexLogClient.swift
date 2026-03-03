import Foundation

struct CodexLogClient {
    struct UsageSample {
        let inputTokens: Double?
        let outputTokens: Double?
        let email: String
        let timestamp: Date
    }

    let logPath: URL
    private let maxTailBytes = 2_000_000
    private let iso8601 = ISO8601DateFormatter()

    init(logPath: URL) {
        self.logPath = logPath
        self.iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    func latestUsage() -> UsageSample? {
        guard let tailText = readTailText() else { return nil }
        let lines = tailText.split(separator: "\n", omittingEmptySubsequences: true)
        for line in lines.reversed() {
            guard let data = line.data(using: .utf8),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let resourceLogs = root["resourceLogs"] as? [[String: Any]] else {
                continue
            }

            if let sample = latestSample(from: resourceLogs) {
                return sample
            }
        }
        return nil
    }

    private func latestSample(from resourceLogs: [[String: Any]]) -> UsageSample? {
        for resourceLog in resourceLogs.reversed() {
            guard let scopeLogs = resourceLog["scopeLogs"] as? [[String: Any]] else { continue }
            for scopeLog in scopeLogs.reversed() {
                guard let logRecords = scopeLog["logRecords"] as? [[String: Any]] else { continue }
                for record in logRecords.reversed() {
                    let attrs = attributesMap(record["attributes"] as? [[String: Any]] ?? [])
                    guard attrs["event.kind"] == "response.completed" else { continue }

                    let input = parseDouble(attrs["input_token_count"])
                    let output = parseDouble(attrs["output_token_count"])
                    let email = attrs["user.email"]?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let observed = parseObservedTime(record["observedTimeUnixNano"] as? String)
                    let eventTs = parseEventTimestamp(attrs["event.timestamp"])
                    let timestamp = eventTs ?? observed ?? Date()

                    return UsageSample(
                        inputTokens: input,
                        outputTokens: output,
                        email: (email?.isEmpty == false ? email! : "Unknown"),
                        timestamp: timestamp
                    )
                }
            }
        }
        return nil
    }

    private func readTailText() -> String? {
        guard let handle = try? FileHandle(forReadingFrom: logPath) else { return nil }
        defer { try? handle.close() }

        guard let fileSize = try? handle.seekToEnd(),
              fileSize > 0 else {
            return nil
        }

        let readSize = min(fileSize, UInt64(maxTailBytes))
        let start = fileSize - readSize
        try? handle.seek(toOffset: start)

        guard let data = try? handle.read(upToCount: Int(readSize)),
              let text = String(data: data, encoding: .utf8) else {
            return nil
        }

        if start == 0 { return text }
        if let newlineIndex = text.firstIndex(of: "\n") {
            return String(text[text.index(after: newlineIndex)...])
        }
        return text
    }

    private func attributesMap(_ attributes: [[String: Any]]) -> [String: String] {
        var out: [String: String] = [:]
        for attr in attributes {
            guard let key = attr["key"] as? String,
                  let valueNode = attr["value"] as? [String: Any] else {
                continue
            }

            if let s = valueNode["stringValue"] as? String {
                out[key] = s
            } else if let i = valueNode["intValue"] as? Int {
                out[key] = String(i)
            } else if let i = valueNode["intValue"] as? String {
                out[key] = i
            } else if let d = valueNode["doubleValue"] as? Double {
                out[key] = String(d)
            } else if let b = valueNode["boolValue"] as? Bool {
                out[key] = b ? "true" : "false"
            }
        }
        return out
    }

    private func parseDouble(_ raw: String?) -> Double? {
        guard let raw else { return nil }
        return Double(raw)
    }

    private func parseEventTimestamp(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        return iso8601.date(from: raw)
    }

    private func parseObservedTime(_ raw: String?) -> Date? {
        guard let raw, let nanos = Double(raw) else { return nil }
        return Date(timeIntervalSince1970: nanos / 1_000_000_000.0)
    }
}
