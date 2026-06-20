import AppKit
import SwiftUI

struct PosturePetCharacterView: View {
    let characterSkin: CharacterSkin?
    let routine: StretchRoutine

    @State private var isTiltingRight = false
    @State private var isBreathing = false

    private let silhouetteColor = Color(red: 0.13, green: 0.15, blue: 0.19)
    private let bodyColor = Color(red: 0.15, green: 0.16, blue: 0.20)
    private let neckColor = Color(red: 0.12, green: 0.14, blue: 0.18)
    private let highlightColor = Color(red: 0.19, green: 0.22, blue: 0.28)
    private let featureColor = Color(red: 0.95, green: 0.95, blue: 0.96)

    init(characterSkin: CharacterSkin? = nil, routine: StretchRoutine = .neckTilt) {
        self.characterSkin = characterSkin
        self.routine = routine
    }

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let scale = side / characterCanvasSize

            ZStack {
                characterContent
                    .frame(width: characterCanvasSize, height: characterCanvasSize)
                    .scaleEffect(scale)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.55).repeatForever(autoreverses: true)) {
                isTiltingRight.toggle()
            }

            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isBreathing.toggle()
            }
        }
    }

    /// 부모 화면마다 필요한 캐릭터 크기가 다릅니다.
    /// 그래서 실제 도형은 180x180 기준 캔버스에 그리고, 화면에는 부모가 준 크기에 맞춰 축소/확대합니다.
    private let characterCanvasSize: CGFloat = 180
    private let defaultCharacterCenterX: CGFloat = 90
    private let defaultHeadCenterY: CGFloat = 64.5
    private let defaultShoulderCenterY: CGFloat = 136

    @ViewBuilder
    private var characterContent: some View {
        if let characterImage, let characterSkin {
            uploadedCharacterImage(characterImage, characterSkin: characterSkin)
        } else {
            defaultSilhouetteCharacter
        }
    }

    private var characterImage: NSImage? {
        guard let characterSkin else { return nil }
        return NSImage(contentsOf: characterSkin.imageURL)
    }

    /// 업로드 이미지는 원본 파일을 자르지 않고 SpriteKit mesh deformation으로 움직입니다.
    /// 얼굴/목/어깨 기준점은 정점별 움직임 가중치를 계산하는 데 사용됩니다.
    private func uploadedCharacterImage(_ image: NSImage, characterSkin: CharacterSkin) -> some View {
        CharacterMeshWarpView(
            image: image,
            imageIdentifier: characterSkin.imagePath,
            rig: characterSkin.rig,
            routine: routine
        )
        .frame(width: 150, height: 150)
        .compositingGroup()
        .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
    }

    /// Figma의 수정된 B안(Round Utility)을 SwiftUI Shape 파츠로 재현한 기본 캐릭터입니다.
    /// 한 장 이미지로 넣지 않고 머리/목/어깨를 나눠 둔 이유는 기본 스트레칭 애니메이션을 더 자연스럽게 연결하기 위해서입니다.
    private var defaultSilhouetteCharacter: some View {
        ZStack {
            shoulderBody
                .scaleEffect(y: shoulderBodyScaleY, anchor: .bottom)
                .position(
                    x: defaultCharacterCenterX,
                    y: defaultShoulderCenterY + defaultShoulderOffsetY
                )

            /// 기본 캐릭터는 캔버스의 정중앙 세로선에 머리와 몸통을 맞춥니다.
            /// macOS SwiftUI의 `position`은 부모 좌표계 안에서 뷰의 중심점을 직접 지정합니다.
            headAndNeck
                .rotationEffect(defaultHeadRotation, anchor: .bottom)
                .scaleEffect(defaultHeadScale, anchor: .bottom)
                .position(
                    x: defaultCharacterCenterX + defaultHeadOffset.width,
                    y: defaultHeadCenterY + defaultHeadOffset.height
                )
        }
        .frame(width: 180, height: 180)
        .compositingGroup()
        .shadow(color: .black.opacity(0.16), radius: 7, y: 4)
    }

    private var defaultHeadRotation: Angle {
        guard routine.id == StretchRoutine.neckTilt.id else { return .degrees(0) }
        return .degrees(isTiltingRight ? 8.5 : -8.5)
    }

    private var defaultHeadScale: CGSize {
        guard routine.id == StretchRoutine.chinTuck.id else { return CGSize(width: 1, height: 1) }
        return CGSize(width: isTiltingRight ? 0.96 : 1.0, height: isTiltingRight ? 0.98 : 1.0)
    }

    private var defaultHeadOffset: CGSize {
        switch routine.id {
        case StretchRoutine.chinTuck.id:
            return CGSize(width: isTiltingRight ? 4 : -2, height: isTiltingRight ? -7 : -4)
        case StretchRoutine.shoulderShrug.id:
            return CGSize(width: 0, height: -2)
        default:
            return CGSize(width: 0, height: 0)
        }
    }

    private var defaultShoulderOffsetY: CGFloat {
        guard routine.id == StretchRoutine.shoulderShrug.id else { return 0 }
        return isBreathing ? -8 : 3
    }

    private var shoulderBodyScaleY: CGFloat {
        guard routine.id != StretchRoutine.shoulderShrug.id else { return 1 }
        return isBreathing ? 1.012 : 0.992
    }

    private var shoulderBody: some View {
        RoundUtilityShoulderBodyShape()
            .fill(bodyColor)
            .frame(width: 101, height: 68)
    }

    private var headAndNeck: some View {
        ZStack(alignment: .topLeading) {
            Capsule()
                .fill(neckColor)
                .frame(width: 21, height: 25)
                .offset(x: 28, y: 80)

            head
                .frame(width: 78, height: 85)
        }
        .frame(width: 78, height: 105)
    }

    private var head: some View {
        RoundUtilityHeadShape()
            .fill(silhouetteColor)
            .overlay(alignment: .topLeading) {
                RoundUtilityHairHighlightShape()
                    .fill(highlightColor.opacity(0.58))
                    .frame(width: 65, height: 26)
                    .offset(x: 6, y: 1)
            }
            .overlay(alignment: .topLeading) {
                facialFeatures
            }
    }

    private var facialFeatures: some View {
        ZStack(alignment: .topLeading) {
            Circle()
                .fill(featureColor.opacity(0.9))
                .frame(width: 9, height: 9)
                .offset(x: 20, y: 36)

            Circle()
                .fill(featureColor.opacity(0.9))
                .frame(width: 9, height: 9)
                .offset(x: 49, y: 36)

            MouthShape()
                .stroke(featureColor.opacity(0.48), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                .frame(width: 24, height: 8)
                .offset(x: 27, y: 59)
        }
    }
}

