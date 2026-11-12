import SwiftUI

@main
struct Erase4meCallsApp: App {
    @StateObject private var catalog = Catalog()
    @StateObject private var store = CallStore()

    init() {
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = UIColor(Palette.bg)
        tab.shadowColor = UIColor(Palette.line)
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(catalog)
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            ProtectionView()
                .tabItem { Label("Protection", systemImage: "shield.lefthalf.filled") }
            NumbersView()
                .tabItem { Label("Numéros", systemImage: "list.bullet.rectangle") }
            CallsView()
                .tabItem { Label("Appels", systemImage: "phone.arrow.down.left") }
            CheckView()
                .tabItem { Label("Vérifier", systemImage: "magnifyingglass") }
        }
        .tint(Palette.accent)
    }
}
