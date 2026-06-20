import Foundation

/// 캐릭터 슬롯 BM에서 사용자가 가진 권한 상태입니다.
///
/// StoreKit을 붙이면 구매/구독 결과가 이 모델로 들어오고,
/// UI와 슬롯 사용 가능 여부는 이 모델만 보고 판단하게 됩니다.
struct CharacterSlotEntitlements: Equatable {
    /// 개별 슬롯을 영구 구매한 경우 해당 슬롯 ID를 저장합니다.
    var permanentlyUnlockedSlotIDs: Set<UUID>

    /// 월 구독이 활성화되어 모든 유료 슬롯을 사용할 수 있는 상태입니다.
    var isAllSlotsSubscriptionActive: Bool

    static let defaults = CharacterSlotEntitlements(
        permanentlyUnlockedSlotIDs: [],
        isAllSlotsSubscriptionActive: false
    )
}

/// 슬롯 하나가 현재 어떤 권한으로 열려 있는지 표현합니다.
enum CharacterSlotAccessState: Equatable {
    case free
    case permanent
    case subscription
    case locked

    var isUnlocked: Bool {
        self != .locked
    }

    var displayName: String {
        switch self {
        case .free:
            return "무료".posturePetLocalized
        case .permanent:
            return "영구 보유".posturePetLocalized
        case .subscription:
            return "구독 사용".posturePetLocalized
        case .locked:
            return "잠김".posturePetLocalized
        }
    }
}
