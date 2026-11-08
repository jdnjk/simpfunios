//
//  SimpfunApp.swift
//  simpfun
//

import SwiftUI

@main
struct SimpfunApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }
    }
}
