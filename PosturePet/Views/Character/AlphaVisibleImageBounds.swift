import AppKit

/// 투명 배경 PNG에서 실제 캐릭터 픽셀이 차지하는 영역을 찾습니다.
/// 배경 제거 후 큰 투명 캔버스에 작은 캐릭터만 남아도 화면에서는 캐릭터가 크게 보이게 하기 위한 helper입니다.
enum AlphaVisibleImageBounds {
    static func visibleRect(in image: NSImage) -> NormalizedImageRect? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = cgImage.bytesPerRow
        let bitsPerPixel = cgImage.bitsPerPixel
        let bitsPerComponent = cgImage.bitsPerComponent
        let alphaInfo = cgImage.alphaInfo

        guard width > 0,
              height > 0,
              bitsPerComponent == 8,
              bitsPerPixel >= 32,
              alphaInfo != .none,
              alphaInfo != .noneSkipFirst,
              alphaInfo != .noneSkipLast else { return nil }

        let bytesPerPixel = bitsPerPixel / 8
        let alphaOffset: Int
        switch alphaInfo {
        case .premultipliedFirst, .first:
            alphaOffset = 0
        case .premultipliedLast, .last:
            alphaOffset = min(3, bytesPerPixel - 1)
        default:
            return nil
        }

        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1
        let alphaThreshold: UInt8 = 8

        for y in 0..<height {
            let rowStart = y * bytesPerRow
            for x in 0..<width {
                let alpha = bytes[rowStart + x * bytesPerPixel + alphaOffset]
                if alpha > alphaThreshold {
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }

        guard maxX >= minX, maxY >= minY else { return nil }

        // 너무 딱 맞게 자르면 머리카락/귀/장식 끝이 답답해 보여서 약간의 표시 여백을 둡니다.
        let paddingX = max(Int(CGFloat(maxX - minX + 1) * 0.08), 8)
        let paddingY = max(Int(CGFloat(maxY - minY + 1) * 0.08), 8)
        let paddedMinX = max(minX - paddingX, 0)
        let paddedMinY = max(minY - paddingY, 0)
        let paddedMaxX = min(maxX + paddingX, width - 1)
        let paddedMaxY = min(maxY + paddingY, height - 1)

        let normalizedWidth = CGFloat(paddedMaxX - paddedMinX + 1) / CGFloat(width)
        let normalizedHeight = CGFloat(paddedMaxY - paddedMinY + 1) / CGFloat(height)

        guard normalizedWidth > 0, normalizedHeight > 0 else { return nil }

        return NormalizedImageRect(
            minX: CGFloat(paddedMinX) / CGFloat(width),
            minY: CGFloat(paddedMinY) / CGFloat(height),
            width: normalizedWidth,
            height: normalizedHeight
        )
    }
}
