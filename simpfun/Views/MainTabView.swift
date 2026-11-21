//
//  MainTabView.swift
//  simpfun
//

import SwiftUI
import UIKit

struct MainTabView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var section: MainSection? = .instances

    private enum MainSection: Hashable {
        case instances
        case profile
    }

    var body: some View {
        if usesSplitLayout {
            splitLayout
        } else {
            tabLayout
        }
    }

    /// 仅在 iPad 的常规宽度下使用分栏布局，iPhone 横屏仍保持标签栏。
    private var usesSplitLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular
    }

    private var tabLayout: some View {
        TabView {
            Tab("实例", systemImage: "server.rack") {
                InstanceListView()
            }

            Tab("我的", systemImage: "person.crop.circle") {
                ProfileView()
            }
        }
    }

    private var splitLayout: some View {
        NavigationSplitView {
            List(selection: $section) {
                Label("实例", systemImage: "server.rack")
                    .tag(MainSection.instances)

                Label("我的", systemImage: "person.crop.circle")
                    .tag(MainSection.profile)
            }
            .listStyle(.sidebar)
            .navigationTitle("简幻欢")
        } detail: {
            switch section ?? .instances {
            case .instances:
                InstanceListView()
            case .profile:
                ProfileView()
            }
        }
        .navigationSplitViewStyle(.prominentDetail)
    }
}

#Preview {
    MainTabView()
        .environment(AppModel())
}
