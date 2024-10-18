

import SwiftUI

@main
struct StoreKit2App: App {
    @State private var storeKitViewModel = StoreKitViewModel()
    
    var body: some Scene {
        WindowGroup {
            StoreKitView()
                .environment(storeKitViewModel)
        }
    }
}
