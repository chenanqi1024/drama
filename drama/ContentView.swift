import SwiftUI

struct ContentView: View {
    @StateObject private var store = DramaStore()
    @StateObject private var playbackManager = PlaybackManager()

    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
                    .navigationDestination(for: Drama.self) { drama in
                        DramaPlaybackView(drama: drama)
                    }
            }
            .tabItem {
                Label("首页", systemImage: "house.fill")
            }

            NavigationStack {
                TheaterView()
                    .navigationDestination(for: Drama.self) { drama in
                        DramaPlaybackView(drama: drama)
                    }
            }
            .tabItem {
                Label("剧场", systemImage: "rectangle.stack.fill")
            }

            NavigationStack {
                ProfileView()
                    .navigationDestination(for: Drama.self) { drama in
                        DramaPlaybackView(drama: drama)
                    }
            }
            .tabItem {
                Label("我的", systemImage: "person.fill")
            }
        }
        .tint(.red)
        .toolbarBackground(.black, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .environmentObject(store)
        .environmentObject(playbackManager)
        .task {
            await store.load()
        }
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
