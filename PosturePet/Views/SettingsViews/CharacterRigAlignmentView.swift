import AppKit
import SwiftUI

struct CharacterRigAlignmentView: View {
    let character: CharacterSkin
    let onCancel: () -> Void
    let onSave: (CharacterRig) -> Void

    @State private var rig: CharacterRig
    @State private var characterImage: NSImage?

    init(
        character: CharacterSkin,
        onCancel: @escaping () -> Void,
        onSave: @escaping (CharacterRig) -> Void
    ) {
        self.character = character
        self.onCancel = onCancel
        self.onSave = onSave
        _rig = State(initialValue: character.rig)
        _characterImage = State(initialValue: NSImage(contentsOf: character.imageURL))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("움직임 기준 맞추기")
                    .font(.title3.bold())

                Text("점을 옮겨 얼굴, 목, 어깨 위치를 맞춰주세요.")
                    .foregroundStyle(.secondary)
            }

            if let characterImage {
                alignmentCanvas(image: characterImage)

                HStack(spacing: 14) {
                    pointLegend(.forehead)
                    pointLegend(.chin)
                    pointLegend(.neck)
                    pointLegend(.leftShoulder)
                    pointLegend(.rightShoulder)
                }
            } else {
                ContentUnavailableView(
                    "이미지를 불러올 수 없어요",
                    systemImage: "photo",
                    description: Text("사진을 다시 등록해 주세요.")
                )
                .frame(height: 300)
            }

