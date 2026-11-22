//
//  AzureTranslator.swift
//  simpfun
//

import Foundation

/// Azure AI Translator（微软翻译）的最小封装。
///
/// 只做「一批文本 → 一批译文」，密钥与区域由界面传进来，
/// token 到位后填进「翻译模式 › 翻译设置」即可使用。
enum AzureTranslator {
    struct Configuration {
        var endpoint: String
        var region: String
        var key: String

        var isUsable: Bool {
            !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    enum TranslationError: LocalizedError {
        case missingKey
        case server(String)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .missingKey:
                return "尚未配置 Azure 翻译密钥。"
            case .server(let message):
                return message
            case .invalidResponse:
                return "翻译服务返回了无法识别的内容。"
            }
        }
    }

    /// 一次请求最多 40 行，避免撞上服务端的长度限制。
    static let maximumLinesPerRequest = 40
    static let maximumCharactersPerRequest = 4000

    static func translate(_ texts: [String], configuration: Configuration) async throws -> [String] {
        guard configuration.isUsable else { throw TranslationError.missingKey }
        guard !texts.isEmpty else { return [] }

        let trimmedEndpoint = configuration.endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmedEndpoint.isEmpty ? "https://api.cognitive.microsofttranslator.com" : trimmedEndpoint
        guard var components = URLComponents(string: base.hasSuffix("/") ? base + "translate" : base + "/translate") else {
            throw TranslationError.server("翻译服务地址无效。")
        }
        components.queryItems = [
            URLQueryItem(name: "api-version", value: "3.0"),
            URLQueryItem(name: "to", value: "zh-Hans")
        ]
        guard let url = components.url else {
            throw TranslationError.server("翻译服务地址无效。")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.key, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        let region = configuration.region.trimmingCharacters(in: .whitespacesAndNewlines)
        if !region.isEmpty {
            request.setValue(region, forHTTPHeaderField: "Ocp-Apim-Subscription-Region")
        }

        let payload = texts.map { ["Text": $0] }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw TranslationError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            if let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: data) {
                throw TranslationError.server("翻译失败：\(envelope.error.message)")
            }
            throw TranslationError.server("翻译失败：HTTP \(http.statusCode)")
        }

        guard let decoded = try? JSONDecoder().decode([Response].self, from: data),
              decoded.count == texts.count else {
            throw TranslationError.invalidResponse
        }
        return decoded.map { $0.translations.first?.text ?? "" }
    }

    private struct Response: Decodable {
        struct Translation: Decodable {
            let text: String
            let to: String?
        }
        let translations: [Translation]
    }

    private struct ErrorEnvelope: Decodable {
        struct Payload: Decodable {
            let code: Int?
            let message: String
        }
        let error: Payload
    }
}
