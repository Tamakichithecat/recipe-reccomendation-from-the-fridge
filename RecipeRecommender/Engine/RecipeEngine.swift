import Foundation

enum RecipeEngine {
    static func suggestRecipe(recipes: [Recipe], availableIngredients: [Ingredient], stores: [Store]) -> RecipeSuggestion? {
        let evaluations = recipes.map { evaluate(recipe: $0, availableIngredients: availableIngredients, stores: stores) }

        let purchasable = evaluations
            .filter { $0.isPurchasable }
            .sorted { lhs, rhs in
                let lhsCost = lhs.totalCost ?? .infinity
                let rhsCost = rhs.totalCost ?? .infinity

                if lhsCost == rhsCost {
                    let lhsDistance = lhs.store?.distanceMinutes ?? 0
                    let rhsDistance = rhs.store?.distanceMinutes ?? 0
                    return lhsDistance < rhsDistance
                }

                return lhsCost < rhsCost
            }

        if let best = purchasable.first {
            return RecipeSuggestion(
                recipe: best.recipe,
                missingIngredients: best.missingIngredients,
                store: best.store,
                totalCost: best.totalCost,
                unavailableReason: nil
            )
        }

        guard let fallback = evaluations.first else { return nil }
        return RecipeSuggestion(
            recipe: fallback.recipe,
            missingIngredients: fallback.missingIngredients,
            store: nil,
            totalCost: nil,
            unavailableReason: "不足食材をすべて購入できる店舗が見つかりません。"
        )
    }

    private static func evaluate(recipe: Recipe, availableIngredients: [Ingredient], stores: [Store]) -> RecipeEvaluation {
        let missing = missingIngredients(for: recipe, availableIngredients: availableIngredients)

        if missing.isEmpty {
            return RecipeEvaluation(
                recipe: recipe,
                missingIngredients: [],
                store: nil,
                totalCost: recipe.baseCost,
                unavailableReason: nil
            )
        }

        let (store, missingCost) = findCheapestStore(missingIngredients: missing, stores: stores)

        guard let selectedStore = store, let purchaseCost = missingCost else {
            return RecipeEvaluation(
                recipe: recipe,
                missingIngredients: missing,
                store: nil,
                totalCost: nil,
                unavailableReason: "不足食材をすべて購入できる店舗が見つかりません。"
            )
        }

        return RecipeEvaluation(
            recipe: recipe,
            missingIngredients: missing,
            store: selectedStore,
            totalCost: recipe.baseCost + purchaseCost,
            unavailableReason: nil
        )
    }

    private static func missingIngredients(for recipe: Recipe, availableIngredients: [Ingredient]) -> [MissingIngredient] {
        recipe.ingredients.compactMap { needed in
            let stocked = pantryQuantity(for: needed, in: availableIngredients)
            let shortage = max(0, needed.quantityNeeded - stocked)
            guard shortage > 0 else { return nil }

            return MissingIngredient(
                name: needed.name,
                requiredQuantity: needed.quantityNeeded,
                currentQuantity: stocked,
                shortageQuantity: shortage,
                unit: needed.unit
            )
        }
    }

    private static func pantryQuantity(for requirement: IngredientRequirement, in ingredients: [Ingredient]) -> Double {
        ingredients
            .filter {
                $0.name.caseInsensitiveCompare(requirement.name) == .orderedSame
                && $0.unit.caseInsensitiveCompare(requirement.unit) == .orderedSame
            }
            .reduce(0) { $0 + $1.quantity }
    }

    private static func findCheapestStore(missingIngredients: [MissingIngredient], stores: [Store]) -> (Store?, Double?) {
        guard !missingIngredients.isEmpty else { return (nil, 0) }

        let candidates = stores.compactMap { store -> (Store, Double)? in
            var total = 0.0
            for ingredient in missingIngredients {
                guard let unitPrice = store.pricePerIngredient[ingredient.name] else {
                    return nil
                }
                total += unitPrice * ingredient.shortageQuantity
            }
            return (store, total)
        }

        let best = candidates.sorted {
            if $0.1 == $1.1 {
                return $0.0.distanceMinutes < $1.0.distanceMinutes
            }
            return $0.1 < $1.1
        }.first

        return (best?.0, best?.1)
    }
}

private struct RecipeEvaluation {
    var recipe: Recipe
    var missingIngredients: [MissingIngredient]
    var store: Store?
    var totalCost: Double?
    var unavailableReason: String?

    var isPurchasable: Bool {
        missingIngredients.isEmpty || store != nil
    }
}