private struct RoundUtilityHeadShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.height * 0.49),
            control1: CGPoint(x: rect.maxX * 0.78, y: rect.minY),
            control2: CGPoint(x: rect.maxX, y: rect.height * 0.22)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.height * 0.78),
            control2: CGPoint(x: rect.maxX * 0.79, y: rect.maxY)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.height * 0.49),
            control1: CGPoint(x: rect.maxX * 0.21, y: rect.maxY),
            control2: CGPoint(x: rect.minX, y: rect.height * 0.78)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control1: CGPoint(x: rect.minX, y: rect.height * 0.22),
            control2: CGPoint(x: rect.maxX * 0.22, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}

private struct RoundUtilityShoulderBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 4, y: rect.maxY - 8))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY + 4),
            control1: CGPoint(x: rect.minX + 10, y: rect.height * 0.48),
            control2: CGPoint(x: rect.midX - 20, y: rect.minY + 4)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX - 4, y: rect.maxY - 8),
            control1: CGPoint(x: rect.midX + 20, y: rect.minY + 4),
            control2: CGPoint(x: rect.maxX - 10, y: rect.height * 0.48)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX - 12, y: rect.maxY),
            control1: CGPoint(x: rect.maxX - 3, y: rect.maxY - 3),
            control2: CGPoint(x: rect.maxX - 6, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + 12, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.minX + 4, y: rect.maxY - 8),
            control1: CGPoint(x: rect.minX + 6, y: rect.maxY),
            control2: CGPoint(x: rect.minX + 3, y: rect.maxY - 3)
        )
        path.closeSubpath()
        return path
    }
}

private struct RoundUtilityHairHighlightShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control1: CGPoint(x: rect.width * 0.11, y: rect.height * 0.36),
            control2: CGPoint(x: rect.width * 0.30, y: rect.minY)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control1: CGPoint(x: rect.width * 0.70, y: rect.minY),
            control2: CGPoint(x: rect.width * 0.90, y: rect.height * 0.36)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.height * 0.63),
            control1: CGPoint(x: rect.width * 0.68, y: rect.height * 0.72),
            control2: CGPoint(x: rect.width * 0.58, y: rect.height * 0.63)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY),
            control1: CGPoint(x: rect.width * 0.42, y: rect.height * 0.63),
            control2: CGPoint(x: rect.width * 0.32, y: rect.height * 0.72)
        )
        path.closeSubpath()
        return path
    }
}

private struct MouthShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 2, y: rect.midY))
        path.addCurve(
            to: CGPoint(x: rect.maxX - 2, y: rect.midY),
            control1: CGPoint(x: rect.width * 0.35, y: rect.maxY),
            control2: CGPoint(x: rect.width * 0.65, y: rect.maxY)
        )
        return path
    }
}
