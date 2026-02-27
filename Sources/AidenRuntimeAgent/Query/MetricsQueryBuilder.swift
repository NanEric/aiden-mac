import Foundation
import AidenShared

enum MetricsQueryBuilder {
    static func inputTokens(serviceName: String) -> String {
        "sum(gen_ai.client.token.usage_sum{gen_ai.token.type=\"input\",service.name=\"\(serviceName)\"})"
    }

    static func outputTokens(serviceName: String) -> String {
        "sum(gen_ai.client.token.usage_sum{gen_ai.token.type=\"output\",service.name=\"\(serviceName)\"})"
    }

    static func currentUser(serviceName: String) -> String {
        "topk(1,max by (user.email) (timestamp(gen_ai.client.token.usage_sum{service.name=\"\(serviceName)\",user.email!=\"\"})))"
    }
}
