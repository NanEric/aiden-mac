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

    static func latestActivityTime(serviceName: String, userEmail: String, lookbackDays: Int = 365) -> String {
        let escapedEmail = userEmail
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "max_over_time(timestamp(gen_ai_client_token_usage_sum{job=\"\(serviceName)\",user_email=\"\(escapedEmail)\"})[\(lookbackDays)d:1h])"
    }

    static func earliestActivityTime(serviceName: String, userEmail: String, lookbackDays: Int = 365) -> String {
        let escapedEmail = userEmail
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        // Use 1h step for better accuracy to capture the true earliest record
        return "min_over_time(timestamp(gen_ai_client_token_usage_sum{job=\"\(serviceName)\",user_email=\"\(escapedEmail)\"})[\(lookbackDays)d:1h])"
    }
}
