import SwiftUI

struct TheaterView: View {
    @EnvironmentObject private var store: DramaStore
    @State private var selectedCategoryId: String?

    var body: some View {
        VStack(spacing: 0) {
            NavigationLink {
                SearchView()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                    Text("搜索短剧")
                    Spacer()
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 15)
                .frame(height: 46)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            if !store.categories.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 24) {
                        ForEach(store.categories) { category in
                            Button {
                                withAnimation {
                                    selectedCategoryId = category.id
                                }
                            } label: {
                                VStack(spacing: 6) {
                                    Text(category.titleZh)
                                        .font(.headline)
                                        .foregroundStyle(selectedCategoryId == category.id ? .primary : .secondary)
                                    Capsule()
                                        .fill(selectedCategoryId == category.id ? .red : .clear)
                                        .frame(width: 22, height: 3)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                }
                .scrollIndicators(.hidden)
                .padding(.top, 14)
            }

            Group {
                if store.isLoading && store.categories.isEmpty {
                    LoadingView()
                } else if let errorMessage = store.errorMessage, store.categories.isEmpty {
                    LoadErrorView(message: errorMessage) {
                        Task { await store.load() }
                    }
                } else {
                    TabView(selection: $selectedCategoryId) {
                        ForEach(store.categories) { category in
                            TheaterCategoryPage(dramas: store.dramas(in: category.id))
                                .tag(Optional(category.id))
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
        }
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if selectedCategoryId == nil {
                selectedCategoryId = store.categories.first?.id
            }
        }
        .onChange(of: store.categories) {
            if selectedCategoryId == nil {
                selectedCategoryId = store.categories.first?.id
            }
        }
    }
}

private struct TheaterCategoryPage: View {
    let dramas: [Drama]

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(dramas) { drama in
                    NavigationLink(value: drama) {
                        DramaPosterCard(drama: drama)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .scrollIndicators(.hidden)
        .overlay {
            if dramas.isEmpty {
                ContentUnavailableView("暂无短剧", systemImage: "rectangle.stack")
            }
        }
    }
}

private struct DramaPosterCard: View {
    let drama: Drama

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            RemotePoster(path: drama.poster)
                .aspectRatio(0.72, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .bottomTrailing) {
                    Text("全\(drama.totalEpisodes)集")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.6), in: Capsule())
                        .padding(7)
                }

            Text(drama.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(drama.tags.prefix(2).joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

private struct SearchView: View {
    @State private var searchText = ""

    var body: some View {
        ContentUnavailableView(
            "搜索功能即将上线",
            systemImage: "magnifyingglass",
            description: Text("之后可以在这里搜索喜欢的短剧")
        )
        .navigationTitle("搜索")
        .searchable(text: $searchText, prompt: "搜索短剧")
    }
}
