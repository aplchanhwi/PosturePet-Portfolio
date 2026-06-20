import CoreGraphics
import Foundation

/// 오버레이 창의 크기 프리셋입니다.
///
/// 사용자가 직접 숫자를 입력하게 하면 처음에는 부담스럽기 때문에,
/// MVP에서는 작게/기본/크게 프리셋으로 시작합니다.
enum OverlayWindowSize: String, CaseIterable, Identifiable, Equatable {
    case compact
    case medium
    case large

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .compact:
            return "작게".posturePetLocalized
        case .medium:
            return "기본".posturePetLocalized
        case .large:
            return "크게".posturePetLocalized
        }
    }

    var windowSize: CGSize {
        switch self {
        case .compact:
            return CGSize(width: 360, height: 320)
        case .medium:
            return CGSize(width: 420, height: 360)
        case .large:
            return CGSize(width: 520, height: 430)
        }
    }
}

/// 오버레이 창이 화면 어디에 뜰지 정하는 위치 프리셋입니다.
enum OverlayWindowPosition: String, CaseIterable, Identifiable, Equatable {
    case bottomCenter
    case center
    case topCenter
    case bottomLeft
    case bottomRight

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bottomCenter:
            return "하단 중앙".posturePetLocalized
        case .center:
            return "화면 중앙".posturePetLocalized
        case .topCenter:
            return "상단 중앙".posturePetLocalized
        case .bottomLeft:
            return "하단 왼쪽".posturePetLocalized
        case .bottomRight:
            return "하단 오른쪽".posturePetLocalized
        }
    }
}

/// 실제 오버레이 창 표시와 관련된 설정 묶음입니다.
struct OverlayWindowSettings: Equatable {
    var size: OverlayWindowSize
    var position: OverlayWindowPosition

    static let defaults = OverlayWindowSettings(
        size: .medium,
        position: .bottomCenter
    )
}

/// 사용자가 바꿀 수 있는 설정값입니다.
///
/// SettingsStore를 통해 UserDefaults에 저장됩니다.
struct PosturePetSettings: Equatable {
    /// 몇 분 집중하면 휴식을 권할지 정합니다.
    var focusDurationMinutes: Double

    /// 오버레이가 몇 분 동안 떠 있을지 정합니다.
    var breakDurationMinutes: Double

    /// false이면 시간이 되어도 자동으로 오버레이를 띄우지 않습니다.
    var isAutomaticOverlayEnabled: Bool

    /// 앱을 실행했을 때 사용 시간 감지를 바로 시작할지 정합니다.
    ///
    /// 메뉴바 앱은 사용자가 켜둔 뒤 잊어도 조용히 작동하는 편이 자연스럽기 때문에,
    /// MVP 기본값은 true로 둡니다.
    var shouldStartMonitoringOnLaunch: Bool

    /// 감지할 앱 목록입니다.
    /// 비어 있으면 모든 활성 앱 시간을 센다는 뜻으로 처리합니다.
    var monitoredApps: [RunningAppInfo]
    
    /// 사용자가 등록할 수 있는 캐릭터 슬롯 목록입니다.
    /// MVP에서는 무료 슬롯 2개와 잠긴 추가 슬롯을 함께 보여줍니다.
    var characterSlots: [CharacterSlot]
    
    /// 오버레이에서 실제로 사용할 슬롯입니다.
    var selectedCharacterSlotID: UUID

    /// 오버레이 창의 크기와 위치 설정입니다.
    var overlayWindow: OverlayWindowSettings

    /// 마지막으로 선택한 스트레칭 루틴 ID입니다.
    var selectedRoutineID: String

    /// 캐릭터 슬롯 구매와 구독 권한입니다.
    var characterSlotEntitlements: CharacterSlotEntitlements
    
    var selectedCharacterSkin: CharacterSkin? {
        characterSlots.first { $0.id == selectedCharacterSlotID }?.character
    }

    var selectedRoutine: StretchRoutine {
        StretchRoutine.routine(withID: selectedRoutineID)
    }
    
    /// MVP 기본값입니다.
    static let defaults = PosturePetSettings(
        focusDurationMinutes: 25,
        breakDurationMinutes: 1.5,
        isAutomaticOverlayEnabled: true,
        shouldStartMonitoringOnLaunch: true,
        monitoredApps: [],
        characterSlots: CharacterSlot.defaults,
        selectedCharacterSlotID: CharacterSlot.firstFreeSlotID,
        overlayWindow: .defaults,
        selectedRoutineID: StretchRoutine.neckTilt.id,
        characterSlotEntitlements: .defaults
    )
}
