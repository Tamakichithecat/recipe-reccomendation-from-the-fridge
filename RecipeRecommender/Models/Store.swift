import Foundation

struct Store: Identifiable, Codable {
    let id = UUID()
    var name: String
    var distanceMinutes: Int
    var pricePerIngredient: [String: Double]
}
