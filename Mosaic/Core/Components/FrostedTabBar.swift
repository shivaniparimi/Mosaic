import SwiftUI

struct FrostedTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 20))
                        Text(tab.title)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(selectedTab == tab ? MosaicColor.accent : .secondary)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.top, MosaicSpacing.sm)
        .padding(.bottom, MosaicSpacing.xs)
        .background(.ultraThinMaterial)
    }
}
