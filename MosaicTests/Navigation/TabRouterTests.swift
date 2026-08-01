import Testing
@testable import Mosaic

@MainActor
struct TabRouterTests {
    @Test func defaultSelectedTabIsToday() {
        let router = TabRouter()
        #expect(router.selectedTab == .today)
    }

    @Test func fabIsVisibleOnTodayInboxAndProjects() {
        let router = TabRouter()
        #expect(router.isFABVisible(for: .today))
        #expect(router.isFABVisible(for: .inbox))
        #expect(router.isFABVisible(for: .projects))
    }

    @Test func fabIsHiddenOnSearchAndSettings() {
        let router = TabRouter()
        #expect(!router.isFABVisible(for: .search))
        #expect(!router.isFABVisible(for: .settings))
    }

    @Test func eachTabStartsWithAnEmptyNavigationPath() {
        let router = TabRouter()
        for tab in AppTab.allCases {
            #expect(router.path(for: tab).wrappedValue.isEmpty)
        }
    }
}
