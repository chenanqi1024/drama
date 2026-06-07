import SwiftUI

struct VerticalPager<Item: Identifiable, Page: View>: View where Item.ID: Hashable {
    let items: [Item]
    @Binding var selection: Item.ID?
    @ViewBuilder let page: (Item) -> Page
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                ForEach(items) { item in
                    page(item)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
            }
            .frame(width: proxy.size.width, alignment: .top)
            .offset(y: -CGFloat(selectedIndex) * proxy.size.height + dragOffset)
            .contentShape(Rectangle())
            .simultaneousGesture(pageDragGesture(pageHeight: proxy.size.height))
        }
        .clipped()
    }

    private var selectedIndex: Int {
        guard let selection,
              let index = items.firstIndex(where: { $0.id == selection }) else {
            return 0
        }
        return index
    }

    private func pageDragGesture(pageHeight: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 16)
            .onChanged { value in
                guard abs(value.translation.height) > abs(value.translation.width) else {
                    return
                }

                let isDraggingPastFirst = selectedIndex == 0 && value.translation.height > 0
                let isDraggingPastLast = selectedIndex == items.count - 1 && value.translation.height < 0
                dragOffset = (isDraggingPastFirst || isDraggingPastLast)
                    ? value.translation.height * 0.2
                    : value.translation.height
            }
            .onEnded { value in
                defer {
                    withAnimation(.snappy(duration: 0.28)) {
                        dragOffset = 0
                    }
                }

                guard abs(value.predictedEndTranslation.height) >
                        abs(value.predictedEndTranslation.width),
                      !items.isEmpty else {
                    return
                }

                let threshold = pageHeight * 0.18
                var targetIndex = selectedIndex
                if value.predictedEndTranslation.height < -threshold {
                    targetIndex += 1
                } else if value.predictedEndTranslation.height > threshold {
                    targetIndex -= 1
                }
                targetIndex = min(max(targetIndex, 0), items.count - 1)

                withAnimation(.snappy(duration: 0.28)) {
                    selection = items[targetIndex].id
                }
            }
    }
}
