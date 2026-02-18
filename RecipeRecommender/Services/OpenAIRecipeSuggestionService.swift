import Foundation

protocol RecipeSuggestionService {
    func suggestRecipe(
        recipes: [Recipe],
        availableIngredients: [Ingredient],
        stores: [Store]
    ) async throws -> RecipeSuggestion
}

enum OpenAIRecipeSuggestionError: LocalizedError {
    case missingAPIKey
    case httpError(statusCode: Int, body: String)
    case invalidResponse
    case recipeNotFound

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI APIキーが設定されていません"
        case .httpError(let code, let body):
            return "APIエラー(\(code)): \(body)"
        case .invalidResponse:
            return "APIレスポンスの解析に失敗しました"
        case .recipeNotFound:
            return "該当するレシピが見つかりませんでした"
        }
    }
}

struct OpenAIRecipeSuggestionService: RecipeSuggestionService {
    private let session: URLSession
    private let apiKeyProvider: () -> String?

    init(
        session: URLSession = .shared,
        apiKeyProvider: @escaping () -> String? = {
            if let plistKey = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String,
               !plistKey.isEmpty {
                return plistKey
            }
            return ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
        }
    ) {
        self.session = session
        self.apiKeyProvider = apiKeyProvider
    }

    func suggestRecipe(
        recipes: [Recipe],
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
                    content: "あなたは節約献立アシスタントです。必ず入力データのみを使い、最安で実現可能なレシピを1つ選び、JSONのみで返答してください。"
                ),
                .init(
                    role: "user",
                    content: userPrompt(recipes: recipes, availableIngredients: availableIngredients, stores: stores)
                )
            ],
            temperature: 0,
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
        let parsed = try JSONDecoder().decode(OpenAIRecipeDecision.self, from: resultData)

        guard let selectedRecipe = recipes.first(where: { $0.name == parsed.recipeName }) else {
            throw OpenAIRecipeSuggestionError.recipeNotFound
        }

        let selectedStore = stores.first(where: { $0.name == parsed.storeName })
        let missingIngredients = parsed.missingIngredients.map {
            MissingIngredient(
                name: $0.name,
                requiredQuantity: $0.requiredQuantity,
                currentQuantity: $0.currentQuantity,
                shortageQuantity: $0.shortageQuantity,
                unit: $0.unit
            )
        }

        return RecipeSuggestion(
            recipe: selectedRecipe,
            missingIngredients: missingIngredients,
            store: selectedStore,
            totalCost: parsed.totalCost,
            unavailableReason: parsed.unavailableReason
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

    private func userPrompt(recipes: [Recipe], availableIngredients: [Ingredient], stores: [Store]) -> String {
        let payload = OpenAIRecipePromptPayload(
            availableIngredients: availableIngredients,
            recipes: recipes,
            stores: stores,
            outputFormat: "{\"recipeName\": string, \"storeName\": string | null, \"totalCost\": number | null, \"unavailableReason\": string | null, \"missingIngredients\": [{\"name\": string, \"requiredQuantity\": number, \"currentQuantity\": number, \"shortageQuantity\": number, \"unit\": string}]}"
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = (try? encoder.encode(payload)) ?? Data()
        let json = String(decoding: data, as: UTF8.self)
        return "次のデータから、最安で実現可能なレシピを1つ選んでください。説明文は不要、JSONのみ返答してください。\n\n\(json)"
    }
}

private struct OpenAIRecipePromptPayload: Codable {
    var availableIngredients: [Ingredient]
    var recipes: [Recipe]
    var stores: [Store]
    var outputFormat: String
}

private struct OpenAIRecipeDecision: Codable {
    var recipeName: String
    var storeName: String?
    var totalCost: Double?
    var unavailableReason: String?
    var missingIngredients: [OpenAIMissingIngredient]
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
