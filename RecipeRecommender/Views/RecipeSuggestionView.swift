import SwiftUI

struct RecipeSuggestionView: View {
    let suggestion: RecipeSuggestion
    let ingredients: [Ingredient]
    let errorMessage: String?
    let onReset: () -> Void

    var body: some View {
        List {
            ingredientsSection
            recipeSection
            stepsSection
            missingIngredientsSection
            costSection

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.footnote)
                }
            }

            Section {
                Button {
                    onReset()
                } label: {
                    Label("材料入力に戻る", systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.secondary)
            }
            .listRowBackground(Color.clear)
        }
        .navigationTitle("レシピ提案")
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - 入力済み材料

    private var ingredientsSection: some View {
        Section(header: Text("入力した食材")) {
            ForEach(ingredients) { ingredient in
                HStack {
                    Text(ingredient.name)
                    Spacer()
                    Text("\(ingredient.quantity.clean) \(ingredient.unit)")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - レシピ概要

    private var recipeSection: some View {
        Section(header: Text("提案レシピ")) {
            Text(suggestion.recipe.name)
                .font(.title3)
                .bold()
        }
    }

    // MARK: - 作り方

    private var stepsSection: some View {
        Section(header: Text("作り方")) {
            ForEach(Array(suggestion.recipe.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top) {
                    Text("\(index + 1).")
                        .bold()
                        .foregroundColor(.secondary)
                    Text(step)
                }
            }
        }
    }

    // MARK: - 不足食材

    private var missingIngredientsSection: some View {
        Section(header: Text("不足食材")) {
            if suggestion.missingIngredients.isEmpty {
                Label("追加購入なしで作れます！", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                ForEach(suggestion.missingIngredients) { ingredient in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ingredient.name)
                            .font(.headline)
                        Text("必要 \(ingredient.requiredQuantity.clean) \(ingredient.unit) / 保有 \(ingredient.currentQuantity.clean) \(ingredient.unit) / 不足 \(ingredient.shortageQuantity.clean) \(ingredient.unit)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let store = suggestion.store {
                    HStack {
                        Image(systemName: "cart.fill")
                        Text("購入先：\(store.name)（徒歩約\(store.distanceMinutes)分）")
                    }
                }
            }

            if let reason = suggestion.unavailableReason {
                Label(reason, systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
            }
        }
    }

    // MARK: - 合計想定額

    private var costSection: some View {
        Section(header: Text("合計想定額")) {
            if let totalCost = suggestion.totalCost {
                Text("¥\(Int(totalCost))")
                    .font(.title2)
                    .bold()
            } else {
                Text("算出不可")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.secondary)
            }
        }
    }
}
