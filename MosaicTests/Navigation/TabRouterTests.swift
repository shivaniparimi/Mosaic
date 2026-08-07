import Testing
@testable import Mosaic

@MainActor
struct TabRouterTests {
    @Test func defaultSelectedTabIsToday() {
        let router = TabRouter()
        #expect(router.selectedTab == .today)
    }

    @Test func fabIsVisibleOnTodayInboxAndUpcoming() {
        let router = TabRouter()
        #expect(router.isFABVisible(for: .today))
        #expect(router.isFABVisible(for: .inbox))
        #expect(router.isFABVisible(for: .upcoming))
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

    @Test func detailPresentedDefaultsToFalseForEveryTab() {
        let router = TabRouter()
        for tab in AppTab.allCases {
            #expect(!router.isDetailPresented(for: tab))
        }
    }

    @Test func setDetailPresentedTracksStatePerTabIndependently() {
        let router = TabRouter()

        router.setDetailPresented(true, for: .today)

        #expect(router.isDetailPresented(for: .today))
        #expect(!router.isDetailPresented(for: .inbox))

        router.setDetailPresented(false, for: .today)

        #expect(!router.isDetailPresented(for: .today))
    }
}
