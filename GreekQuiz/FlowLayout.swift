import SwiftUI

struct FlowLayout<Data: Hashable, Content: View>: View {
    let data: [Data]
    let spacing: CGFloat
    let content: (Data) -> Content

    init(_ data: [Data], spacing: CGFloat = 8, @ViewBuilder content: @escaping (Data) -> Content) {
        self.data = data
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            self.generateContent(in: geometry)
        }
    }

    private func generateContent(in geometry: GeometryProxy) -> some View {
        var positions: [(x: CGFloat, y: CGFloat)] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for item in data {
            // Рассчитываем размер каждого элемента
            let proposedSize = CGSize(width: geometry.size.width, height: .infinity)
            let hosting = UIHostingController(rootView: content(item).fixedSize())
            hosting.view.translatesAutoresizingMaskIntoConstraints = false
            let targetSize = hosting.view.systemLayoutSizeFitting(proposedSize)

            if currentX + targetSize.width > geometry.size.width {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0 
            }

            positions.append((x: currentX, y: currentY))

            currentX += targetSize.width + spacing

            rowHeight = max(rowHeight, targetSize.height)
        }

        return ZStack(alignment: .topLeading) {
            ForEach(Array(data.enumerated()), id: \.1) { index, item in
                content(item)
                    .offset(x: positions[index].x, y: positions[index].y)
            }
        }
    }
}
