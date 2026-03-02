import Foundation
import AidenShared

enum MetricsQueryBuilder {
    static func inputTokens(serviceName: String) -> String {
        "sum(gen_ai_client_token_usage_sum{gen_ai_token_type=\"input\",job=\"\(serviceName)\"})"
    }

    static func outputTokens(serviceName: String) -> String {
        "sum(gen_ai_client_token_usage_sum{gen_ai_token_type=\"output\",job=\"\(serviceName)\"})"
    }

    static func currentUser(serviceName: String) -> String {
        "topk(1,max by (user_email) (timestamp(gen_ai_client_token_usage_sum{job=\"\(serviceName)\",user_email!=\"\"})))"
    }
}
