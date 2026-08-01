import SwiftUI

extension Color {
    init(hex: String) {
        let trimmed = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgbValue: UInt64 = 0
        Scanner(string: trimmed).scanHexInt64(&rgbValue)

        let red = Double((rgbValue & 0xFF0000) >> 16) / 255
        let green = Double((rgbValue & 0x00FF00) >> 8) / 255
        let blue = Double(rgbValue & 0x0000FF) / 255

        self.init(red: red, green: green, blue: blue)
    }
}
