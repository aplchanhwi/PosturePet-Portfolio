import AppKit
import Foundation
import Combine

/// 현재 어떤 앱을 사용 중인지 감지하고, 사용 시간을 누적하는 서비스입니다.
///
/// iOS 앱은 다른 앱이 앞에 떠 있는지 자유롭게 볼 수 없지만,
/// macOS에서는 `NSWorkspace`를 통해 현재 frontmost application을 확인할 수 있습니다.
///
/// View가 직접 `NSWorkspace`를 만지지 않게 분리했습니다.
/// 이렇게 해두면 나중에 감지 로직이 복잡해져도 화면 코드는 크게 흔들리지 않습니다.
@MainActor
final class AppUsageMonitor: ObservableObject {
    /// 현재 가장 앞에 떠 있는 앱 이름입니다.
    @Published private(set) var activeAppName: String = "알 수 없음".posturePetLocalized

    /// 감지 대상 앱을 사용한 누적 시간입니다. 단위는 초입니다.
    @Published private(set) var elapsedFocusTime: TimeInterval = 0

    /// 1초마다 현재 활성 앱을 확인하는 작업입니다.
    /// `Timer` 대신 `Task` 루프를 쓴 이유는 Swift Concurrency 경고를 피하고 구조를 단순하게 하기 위해서입니다.
    private var monitoringTask: Task<Void, Never>?

    /// 마지막으로 시간을 계산한 시점입니다.
    private var lastTickDate: Date?

    /// 사용자가 감지 대상으로 고른 앱 목록입니다.
    /// 비어 있으면 모든 앱을 감지 대상으로 봅니다.
    private var monitoredApps: [RunningAppInfo] = []

    var isRunning: Bool {
        monitoringTask != nil
    }

    /// 앱 사용량 감지를 시작합니다.
    func start(monitoredApps: [RunningAppInfo]) {
        self.monitoredApps = monitoredApps
        /// `frontmostApplication`은 현재 사용자가 실제로 보고 있는 앱에 가깝습니다.
        /// 예: Xcode가 앞에 있으면 Xcode, Safari가 앞에 있으면 Safari가 잡힙니다.
        activeAppName = NSWorkspace.shared.frontmostApplication?.localizedName ?? "알 수 없음".posturePetLocalized
        lastTickDate = Date()

        monitoringTask?.cancel()
        monitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.tick()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    /// 앱 사용량 감지를 멈춥니다.
    func stop() {
        monitoringTask?.cancel()
        monitoringTask = nil
        lastTickDate = nil
    }

    /// 누적된 집중 시간을 0으로 돌립니다.
    /// 휴식 오버레이를 띄운 직후 다시 집중 시간을 세기 위해 사용합니다.
    func resetElapsedTime() {
        elapsedFocusTime = 0
        lastTickDate = Date()
    }

    /// 1초마다 호출되어 현재 앱과 경과 시간을 갱신합니다.
    private func tick() {
        let now = Date()
        let delta = now.timeIntervalSince(lastTickDate ?? now)
        lastTickDate = now

        let activeApplication = NSWorkspace.shared.frontmostApplication
        activeAppName = activeApplication?.localizedName ?? "알 수 없음".posturePetLocalized

        guard shouldCount(activeApplication: activeApplication) else { return }
        elapsedFocusTime += delta
    }

    /// 현재 앱을 사용 시간에 포함할지 결정합니다.
    private func shouldCount(activeApplication: NSRunningApplication?) -> Bool {
        guard !monitoredApps.isEmpty else { return true }
        guard let activeApplication else { return false }

        let activeBundleIdentifier = activeApplication.bundleIdentifier
        let activeName = activeApplication.localizedName ?? ""

        return monitoredApps.contains { monitoredApp in
            /// bundleIdentifier가 있으면 앱 이름보다 이 값이 더 정확합니다.
            /// 예: 앱 이름은 바뀔 수 있지만 `com.apple.dt.Xcode` 같은 bundle ID는 더 안정적입니다.
            if let monitoredBundleIdentifier = monitoredApp.bundleIdentifier,
               let activeBundleIdentifier {
                return monitoredBundleIdentifier == activeBundleIdentifier
            }

            /// bundleIdentifier가 없는 앱도 있을 수 있으므로 이름 비교를 fallback으로 둡니다.
            return activeName.localizedCaseInsensitiveContains(monitoredApp.name)
        }
    }
}
