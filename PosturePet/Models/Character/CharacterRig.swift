import Foundation

/// 커스텀 캐릭터 이미지에서 움직임의 기준이 되는 위치 정보입니다.
///
/// 사용자에게는 `얼굴과 어깨를 맞춰주세요`처럼 쉽게 보여주지만,
/// 내부적으로는 이마/턱/목/양쪽 어깨를 따로 저장합니다.
/// 이렇게 해야 턱은 비교적 고정하고 이마 쪽이 더 크게 움직이는 고개 기울이기를 만들 수 있습니다.
struct CharacterRig: Codable, Equatable, Sendable {
    /// 이미지 안에서 얼굴 중심이 어디인지 나타냅니다. 값은 0...1 비율입니다.
    /// 예전 저장 데이터와의 호환, 얼굴 주변 영향 범위 계산에 사용합니다.
    var faceCenter: CharacterPoint

    /// 이마 쪽 기준점입니다. 목 좌우 기울이기에서 얼굴 위쪽 움직임을 더 자연스럽게 만드는 데 사용합니다.
    var foreheadPoint: CharacterPoint

    /// 턱 쪽 기준점입니다. 목 좌우 기울이기에서 얼굴 회전의 중심에 가깝게 사용합니다.
    var chinPoint: CharacterPoint

    /// 목이 시작되는 위치입니다. 목 아래/어깨 고정 영역을 계산하는 기준점이 됩니다.
    var neckPoint: CharacterPoint

    /// 사용자가 보는 이미지 기준 왼쪽 어깨 위치입니다.
    var leftShoulder: CharacterPoint

    /// 사용자가 보는 이미지 기준 오른쪽 어깨 위치입니다.
    var rightShoulder: CharacterPoint

    /// 기존에 저장하던 `어깨 중심점`과 호환하기 위한 계산값입니다.
    /// 새 저장 구조에서는 왼쪽/오른쪽 어깨를 직접 저장하고, 중심은 필요할 때 계산합니다.
    var shoulderCenter: CharacterPoint {
        CharacterPoint(
            x: (leftShoulder.x + rightShoulder.x) / 2,
            y: (leftShoulder.y + rightShoulder.y) / 2
        )
    }

    nonisolated static let defaults = CharacterRig(
        faceCenter: CharacterPoint(x: 0.5, y: 0.32),
        foreheadPoint: CharacterPoint(x: 0.5, y: 0.22),
        chinPoint: CharacterPoint(x: 0.5, y: 0.43),
        neckPoint: CharacterPoint(x: 0.5, y: 0.54),
        leftShoulder: CharacterPoint(x: 0.32, y: 0.68),
        rightShoulder: CharacterPoint(x: 0.68, y: 0.68)
    )

    init(
        faceCenter: CharacterPoint,
        foreheadPoint: CharacterPoint,
        chinPoint: CharacterPoint,
        neckPoint: CharacterPoint,
        leftShoulder: CharacterPoint,
        rightShoulder: CharacterPoint
    ) {
        self.faceCenter = faceCenter
        self.foreheadPoint = foreheadPoint
        self.chinPoint = chinPoint
        self.neckPoint = neckPoint
        self.leftShoulder = leftShoulder
        self.rightShoulder = rightShoulder
    }

    private enum CodingKeys: String, CodingKey {
        case faceCenter
        case foreheadPoint
        case chinPoint
        case neckPoint
        case shoulderCenter
        case leftShoulder
        case rightShoulder
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = CharacterRig.defaults

        faceCenter = try container.decodeIfPresent(CharacterPoint.self, forKey: .faceCenter) ?? defaults.faceCenter
        foreheadPoint = try container.decodeIfPresent(CharacterPoint.self, forKey: .foreheadPoint)
            ?? CharacterPoint(x: faceCenter.x, y: Self.clamp(faceCenter.y - 0.10))
        chinPoint = try container.decodeIfPresent(CharacterPoint.self, forKey: .chinPoint)
            ?? CharacterPoint(x: faceCenter.x, y: Self.clamp(faceCenter.y + 0.11))
        neckPoint = try container.decodeIfPresent(CharacterPoint.self, forKey: .neckPoint) ?? defaults.neckPoint

        if let leftShoulder = try container.decodeIfPresent(CharacterPoint.self, forKey: .leftShoulder),
           let rightShoulder = try container.decodeIfPresent(CharacterPoint.self, forKey: .rightShoulder) {
            self.leftShoulder = leftShoulder
            self.rightShoulder = rightShoulder
        } else if let oldShoulderCenter = try container.decodeIfPresent(CharacterPoint.self, forKey: .shoulderCenter) {
            /// 예전 버전에서 저장한 어깨 중심점 하나를 좌우 어깨로 펼칩니다.
            /// 사용자가 다시 맞춤 화면을 열면 더 정확하게 고칠 수 있습니다.
            leftShoulder = CharacterPoint(
                x: Self.clamp(oldShoulderCenter.x - 0.18),
                y: oldShoulderCenter.y
            )
            rightShoulder = CharacterPoint(
                x: Self.clamp(oldShoulderCenter.x + 0.18),
                y: oldShoulderCenter.y
            )
        } else {
            leftShoulder = defaults.leftShoulder
            rightShoulder = defaults.rightShoulder
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(faceCenter, forKey: .faceCenter)
        try container.encode(foreheadPoint, forKey: .foreheadPoint)
        try container.encode(chinPoint, forKey: .chinPoint)
        try container.encode(neckPoint, forKey: .neckPoint)
        try container.encode(leftShoulder, forKey: .leftShoulder)
        try container.encode(rightShoulder, forKey: .rightShoulder)
        try container.encode(shoulderCenter, forKey: .shoulderCenter)
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

/// CGPoint를 그대로 저장하지 않고 직접 만든 이유는 Codable로 단순하게 저장하기 위해서입니다.
struct CharacterPoint: Codable, Equatable, Sendable {
    var x: Double
    var y: Double
}
