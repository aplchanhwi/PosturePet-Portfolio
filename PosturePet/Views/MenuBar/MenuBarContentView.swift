import AppKit
import SwiftUI

/// 메뉴바 아이콘을 클릭했을 때 펼쳐지는 메뉴 화면입니다.
///
/// iOS에는 상단 메뉴바 개념이 없기 때문에 이런 UI가 없습니다.
/// macOS 앱에서는 Dock에 큰 창을 띄우지 않고도 메뉴바에 작은 유틸리티 앱을 둘 수 있습니다.
struct MenuBarContentView: View {
    @ObservedObject var viewModel: AppViewModel

    /// macOS SwiftUI의 Window scene을 열 때 쓰는 환경값입니다.
    ///
    /// iOS에서는 보통 NavigationStack, sheet, fullScreenCover로 화면을 이동하지만,
    /// macOS에서는 독립적인 설정 창을 열어야 할 때 `openWindow(id:)`를 자주 씁니다.
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("목펴요")
                .font(.headline)

            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(posturePetLocalizedFormat("루틴: %@", viewModel.selectedRoutine.name))
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Button((viewModel.isMonitoring ? "일시정지" : "시작").posturePetLocalized) {
                viewModel.isMonitoring ? viewModel.pauseMonitoring() : viewModel.startMonitoring()
            }

            /// 메뉴바에서 바로 루틴을 고릅니다.
            /// 설정 창까지 열지 않아도 다음 오버레이와 "지금 스트레칭"에 즉시 반영됩니다.
            Menu("스트레칭 선택") {
                ForEach(StretchRoutine.mvpRoutines) { routine in
                    Button {
                        viewModel.selectRoutine(routine)
                    } label: {
                        routineMenuLabel(for: routine)
                    }
                }
            }

            Button("지금 하기") {
                viewModel.startBreakNow()
            }

            /// `PosturePetApp.swift`에 있는 `Window(..., id: "settings")`를 엽니다.
            /// iOS의 화면 push가 아니라, macOS의 별도 창을 여는 동작입니다.
            Button("설정") {
                /// 메뉴바 전용 앱은 Dock에 앱이 보이지 않기 때문에,
                /// 창을 열기 전에 앱을 foreground로 활성화해야 설정 창이 뒤에 숨는 일을 줄일 수 있습니다.
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "settings")
            }

            Divider()

            Button("종료") {
                viewModel.quit()
            }
        }
        .padding(.vertical, 4)
    }

    private var statusText: String {
        if viewModel.isMonitoring {
            posturePetLocalizedFormat("사용 시간 감지 중: %@", viewModel.usageState.activeAppName)
        } else {
            "대기 중".posturePetLocalized
        }
    }

    /// macOS 메뉴에서는 현재 선택된 항목에 체크 표시를 붙이면 상태가 훨씬 빨리 읽힙니다.
    @ViewBuilder
    private func routineMenuLabel(for routine: StretchRoutine) -> some View {
        if routine == viewModel.selectedRoutine {
            Label(routine.name, systemImage: "checkmark")
        } else {
            Text(routine.name)
        }
    }
}
