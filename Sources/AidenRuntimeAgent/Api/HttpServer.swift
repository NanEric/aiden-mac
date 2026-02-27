import Foundation
import Network

final class HttpServer {
    typealias Handler = @Sendable (String, String, [String: String]) async -> (Int, Data)

    private let listener: NWListener
    private let handler: Handler

    init(host: String, port: UInt16, handler: @escaping Handler) throws {
        self.handler = handler
        let params = NWParameters.tcp
        listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        listener.service = nil
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection: connection)
        }
    }

    func start() {
        listener.start(queue: .global())
    }

    private func handle(connection: NWConnection) {
        connection.start(queue: .global())
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, _, _ in
            guard let self, let data, let request = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }

            let (method, path, query) = self.parse(request: request)
            Task {
                let (status, body) = await self.handler(method, path, query)
                let response = self.buildResponse(status: status, body: body)
                connection.send(content: response, completion: .contentProcessed { _ in
                    connection.cancel()
                })
            }
        }
    }

    private func parse(request: String) -> (String, String, [String: String]) {
        guard let firstLine = request.split(separator: "\n").first else {
            return ("GET", "/", [:])
        }
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else { return ("GET", "/", [:]) }

        let method = String(parts[0])
        let fullPath = String(parts[1])
        let pieces = fullPath.split(separator: "?", maxSplits: 1).map(String.init)
        let path = pieces.first ?? "/"
        var query: [String: String] = [:]
        if pieces.count > 1 {
            for item in pieces[1].split(separator: "&") {
                let kv = item.split(separator: "=", maxSplits: 1).map(String.init)
                if kv.count == 2 {
                    query[kv[0]] = kv[1].removingPercentEncoding ?? kv[1]
                }
            }
        }

        return (method, path, query)
    }

    private func buildResponse(status: Int, body: Data) -> Data {
        let text = "HTTP/1.1 \(status) OK\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        var data = Data(text.utf8)
        data.append(body)
        return data
    }
}
