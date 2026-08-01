import Testing
import SwiftUI
@testable import Mosaic

struct ColorHexTests {
    @Test func parsesAccentPinkHexString() {
        let color = Color(hex: "#E8738A")
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        #expect(abs(red - 0xE8 / 255.0) < 0.01)
        #expect(abs(green - 0x73 / 255.0) < 0.01)
        #expect(abs(blue - 0x8A / 255.0) < 0.01)
    }

    @Test func parsesHexStringWithoutHashPrefix() {
        let color = Color(hex: "F7F5F1")
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        #expect(abs(red - 0xF7 / 255.0) < 0.01)
        #expect(abs(green - 0xF5 / 255.0) < 0.01)
        #expect(abs(blue - 0xF1 / 255.0) < 0.01)
    }
}
