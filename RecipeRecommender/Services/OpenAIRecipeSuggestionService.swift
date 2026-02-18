import Foundation

protocol RecipeSuggestionService {
    func suggestRecipe(
        availableIngredients: [Ingredient],
        stores: [Store]
    ) async throws -> RecipeSuggestion
}

enum OpenAIRecipeSuggestionError: LocalizedError {
    case missingAPIKey
    case httpError(statusCode: Int, body: String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI APIキーが設定されていません"
        case .httpError(let code, let body):
            return "APIエラー(\(code)): \(body)"
        case .invalidResponse:
            return "APIレスポンスの解析に失敗しました"
        }
    }
}

struct OpenAIRecipeSuggestionService: RecipeSuggestionService {
    private let session: URLSession
    private let apiKeyProvider: () -> String?

    init(
        session: URLSession = .shared,
        apiKeyProvider: @escaping () -> String? = {
            // 1. Xcode Scheme 環境変数（Edit Scheme > Run > Environment Variables）
            if let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"],
               !envKey.isEmpty {
                return envKey
            }
            // 2. Info.plist（xcconfig の INFOPLIST_KEY_ 経由）
            if let plistKey = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String,
               !plistKey.isEmpty,
               !plistKey.hasPrefix("sk-placeholder") {
                return plistKey
            }
            return nil
        }
    ) {
        self.session = session
        self.apiKeyProvider = apiKeyProvider
    }

    func suggestRecipe(
        availableIngredients: [Ingredient],
        stores: [Store]
    ) async throws -> RecipeSuggestion {
        guard let apiKey = apiKeyProvider(), !apiKey.isEmpty else {
            throw OpenAIRecipeSuggestionError.missingAPIKey
        }

        let requestBody = ChatCompletionRequest(
            model: "gpt-4.1-mini",
            messages: [
                .init(
                    role: "system",
                    content: "あなたは節約献立アシスタントです。ユーザーの手持ち食材を基に、簡単で美味しいレシピを1つ考案してください。手持ち食材をできるだけ活用し、追加購入が最小限になるレシピを提案してください。JSONのみで返答してください。"
                ),
                .init(
                    role: "user",
                    content: userPrompt(availableIngredients: availableIngredients, stores: stores)
                )
            ],
            temperature: 0.7,
            response_format: ResponseFormat(type: "json_object")
        )

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIRecipeSuggestionError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(decoding: data, as: UTF8.self)
            throw OpenAIRecipeSuggestionError.httpError(
                statusCode: httpResponse.statusCode, body: body
            )
        }

        let completion = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let rawContent = completion.choices.first?.message.content else {
            throw OpenAIRecipeSuggestionError.invalidResponse
        }

        let cleanedContent = sanitizeJSON(rawContent)
        let resultData = Data(cleanedContent.utf8)
        let parsed = try JSONDecoder().decode(OpenAIGeneratedRecipe.self, from: resultData)

        let recipe = Recipe(
            name: parsed.recipeName,
            ingredients: parsed.ingredients.map {
                IngredientRequirement(name: $0.name, quantityNeeded: $0.quantityNeeded, unit: $0.unit)
            },
            steps: parsed.steps,
            baseCost: parsed.estimatedCost ?? 0
        )

        let missingIngredients = parsed.missingIngredients.map {
            MissingIngredient(
                name: $0.name,
                requiredQuantity: $0.requiredQuantity,
                currentQuantity: $0.currentQuantity,
                shortageQuantity: $0.shortageQuantity,
                unit: $0.unit
            )
        }

        let selectedStore = stores.first(where: { $0.name == parsed.storeName })

        return RecipeSuggestion(
            recipe: recipe,
            missingIngredients: missingIngredients,
            store: selectedStore,
            totalCost: parsed.estimatedCost,
            unavailableReason: nil
        )
    }

    private func sanitizeJSON(_ content: String) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```") else { return trimmed }

        return trimmed
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func userPrompt(availableIngredients: [Ingredient], stores: [Store]) -> String {
        let payload = OpenAIRecipePromptPayload(
            availableIngredients: availableIngredients,
            stores: stores,
            outputFormat: """
            {
              "recipeName": "レシピ名",
              "steps": ["手順1", "手順2", ...],
              "ingredients": [{"name": "食材名", "quantityNeeded": 数量, "unit": "単位"}],
              "missingIngredients": [{"name": "食材名", "requiredQuantity": 必要量, "currentQuantity": 手持ち量, "shortageQuantity": 不足量, "unit": "単位"}],
              "storeName": "最安の店舗名 or null",
              "estimatedCost": 概算費用(円)
            }
            """
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = (try? encoder.encode(payload)) ?? Data()
        let json = String(decoding: data, as: UTF8.self)
        return "次の手持ち食材と店舗情報を基に、簡単で節約できるレシピを1つ考案してください。手持ち食材をなるべく活用し、不足食材は最安の店舗で補えるようにしてください。説明文は不要、JSONのみ返答してください。\n\n\(json)"
    }
}

private struct OpenAIRecipePromptPayload: Codable {
    var availableIngredients: [Ingredient]
    var stores: [Store]
    var outputFormat: String
}

private struct OpenAIGeneratedRecipe: Codable {
    var recipeName: String
    var steps: [String]
    var ingredients: [OpenAIIngredient]
    var missingIngredients: [OpenAIMissingIngredient]
    var storeName: String?
    var estimatedCost: Double?
}

private struct OpenAIIngredient: Codable {
    var name: String
    var quantityNeeded: Double
    var unit: String
}

private struct OpenAIMissingIngredient: Codable {
    var name: String
    var requiredQuantity: Double
    var currentQuantity: Double
    var shortageQuantity: Double
    var unit: String
}

private struct ChatCompletionRequest: Codable {
    var model: String
    var messages: [ChatMessage]
    var temperature: Double
    var response_format: ResponseFormat?
}

private struct ResponseFormat: Codable {
    var type: String
}

private struct ChatMessage: Codable {
    var role: String
    var content: String
}

private struct ChatCompletionResponse: Codable {
    var choices: [Choice]

    struct Choice: Codable {
        var message: ChatMessage
    }
}
