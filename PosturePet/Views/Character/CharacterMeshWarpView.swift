import AppKit
import simd
import SpriteKit
import SwiftUI

/// 업로드한 캐릭터 이미지를 자르지 않고, 격자(mesh) 정점만 움직여서 목 움직임을 표현하는 뷰입니다.
///
/// 지금까지의 머리/몸통 마스크 방식은 긴 머리, 귀, 모자처럼 어깨 아래로 이어지는 요소가 잘릴 수 있었습니다.
/// 이 뷰는 이미지 한 장을 통째로 유지하고, 얼굴/목/어깨 기준점에 가까운 격자점만 더 많이 움직입니다.
struct CharacterMeshWarpView: NSViewRepresentable {
    let image: NSImage
    let imageIdentifier: String
    let rig: CharacterRig
    let routine: StretchRoutine

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> SKView {
        let view = SKView()
        view.allowsTransparency = true
        view.ignoresSiblingOrder = true
        view.presentScene(context.coordinator.scene)
        return view
    }

    func updateNSView(_ nsView: SKView, context: Context) {
        context.coordinator.scene.configure(
            image: image,
            imageIdentifier: imageIdentifier,
            rig: rig,
            routine: routine
        )
    }

    final class Coordinator {
        fileprivate let scene = CharacterMeshWarpScene()
    }
}

