import Foundation

/// 현재 앱 사용 상태를 화면에 보여주기 좋게 묶은 값입니다.
///
/// Model은 "데이터 모양"만 표현합니다.
/// 실제로 시간을 재는 일은 `AppUsageMonitor`, 화면에 보여줄 판단은 `AppViewModel`이 담당합니다.
struct AppUsageState: Equatable {
    /// 지금 가장 앞에 떠 있는 앱 이름입니다. 예: Xcode, Safari, Figma
    var activeAppName: String

    /// 현재 집중 세션에서 누적된 사용 시간입니다. 단위는 초입니다.
    var elapsedFocusTime: TimeInterval

    /// 휴식 오버레이를 띄우기 전까지 기다릴 집중 시간입니다. 단위는 초입니다.
    var focusDuration: TimeInterval

    /// 설정 창의 ProgressView에 연결할 진행률입니다.
    /// 0.0이면 시작, 1.0이면 휴식 시간이 된 상태입니다.
    var progress: Double {
        guard focusDuration > 0 else { return 0 }
        return min(elapsedFocusTime / focusDuration, 1)
    }

    /// 다음 휴식까지 남은 시간입니다. 음수가 되지 않게 0에서 멈춥니다.
    var remainingFocusTime: TimeInterval {
        max(focusDuration - elapsedFocusTime, 0)
    }
}
