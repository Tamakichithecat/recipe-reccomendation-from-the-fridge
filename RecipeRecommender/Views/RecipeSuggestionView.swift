import SwiftUI

struct RecipeSuggestionView: View {
    let suggestion: RecipeSuggestion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            Text("提案レシピ")
                .font(.title2)
                .bold()
            Text(suggestion.recipe.name)
                .font(.title3)

            Text("作り方")
                .font(.headline)
            ForEach(Array(suggestion.recipe.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top) {
                    Text("\(index + 1).")
                        .bold()
                    Text(step)
                }
            }

            if suggestion.missingIngredients.isEmpty {
                Label("追加購入なしで作れます！", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("不足食材")
                        .font(.headline)
                    ForEach(suggestion.missingIngredients) { ingredient in
                        Text("\(ingredient.name)：必要 \(ingredient.requiredQuantity.clean) \(ingredient.unit) / 保有 \(ingredient.currentQuantity.clean) \(ingredient.unit) / 不足 \(ingredient.shortageQuantity.clean) \(ingredient.unit)")
                    }

                    if let store = suggestion.store {
                        HStack {
                            Image(systemName: "cart.fill")
                            Text("購入先：\(store.name)（徒歩約\(store.distanceMinutes)分）")
                        }
                        .padding(.top, 8)
                    }
                }
            }

            if let reason = suggestion.unavailableReason {
                Label(reason, systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
            }

            if let totalCost = suggestion.totalCost {
                Text("合計想定額：¥\(Int(totalCost))")
                    .font(.title3)
                    .bold()
                    .padding(.top, 8)
            } else {
                Text("合計想定額：算出不可")
                    .font(.title3)
                    .bold()
                    .padding(.top, 8)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding([.horizontal, .bottom])
    }
}
