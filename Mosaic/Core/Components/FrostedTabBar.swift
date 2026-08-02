import SwiftUI

struct FrostedTabBar: View {
    @Binding var selectedTab: AppTab
    var inboxCount: Int = 0

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: tab.systemImage)
                                .font(.system(size: 20))
                            if tab == .inbox && inboxCount > 0 {
                                Text("\(inboxCount)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(MosaicColor.accent)
                                    .clipShape(Capsule())
                                    .offset(x: 10, y: -6)
                            }
                        }
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
