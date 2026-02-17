import Foundation

struct Ingredient: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var quantity: Double
    var unit: String
}

struct IngredientRequirement: Identifiable {
    let id = UUID()
    var name: String
    var quantityNeeded: Double
    var unit: String
}

struct MissingIngredient: Identifiable {
    let id = UUID()
    var name: String
    var requiredQuantity: Double
    var currentQuantity: Double
    var shortageQuantity: Double
    var unit: String
}
