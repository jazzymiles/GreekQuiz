import SwiftUI

struct FlowLayout<Data: Hashable, Content: View>: View {
    let data: [Data]
    let spacing: CGFloat
    let content: (Data) -> Content

    init(_ data: [Data], spacing: CGFloat = 5, @ViewBuilder content: @escaping (Data) -> Content) {
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

        // ⬇️ Предварительно вычисляем позиции
        for item in data {
            let size = CGSize(width: 1000, height: CGFloat.infinity) // placeholder
            let proposedSize = CGSize(width: geometry.size.width, height: .infinity)
            let hosting = UIHostingController(rootView: content(item)).view!
            let targetSize = hosting.systemLayoutSizeFitting(proposedSize)
            
            let _ = print("-")
            let _ = print(item)
            let _ = print(currentX)
            let _ = print(currentY)
            
            positions.append((x: currentX, y: currentY))
            
            if currentX + targetSize.width + spacing > geometry.size.width - 25 {
                currentX = 0
                currentY += rowHeight + 26
                rowHeight = 0
            }else{
                currentX += targetSize.width + 2
            }

            //positions.append((x: currentX, y: currentY))

            
            rowHeight = max(rowHeight, spacing)
        }

        return ZStack(alignment: .topLeading) {
            ForEach(Array(data.enumerated()), id: \.1) { index, item in
                content(item)
                    .alignmentGuide(.leading) { _ in -positions[index].x }
                    .alignmentGuide(.top) { _ in -positions[index].y }
            }
        }
    }
}

#Preview {
    ContentView()
}
