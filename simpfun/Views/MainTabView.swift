//
//  MainTabView.swift
//  simpfun
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("实例", systemImage: "server.rack") {
                InstanceListView()
            }

            Tab("我的", systemImage: "person.crop.circle") {
                ProfileView()
            }
        }
    }
}

#Preview {
    MainTabView()
        .environment(AppModel())
}
