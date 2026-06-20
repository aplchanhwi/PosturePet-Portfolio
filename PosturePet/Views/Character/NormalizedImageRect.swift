import CoreGraphics

/// 이미지 안에서 실제 캐릭터가 보이는 영역을 0...1 비율로 표현합니다.
/// SwiftUI 이미지 좌표처럼 왼쪽 위가 원점입니다.
struct NormalizedImageRect: Equatable {
    let minX: CGFloat
    let minY: CGFloat
    let width: CGFloat
    let height: CGFloat

    static let full = NormalizedImageRect(minX: 0, minY: 0, width: 1, height: 1)

    var spriteKitTextureRect: CGRect {
        // SpriteKit texture rect는 왼쪽 아래가 원점이고, 이 타입은 SwiftUI처럼 왼쪽 위가 원점입니다.
        CGRect(x: minX, y: 1 - minY - height, width: width, height: height)
    }

    func size(in imageSize: CGSize) -> CGSize {
        CGSize(
            width: max(imageSize.width * width, 1),
            height: max(imageSize.height * height, 1)
        )
    }

    func remap(_ point: CharacterPoint) -> CharacterPoint {
        CharacterPoint(
            x: Double(clamp((CGFloat(point.x) - minX) / width)),
            y: Double(clamp((CGFloat(point.y) - minY) / height))
        )
    }

    private func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }
}
