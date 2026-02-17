import Foundation

struct Store: Identifiable {
    let id = UUID()
    var name: String
    var distanceMinutes: Int
    var pricePerIngredient: [String: Double]
}
