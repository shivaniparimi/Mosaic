import Testing
import Foundation
@testable import Mosaic

@MainActor
struct CalendarPickerViewModelTests {
    private func makeIsolatedDefaults() -> (defaults: UserDefaults, cleanup: () -> Void) {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return (defaults, { defaults.removePersistentDomain(forName: suiteName) })
    }

    @Test func loadFetchesAvailableCalendarsFromService() async {
        let (defaults, cleanup) = makeIsolatedDefaults()
        defer { cleanup() }
        let service = StubCalendarSyncService(calendars: [
            CalendarInfo(id: "home", title: "Home", sourceName: "iCloud"),
            CalendarInfo(id: "work", title: "Work", sourceName: "iCloud")
        ])
        let viewModel = CalendarPickerViewModel(calendarSyncService: service, userDefaults: defaults)

        await viewModel.load()

        #expect(viewModel.calendars.map(\.id) == ["home", "work"])
    }

    @Test func loadDefaultsToAllCalendarsSelectedWhenNothingPersisted() async {
        let (defaults, cleanup) = makeIsolatedDefaults()
        defer { cleanup() }
        let service = StubCalendarSyncService(calendars: [
            CalendarInfo(id: "home", title: "Home", sourceName: "iCloud"),
            CalendarInfo(id: "work", title: "Work", sourceName: "iCloud")
        ])
        let viewModel = CalendarPickerViewModel(calendarSyncService: service, userDefaults: defaults)

        await viewModel.load()

        #expect(viewModel.isSelected(service.calendarsToReturn[0]))
        #expect(viewModel.isSelected(service.calendarsToReturn[1]))
    }

    @Test func loadRestoresPreviouslyPersistedSelection() async {
        let (defaults, cleanup) = makeIsolatedDefaults()
        defer { cleanup() }
        defaults.set(["home"], forKey: SettingsKeys.selectedCalendarIdentifiers)
        let service = StubCalendarSyncService(calendars: [
            CalendarInfo(id: "home", title: "Home", sourceName: "iCloud"),
            CalendarInfo(id: "work", title: "Work", sourceName: "iCloud")
        ])
        let viewModel = CalendarPickerViewModel(calendarSyncService: service, userDefaults: defaults)

        await viewModel.load()

        #expect(viewModel.isSelected(service.calendarsToReturn[0]))
        #expect(!viewModel.isSelected(service.calendarsToReturn[1]))
    }

    @Test func toggleSelectionDeselectsThenReselectsACalendar() async {
        let (defaults, cleanup) = makeIsolatedDefaults()
        defer { cleanup() }
        let home = CalendarInfo(id: "home", title: "Home", sourceName: "iCloud")
        let service = StubCalendarSyncService(calendars: [home])
        let viewModel = CalendarPickerViewModel(calendarSyncService: service, userDefaults: defaults)
        await viewModel.load()
        #expect(viewModel.isSelected(home))

        viewModel.toggleSelection(for: home)
        #expect(!viewModel.isSelected(home))

        viewModel.toggleSelection(for: home)
        #expect(viewModel.isSelected(home))
    }

    @Test func toggleSelectionPersistsToUserDefaults() async {
        let (defaults, cleanup) = makeIsolatedDefaults()
        defer { cleanup() }
        let home = CalendarInfo(id: "home", title: "Home", sourceName: "iCloud")
        let work = CalendarInfo(id: "work", title: "Work", sourceName: "iCloud")
        let service = StubCalendarSyncService(calendars: [home, work])
        let viewModel = CalendarPickerViewModel(calendarSyncService: service, userDefaults: defaults)
        await viewModel.load()

        viewModel.toggleSelection(for: home)

        let persisted = Set(defaults.stringArray(forKey: SettingsKeys.selectedCalendarIdentifiers) ?? [])
        #expect(persisted == ["work"])
    }
}

private final class StubCalendarSyncService: CalendarSyncService {
    let calendarsToReturn: [CalendarInfo]

    init(calendars: [CalendarInfo]) {
        self.calendarsToReturn = calendars
    }

    func requestAuthorization() async -> Bool { true }
    func fetchEvents(from startDate: Date, to endDate: Date) async -> [CalendarEvent] { [] }
    func fetchAvailableCalendars() async -> [CalendarInfo] { calendarsToReturn }
}