fileprivate final class CharacterMeshWarpScene: SKScene {
    private let sprite = SKSpriteNode()
    private let columns = 8
    private let rows = 8

    private var imageIdentifier = ""
    private var imageSize = CGSize(width: 1, height: 1)
    private var visibleImageRect = NormalizedImageRect.full
    private var rig = CharacterRig.defaults
    private var routineID = StretchRoutine.neckTilt.id
    private var animationStartTime: TimeInterval?

    override init(size: CGSize = CGSize(width: 150, height: 150)) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = .clear

        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        addChild(sprite)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        image: NSImage,
        imageIdentifier: String,
        rig: CharacterRig,
        routine: StretchRoutine
    ) {
        routineID = routine.id

        if self.imageIdentifier != imageIdentifier {
            self.imageIdentifier = imageIdentifier
            visibleImageRect = AlphaVisibleImageBounds.visibleRect(in: image) ?? .full
            imageSize = visibleImageRect.size(in: image.size)

            let fullTexture = SKTexture(image: image)
            fullTexture.filteringMode = .linear
            let texture = SKTexture(rect: visibleImageRect.spriteKitTextureRect, in: fullTexture)
            texture.filteringMode = .linear
            sprite.texture = texture
            layoutSprite()
        }

        // 화면에는 투명 여백을 잘라낸 텍스처를 쓰므로,
        // 사용자가 원본 이미지 기준으로 찍은 핀도 잘린 영역 기준으로 변환해야 합니다.
        self.rig = rig.remapped(to: visibleImageRect)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutSprite()
    }

    override func update(_ currentTime: TimeInterval) {
        if animationStartTime == nil {
            animationStartTime = currentTime
        }

        let elapsedTime = currentTime - (animationStartTime ?? currentTime)
        let phase = CGFloat(sin(elapsedTime * 2.0 * .pi / 3.1))
        applyWarp(phase: phase)
    }

    private func layoutSprite() {
        guard imageSize.width > 0,
              imageSize.height > 0,
              size.width > 0,
              size.height > 0 else { return }

        let imageAspectRatio = imageSize.width / imageSize.height
        let viewAspectRatio = size.width / size.height

        let fittedSize: CGSize
        if imageAspectRatio > viewAspectRatio {
            let width = size.width
            fittedSize = CGSize(width: width, height: width / imageAspectRatio)
        } else {
            let height = size.height
            fittedSize = CGSize(width: height * imageAspectRatio, height: height)
        }

        sprite.position = CGPoint(x: size.width / 2, y: size.height / 2)
        sprite.size = fittedSize
    }

    private func applyWarp(phase: CGFloat) {
        var sourcePositions: [vector_float2] = []
        var destinationPositions: [vector_float2] = []

        for row in 0...rows {
            for column in 0...columns {
                let x = CGFloat(column) / CGFloat(columns)
                let yFromBottom = CGFloat(row) / CGFloat(rows)

                sourcePositions.append(vector_float2(Float(x), Float(yFromBottom)))

                /// SpriteKit의 warp 좌표는 아래쪽이 0이고,
                /// 우리가 저장한 CharacterRig 좌표는 SwiftUI 이미지처럼 위쪽이 0입니다.
                let pointFromTop = CGPoint(x: x, y: 1 - yFromBottom)
                let warpedFromTop = warpedPoint(pointFromTop, phase: phase)
                let warpedFromBottom = CGPoint(x: warpedFromTop.x, y: 1 - warpedFromTop.y)

                destinationPositions.append(
                    vector_float2(
                        Float(clamp(warpedFromBottom.x)),
                        Float(clamp(warpedFromBottom.y))
                    )
                )
            }
        }

        sprite.warpGeometry = SKWarpGeometryGrid(
            __columns: columns,
            rows: rows,
            sourcePositions: sourcePositions,
            destPositions: destinationPositions
        )
    }

    private func warpedPoint(_ point: CGPoint, phase: CGFloat) -> CGPoint {
        switch routineID {
        case StretchRoutine.neckTilt.id:
            return neckTiltPoint(point, phase: phase)
        case StretchRoutine.chinTuck.id:
            return chinTuckPoint(point, phase: phase)
        case StretchRoutine.shoulderShrug.id:
            return shoulderShrugPoint(point, phase: phase)
        default:
            return point
        }
    }

    private func neckTiltPoint(_ point: CGPoint, phase: CGFloat) -> CGPoint {
        let chin = cgPoint(rig.chinPoint)
        let angle = phase * .pi / 11.0
        let weight = headWeight(for: point)

        // 턱을 회전 중심에 가깝게 두면 턱 주변은 덜 움직이고,
        // 이마처럼 턱에서 먼 지점은 더 크게 움직여 고개 기울임이 자연스러워집니다.
        let rotated = rotate(point, around: chin, angle: angle)

        return blend(from: point, to: rotated, weight: weight)
    }

    private func chinTuckPoint(_ point: CGPoint, phase: CGFloat) -> CGPoint {
        let forehead = cgPoint(rig.foreheadPoint)
        let chin = cgPoint(rig.chinPoint)
        let neck = cgPoint(rig.neckPoint)
        let shoulderCenter = cgPoint(rig.shoulderCenter)
        let face = CGPoint(
            x: (forehead.x + chin.x) / 2,
            y: (forehead.y + chin.y) / 2
        )

        let faceHeight = max(chin.y - forehead.y, 0.14)
        let neckToShoulder = max(shoulderCenter.y - neck.y, 0.12)
        let progress = (phase + 1) / 2
        let easedProgress = smoothstep(0, 1, progress)

        let headInfluence = headWeight(for: point)
        let lowerFaceInfluence = smoothstep(
            forehead.y + faceHeight * 0.25,
            chin.y + faceHeight * 0.18,
            point.y
        )
        let belowChin = max(0, point.y - chin.y)
        let neckInfluence = (1 - smoothstep(0, neckToShoulder * 0.58, belowChin))
            * smoothstep(chin.y - faceHeight * 0.2, neck.y + neckToShoulder * 0.25, point.y)

        // 턱 당기기는 좌우 회전보다 미묘한 동작입니다.
        // 턱 근처는 위쪽/가운데로 더 당기고, 이마는 조금만 따라오게 해서 얼굴 전체가 통째로 밀리지 않게 합니다.
        let chinLift = -easedProgress * (0.012 + lowerFaceInfluence * 0.026) * headInfluence
        let foreheadLift = -easedProgress * 0.008 * headInfluence * (1 - lowerFaceInfluence)
        let neckCompression = -easedProgress * 0.012 * neckInfluence
        let centerPull = (face.x - point.x) * easedProgress * 0.055 * lowerFaceInfluence * headInfluence

        let tucked = CGPoint(
            x: point.x + centerPull,
            y: point.y + chinLift + foreheadLift + neckCompression
        )

        return tucked
    }

    private func shoulderShrugPoint(_ point: CGPoint, phase: CGFloat) -> CGPoint {
        let shoulderWeight = shoulderWeight(for: point)
        let lifted = CGPoint(
            x: point.x,
            y: point.y - max(0, phase) * 0.035
        )

        return blend(from: point, to: lifted, weight: shoulderWeight)
    }

    private func headWeight(for point: CGPoint) -> CGFloat {
        let forehead = cgPoint(rig.foreheadPoint)
        let chin = cgPoint(rig.chinPoint)
        let face = CGPoint(
            x: (forehead.x + chin.x) / 2,
            y: (forehead.y + chin.y) / 2
        )
        let neck = cgPoint(rig.neckPoint)
        let shoulderCenter = cgPoint(rig.shoulderCenter)
        let leftShoulder = cgPoint(rig.leftShoulder)
        let rightShoulder = cgPoint(rig.rightShoulder)

        let shoulderSpan = max(abs(rightShoulder.x - leftShoulder.x), 0.22)
        let faceHeight = max(chin.y - forehead.y, 0.14)
        let neckToShoulder = max(shoulderCenter.y - neck.y, 0.12)

        let horizontalRadius = max(shoulderSpan * 0.78, 0.32)
        let horizontalWeight = 1 - smoothstep(
            horizontalRadius,
            horizontalRadius + 0.2,
            abs(point.x - face.x)
        )

        let radialX = (point.x - face.x) / max(shoulderSpan * 0.82, 0.34)
        let radialY = (point.y - face.y) / max(faceHeight * 1.75, 0.28)
        let radialDistance = sqrt(radialX * radialX + radialY * radialY)
        let radialWeight = 1 - smoothstep(0.9, 1.42, radialDistance)

        // 턱 위쪽은 머리 영역으로 봅니다. 턱이 회전 중심이므로 이마 쪽이 더 크게 움직입니다.
        if point.y <= chin.y {
            return clamp(max(horizontalWeight, radialWeight))
        }

        // 턱 아래부터는 빠르게 움직임을 줄여 목은 조금만 따라오고 어깨는 거의 고정합니다.
        let belowChin = max(0, point.y - chin.y)
        let chinFalloff = 1 - smoothstep(0, max(faceHeight * 0.62, 0.09), belowChin)
        let belowNeck = max(0, point.y - neck.y)
        let shoulderLock = 1 - smoothstep(neckToShoulder * 0.18, neckToShoulder * 0.62, belowNeck)
        let neckFollow = chinFalloff * shoulderLock

        return clamp(max(horizontalWeight * neckFollow, radialWeight * 0.16 * neckFollow))
    }

    private func shoulderWeight(for point: CGPoint) -> CGFloat {
        let shoulderCenter = cgPoint(rig.shoulderCenter)
        let leftShoulder = cgPoint(rig.leftShoulder)
        let rightShoulder = cgPoint(rig.rightShoulder)
        let shoulderSpan = max(abs(rightShoulder.x - leftShoulder.x), 0.24)

        let horizontalDistance = abs(point.x - shoulderCenter.x) / max(shoulderSpan * 0.78, 0.22)
        let verticalDistance = abs(point.y - shoulderCenter.y) / 0.26
        let distance = sqrt(horizontalDistance * horizontalDistance + verticalDistance * verticalDistance)

        return clamp(1 - smoothstep(0.35, 1.45, distance))
    }

    private func rotate(_ point: CGPoint, around pivot: CGPoint, angle: CGFloat) -> CGPoint {
        let dx = point.x - pivot.x
        let dy = point.y - pivot.y
        let cosine = cos(angle)
        let sine = sin(angle)

        return CGPoint(
            x: pivot.x + dx * cosine - dy * sine,
            y: pivot.y + dx * sine + dy * cosine
        )
    }

    private func blend(from start: CGPoint, to end: CGPoint, weight: CGFloat) -> CGPoint {
        CGPoint(
            x: start.x + (end.x - start.x) * weight,
            y: start.y + (end.y - start.y) * weight
        )
    }

    private func cgPoint(_ point: CharacterPoint) -> CGPoint {
        CGPoint(x: clamp(CGFloat(point.x)), y: clamp(CGFloat(point.y)))
    }

    private func smoothstep(_ edge0: CGFloat, _ edge1: CGFloat, _ value: CGFloat) -> CGFloat {
        guard edge0 != edge1 else { return value < edge0 ? 0 : 1 }
        let x = clamp((value - edge0) / (edge1 - edge0))
        return x * x * (3 - 2 * x)
    }

    private func clamp(_ value: CGFloat, lowerBound: CGFloat = 0, upperBound: CGFloat = 1) -> CGFloat {
        min(max(value, lowerBound), upperBound)
    }
}
