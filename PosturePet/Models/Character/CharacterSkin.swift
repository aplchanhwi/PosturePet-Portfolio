import Foundation

/// 사용자가 등록한 캐릭터 이미지 정보입니다.
///
/// 이미지는 UserDefaults에 직접 저장하지 않고, 앱 내부 폴더에 파일로 저장합니다.
/// UserDefaults에는 그 파일을 다시 찾기 위한 경로와 움직임 기준 정보만 저장합니다.
struct CharacterSkin: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var displayName: String

    /// 사용자가 처음 등록한 원본 또는 배경 제거된 대표 이미지입니다.
    /// PosturePet은 이 이미지를 머리/몸통으로 자르지 않고, 한 장 이미지 위에 mesh deformation을 적용합니다.
    var imagePath: String

    var rig: CharacterRig

    nonisolated var imageURL: URL {
        URL(fileURLWithPath: imagePath)
    }

    nonisolated init(
        id: UUID = UUID(),
        displayName: String,
        imagePath: String,
        rig: CharacterRig = .defaults
    ) {
        self.id = id
        self.displayName = displayName
        self.imagePath = imagePath
        self.rig = rig
    }
}
