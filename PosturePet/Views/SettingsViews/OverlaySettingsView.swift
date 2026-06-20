import SwiftUI

/// 오버레이 창의 크기와 위치를 설정하는 화면입니다.
///
/// 실제 창 제어는 AppKit을 쓰는 `OverlayWindowManager`가 맡고,
/// 이 View는 사용자가 고른 설정값을 ViewModel에 전달하는 역할만 합니다.
struct OverlaySettingsView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        Form {
            Section("창 크기") {
                Picker("크기", selection: overlaySizeBinding) {
                    ForEach(OverlayWindowSize.allCases) { size in
                        Text(size.displayName).tag(size)
                    }
                }
                .pickerStyle(.segmented)

                LabeledContent("현재 크기", value: currentSizeText)
            }

            Section("창 위치") {
                Picker("위치", selection: overlayPositionBinding) {
                    ForEach(OverlayWindowPosition.allCases) { position in
                        Text(position.displayName).tag(position)
                    }
                }
            }

            Section("확인") {
                StretchOverlayPreview(
                    routine: viewModel.selectedRoutine,
                    characterSkin: viewModel.selectedCharacterSkin
                )

                HStack {
                    Button("미리보기") {
                        viewModel.startBreakNow()
                    }

                    Button("기본값으로 되돌리기") {
                        viewModel.resetOverlayWindowSettings()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(12)
    }

    private var currentSizeText: String {
        let size = viewModel.settings.overlayWindow.size.windowSize
        return "\(Int(size.width)) x \(Int(size.height))"
    }

    private var overlaySizeBinding: Binding<OverlayWindowSize> {
        Binding {
            viewModel.settings.overlayWindow.size
        } set: { size in
            viewModel.setOverlayWindowSize(size)
        }
    }

    private var overlayPositionBinding: Binding<OverlayWindowPosition> {
        Binding {
            viewModel.settings.overlayWindow.position
        } set: { position in
            viewModel.setOverlayWindowPosition(position)
        }
    }
}
