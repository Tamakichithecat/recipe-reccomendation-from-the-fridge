import Foundation

protocol RecipeDataStore {
    var recipes: [Recipe] { get }
    var stores: [Store] { get }
}

struct MockRecipeDataStore: RecipeDataStore {
    let recipes: [Recipe] = [
        Recipe(
            name: "野菜たっぷり味噌汁",
            ingredients: [
                IngredientRequirement(name: "大根", quantityNeeded: 0.5, unit: "本"),
                IngredientRequirement(name: "にんじん", quantityNeeded: 1, unit: "本"),
                IngredientRequirement(name: "豆腐", quantityNeeded: 0.5, unit: "丁"),
                IngredientRequirement(name: "味噌", quantityNeeded: 30, unit: "g")
            ],
            steps: [
                "野菜を食べやすい大きさに切る",
                "鍋で煮てから味噌を溶く"
            ],
            baseCost: 120
        ),
        Recipe(
            name: "鶏肉とキャベツの炒め物",
            ingredients: [
                IngredientRequirement(name: "鶏もも肉", quantityNeeded: 200, unit: "g"),
                IngredientRequirement(name: "キャベツ", quantityNeeded: 0.5, unit: "玉"),
                IngredientRequirement(name: "醤油", quantityNeeded: 15, unit: "ml")
            ],
            steps: [
                "材料を切り、鶏肉から炒める",
                "キャベツを加えて味付け"
            ],
            baseCost: 250
        )
    ]

    let stores: [Store] = [
        Store(
            name: "スーパーA",
            distanceMinutes: 6,
            pricePerIngredient: [
                "にんじん": 80,      // 円/本
                "豆腐": 90,         // 円/丁
                "味噌": 5.0,        // 円/g
                "鶏もも肉": 1.6,     // 円/g
                "大根": 120,        // 円/本
                "醤油": 0.7         // 円/ml
            ]
        ),
        Store(
            name: "スーパーB",
            distanceMinutes: 3,
            pricePerIngredient: [
                "にんじん": 70,      // 円/本
                "キャベツ": 150,     // 円/玉
                "豆腐": 100,        // 円/丁
                "鶏もも肉": 1.65,    // 円/g
                "味噌": 5.5,        // 円/g
                "大根": 110,        // 円/本
                "醤油": 0.8         // 円/ml
            ]
        )
    ]
}
