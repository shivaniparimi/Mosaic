import Foundation

@Observable
@MainActor
final class CalendarPickerViewModel {
    private(set) var calendars: [CalendarInfo] = []

    private var selectedIdentifiers: Set<String> = []
    private let calendarSyncService: CalendarSyncService
    private let userDefaults: UserDefaults

    init(calendarSyncService: CalendarSyncService, userDefaults: UserDefaults = .standard) {
        self.calendarSyncService = calendarSyncService
        self.userDefaults = userDefaults
    }

    func load() async {
        calendars = await calendarSyncService.fetchAvailableCalendars()
        if let saved = userDefaults.stringArray(forKey: SettingsKeys.selectedCalendarIdentifiers) {
            selectedIdentifiers = Set(saved)
        } else {
            selectedIdentifiers = Set(calendars.map(\.id))
        }
    }

    func isSelected(_ calendar: CalendarInfo) -> Bool {
        selectedIdentifiers.contains(calendar.id)
    }

    func toggleSelection(for calendar: CalendarInfo) {
        if selectedIdentifiers.contains(calendar.id) {
            selectedIdentifiers.remove(calendar.id)
        } else {
            selectedIdentifiers.insert(calendar.id)
        }
        userDefaults.set(Array(selectedIdentifiers), forKey: SettingsKeys.selectedCalendarIdentifiers)
    }
}