            HStack {
                Button("기본 위치") {
                    rig = .defaults
                }
                .disabled(characterImage == nil)

                Spacer()

                Button("뒤로") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button("저장") {
                    onSave(rig)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(characterImage == nil)
            }
        }
    }

    private func alignmentCanvas(image: NSImage) -> some View {
        GeometryReader { geometry in
            let imageRect = fittedImageRect(
                imageSize: image.size,
                containerSize: geometry.size
            )

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))

                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)

                connectionPath(in: imageRect)
                    .stroke(Color.secondary.opacity(0.55), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))

                rigMarker(.forehead, in: imageRect)
                rigMarker(.chin, in: imageRect)
                rigMarker(.neck, in: imageRect)
                rigMarker(.leftShoulder, in: imageRect)
                rigMarker(.rightShoulder, in: imageRect)
            }
            .coordinateSpace(name: "CharacterRigCanvas")
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
            }
        }
        .frame(height: 360)
    }

    private func connectionPath(in imageRect: CGRect) -> Path {
        Path { path in
            let forehead = position(for: .forehead, in: imageRect)
            let chin = position(for: .chin, in: imageRect)
            let neck = position(for: .neck, in: imageRect)
            let leftShoulder = position(for: .leftShoulder, in: imageRect)
            let rightShoulder = position(for: .rightShoulder, in: imageRect)

            path.move(to: forehead)
            path.addLine(to: chin)
            path.addLine(to: neck)
            path.addLine(to: leftShoulder)

            path.move(to: neck)
            path.addLine(to: rightShoulder)

            path.move(to: leftShoulder)
            path.addLine(to: rightShoulder)
        }
    }

    private func rigMarker(_ point: RigPointKind, in imageRect: CGRect) -> some View {
        let position = position(for: point, in: imageRect)

        return ZStack {
            Circle()
                .fill(point.color)

            Circle()
                .stroke(Color.white, lineWidth: 2)

            Text(point.shortTitle)
                .font(.caption.bold())
                .foregroundStyle(.white)
        }
        .frame(width: 34, height: 34)
        .position(position)
        .shadow(color: .black.opacity(0.22), radius: 4, y: 2)
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("CharacterRigCanvas"))
                .onChanged { value in
                    update(point, to: value.location, in: imageRect)
                }
        )
        .accessibilityLabel(point.title)
    }

    private func pointLegend(_ point: RigPointKind) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(point.color)
                .frame(width: 10, height: 10)

            Text(point.title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func update(_ point: RigPointKind, to location: CGPoint, in imageRect: CGRect) {
        guard imageRect.width > 0, imageRect.height > 0 else { return }

        let clampedX = min(max(location.x, imageRect.minX), imageRect.maxX)
        let clampedY = min(max(location.y, imageRect.minY), imageRect.maxY)
        let normalizedPoint = CharacterPoint(
            x: Double((clampedX - imageRect.minX) / imageRect.width),
            y: Double((clampedY - imageRect.minY) / imageRect.height)
        )

        switch point {
        case .forehead:
            rig.foreheadPoint = normalizedPoint
            rig.faceCenter = faceCenterFromForeheadAndChin()
        case .chin:
            rig.chinPoint = normalizedPoint
            rig.faceCenter = faceCenterFromForeheadAndChin()
        case .neck:
            rig.neckPoint = normalizedPoint
        case .leftShoulder:
            rig.leftShoulder = normalizedPoint
        case .rightShoulder:
            rig.rightShoulder = normalizedPoint
        }
    }

    private func faceCenterFromForeheadAndChin() -> CharacterPoint {
        CharacterPoint(
            x: (rig.foreheadPoint.x + rig.chinPoint.x) / 2,
            y: (rig.foreheadPoint.y + rig.chinPoint.y) / 2
        )
    }

    private func position(for point: RigPointKind, in imageRect: CGRect) -> CGPoint {
        let characterPoint: CharacterPoint
        switch point {
        case .forehead:
            characterPoint = rig.foreheadPoint
        case .chin:
            characterPoint = rig.chinPoint
        case .neck:
            characterPoint = rig.neckPoint
        case .leftShoulder:
            characterPoint = rig.leftShoulder
        case .rightShoulder:
            characterPoint = rig.rightShoulder
        }

        return CGPoint(
            x: imageRect.minX + CGFloat(characterPoint.x) * imageRect.width,
            y: imageRect.minY + CGFloat(characterPoint.y) * imageRect.height
        )
    }

    /// `scaledToFit`으로 보이는 실제 이미지 영역을 계산합니다.
    /// 이미지 바깥 여백까지 점 위치에 포함되면 저장값이 어긋나기 때문입니다.
    private func fittedImageRect(imageSize: CGSize, containerSize: CGSize) -> CGRect {
        guard imageSize.width > 0,
              imageSize.height > 0,
              containerSize.width > 0,
              containerSize.height > 0 else {
            return CGRect(origin: .zero, size: containerSize)
        }

        let imageAspectRatio = imageSize.width / imageSize.height
        let containerAspectRatio = containerSize.width / containerSize.height

        if imageAspectRatio > containerAspectRatio {
            let width = containerSize.width
            let height = width / imageAspectRatio
            return CGRect(
                x: 0,
                y: (containerSize.height - height) / 2,
                width: width,
                height: height
            )
        } else {
            let height = containerSize.height
            let width = height * imageAspectRatio
            return CGRect(
                x: (containerSize.width - width) / 2,
                y: 0,
                width: width,
                height: height
            )
        }
    }
}

private enum RigPointKind {
    case forehead
    case chin
    case neck
    case leftShoulder
    case rightShoulder

    var title: String {
        switch self {
        case .forehead:
            return "이마".posturePetLocalized
        case .chin:
            return "턱".posturePetLocalized
        case .neck:
            return "목".posturePetLocalized
        case .leftShoulder:
            return "왼쪽 어깨".posturePetLocalized
        case .rightShoulder:
            return "오른쪽 어깨".posturePetLocalized
        }
    }

    var shortTitle: String {
        switch self {
        case .forehead:
            return "이".posturePetLocalized
        case .chin:
            return "턱".posturePetLocalized
        case .neck:
            return "목".posturePetLocalized
        case .leftShoulder:
            return "왼".posturePetLocalized
        case .rightShoulder:
            return "오".posturePetLocalized
        }
    }

    var color: Color {
        switch self {
        case .forehead:
            return .blue
        case .chin:
            return .pink
        case .neck:
            return .purple
        case .leftShoulder:
            return .green
        case .rightShoulder:
            return .orange
        }
    }
}
