//
//  HereDocApp.swift
//  HereDoc
//
//  Created by 123456 on 4/8/26.
//

import SwiftUI

@main
struct HereDocApp: App {
    @State private var appModel = HereDocAppModel()

    var body: some Scene {
        WindowGroup {
            ContentView(appModel: appModel)
        }
    }
}
