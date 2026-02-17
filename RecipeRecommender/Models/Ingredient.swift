import Foundation

struct Ingredient: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var quantity: Double
    var unit: String

    static func == (lhs: Ingredient, rhs: Ingredient) -> Bool {
        lhs.name == rhs.name && lhs.quantity == rhs.quantity && lhs.unit == rhs.unit
    }
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
