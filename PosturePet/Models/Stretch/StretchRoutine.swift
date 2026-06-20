import Foundation

/// 하나의 스트레칭 루틴을 표현합니다.
///
/// `Identifiable`: ForEach에서 목록으로 보여주기 위해 필요합니다.
/// `Hashable`: Picker에서 선택값으로 쓰기 위해 필요합니다.
struct StretchRoutine: Identifiable, Equatable, Hashable {
    /// 코드에서 루틴을 구분하는 안정적인 ID입니다.
    let id: String

    /// 사용자에게 보이는 루틴 이름입니다.
    let nameKey: String

    /// 오버레이에 표시할 짧은 안내 문구입니다.
    let instructionKey: String

    /// 루틴 기본 시간입니다. 단위는 초입니다.
    let duration: TimeInterval

    var name: String {
        nameKey.posturePetLocalized
    }

    var instruction: String {
        instructionKey.posturePetLocalized
    }

    static let neckTilt = StretchRoutine(
        id: "neck-tilt",
        nameKey: "목 좌우 기울이기",
        instructionKey: "어깨는 편하게 두고 고개를 천천히 좌우로 기울여요.",
        duration: 60
    )

    static let chinTuck = StretchRoutine(
        id: "chin-tuck",
        nameKey: "턱 당기기",
        instructionKey: "턱을 살짝 뒤로 당겨 목 뒤쪽을 길게 만들어줘요.",
        duration: 45
    )

    static let shoulderShrug = StretchRoutine(
        id: "shoulder-shrug",
        nameKey: "어깨 으쓱하기",
        instructionKey: "어깨를 귀 쪽으로 올렸다가 천천히 내려놓아요.",
        duration: 45
    )

    /// MVP에서 먼저 제공할 3개의 루틴입니다.
    static let mvpRoutines: [StretchRoutine] = [neckTilt, chinTuck, shoulderShrug]

    static func routine(withID id: String) -> StretchRoutine {
        mvpRoutines.first { $0.id == id } ?? .neckTilt
    }
}
