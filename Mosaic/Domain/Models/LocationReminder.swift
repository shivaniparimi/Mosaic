import Foundation
import SwiftData

@Model
final class LocationReminder {
    @Attribute(.unique) var id: UUID
    var name: String
    var address: String
    var latitude: Double
    var longitude: Double
    var trigger: LocationTrigger

    init(
        id: UUID = UUID(),
        name: String,
        address: String,
        latitude: Double,
        longitude: Double,
        trigger: LocationTrigger
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.trigger = trigger
    }
}
