import SwiftUI

/// 설정 창의 SwiftUI 화면입니다.
///
/// iOS라면 보통 `Settings` 화면이 NavigationStack 안에 들어가지만,
/// macOS에서는 메뉴바 앱에서 작은 독립 창으로 설정을 여는 흐름이 자연스럽습니다.
struct GeneralSettingsView: View {
    /// 부모인 SettingsView에서 이미 만들어진 ViewModel을 전달받습니다.
    /// 이 View가 ViewModel을 새로 생성하는 것이 아니므로 `@StateObject`가 아니라 `@ObservedObject`를 씁니다.
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        /// macOS의 Form은 시스템 설정 앱처럼 그룹화된 설정 UI를 만들기 좋습니다.
        /// iOS Form과 비슷하지만, 창 크기와 마우스 조작을 더 의식해서 배치해야 합니다.
        Form {
            Section("집중과 휴식") {
                Stepper(value: $viewModel.settings.focusDurationMinutes, in: 5...120, step: 5) {
                    LabeledContent("집중 시간", value: posturePetLocalizedFormat("%d분", Int(viewModel.settings.focusDurationMinutes)))
                }

                Stepper(value: $viewModel.settings.breakDurationMinutes, in: 1...5, step: 0.5) {
                    LabeledContent("휴식 시간", value: breakDurationText)
                }

                Toggle("앱 실행 시 자동으로 감지 시작", isOn: $viewModel.settings.shouldStartMonitoringOnLaunch)

                Toggle("자동으로 스트레칭 알리기", isOn: $viewModel.settings.isAutomaticOverlayEnabled)
            }

            Section("현재 상태") {
                LabeledContent("활성 앱", value: viewModel.usageState.activeAppName)
                ProgressView(value: viewModel.usageState.progress) {
                    Text("다음 휴식까지")
                } currentValueLabel: {
                    Text(remainingTimeText)
                }
            }

            Section("스트레칭 미리보기") {
                Picker("루틴", selection: selectedRoutineBinding) {
                    ForEach(StretchRoutine.mvpRoutines) { routine in
                        Text(routine.name).tag(routine)
                    }
                }

                StretchOverlayPreview(
                    routine: viewModel.selectedRoutine,
                    characterSkin: viewModel.selectedCharacterSkin
                )

                Button("미리보기") {
                    viewModel.startBreakNow()
                }
            }

            Section("법적 정보") {
                /// macOS SwiftUI의 `Link`는 사용자가 클릭하면 기본 브라우저로 URL을 엽니다.
                /// 개인정보 처리방침은 App Store 심사에서 앱 내부 접근 위치가 중요하므로 설정 탭 하단에 둡니다.
                Link("개인정보 처리방침", destination: LegalLinks.privacyPolicy)
                Link("이용약관", destination: LegalLinks.termsOfUse)
                Link("라이선스/EULA", destination: LegalLinks.standardEULA)
                Link("문의하기", destination: LegalLinks.support)
            }
        }
        .formStyle(.grouped)
        .padding(12)
    }

    private var breakDurationText: String {
        posturePetLocalizedFormat("%.1f분", viewModel.settings.breakDurationMinutes)
    }

    private var remainingTimeText: String {
        let seconds = Int(viewModel.usageState.remainingFocusTime)
        return posturePetLocalizedFormat("%d분 %d초", seconds / 60, seconds % 60)
    }

    private var selectedRoutineBinding: Binding<StretchRoutine> {
        Binding {
            viewModel.selectedRoutine
        } set: { routine in
            viewModel.selectRoutine(routine)
        }
    }
}

private enum LegalLinks {
    static let support = URL(string: "https://github.com/aplchanhwi/PosturePet-Support")!
    static let privacyPolicy = URL(string: "https://github.com/aplchanhwi/PosturePet-Support/blob/main/PrivacyPolicy.md")!
    static let termsOfUse = URL(string: "https://github.com/aplchanhwi/PosturePet-Support/blob/main/TermsOfUse.md")!
    static let standardEULA = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}
