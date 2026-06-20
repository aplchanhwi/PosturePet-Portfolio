import SwiftUI

struct StretchOverlayView: View {
    let routine: StretchRoutine
    let breakDuration: TimeInterval
    
    /// ViewModel이 기억하고 있는 기본 스누즈 시간입니다.
    /// 이 View는 오버레이가 닫히면 사라지므로, 사용자가 고른 값을 직접 기억하지 않습니다.
    let defaultSnoozeMinutes: Int
    let characterSkin: CharacterSkin?
    let overlaySize: CGSize
    
    /// 오버레이가 닫힐 때 사용자가 어떤 행동을 선택했는지 받습니다.
    let onAction: (StretchOverlayAction) -> Void

    @State private var remainingSeconds: Int = 0
    
    @State private var didChooseAction = false
    
    private let snoozeOptions = [5, 10, 15, 20, 25, 30]
    
    var body: some View {
        VStack(spacing: 18) {
            PosturePetCharacterView(characterSkin: characterSkin, routine: routine)
                .frame(width: characterSideLength, height: characterSideLength)

            VStack(spacing: 6) {
                Text(routine.name)
                    .font(.title3.weight(.semibold))
                Text(routine.instruction)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Text(timeText)
                    .font(.headline.monospacedDigit())
            }

            HStack(spacing: 10) {
                snoozeButton
                
                Button("완료") {
                    didChooseAction = true
                    onAction(.completed)
                }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: overlaySize.width, height: overlaySize.height)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .task {
            remainingSeconds = max(1, Int(breakDuration.rounded(.up)))

            while remainingSeconds > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                remainingSeconds -= 1
            }
            
            /// 시간이 지나면 완료 처리.
            guard !Task.isCancelled, !didChooseAction else { return }
            onAction(.completed)
        }
    }
    
    /// SwiftUI의 `Menu(primaryAction:)`은 macOS에서 split button처럼 동작합니다.
    /// iOS의 `Button`만 쓰던 흐름과 달리, macOS에서는 메뉴를 가진 버튼이 자주 쓰입니다.
    /// - 버튼 본문 클릭: 기본 동작인 `나중에` 실행
    /// - 화살표 클릭: 몇 분 뒤 다시 알릴지 고르는 메뉴 표시
    private var snoozeButton: some View {
        Menu {
            ForEach(snoozeOptions, id: \.self) { minutes in
                Button {
                    snooze(after: minutes)
                } label: {
                    snoozeOptionLabel(minutes)
                }
            }
        } label: {
            Text("나중에")
                .frame(width: 82)
        } primaryAction: {
            snooze(after: defaultSnoozeMinutes)
        }
        .menuStyle(.button)
        .help(posturePetLocalizedFormat("현재 %d분 뒤 다시 알림", defaultSnoozeMinutes))
    }
    
    /// 선택된 항목에만 `checkmark` SF Symbol을 붙입니다.
    /// 빈 문자열을 `systemImage`로 넘기면 macOS가 "이름이 빈 심볼"을 찾으려고 해서 런타임 로그가 납니다.
    @ViewBuilder
    private func snoozeOptionLabel(_ minutes: Int) -> some View {
        if minutes == defaultSnoozeMinutes {
            Label(posturePetLocalizedFormat("%d분 뒤", minutes), systemImage: "checkmark")
        } else {
            Text(posturePetLocalizedFormat("%d분 뒤", minutes))
        }
    }

    private func snooze(after minutes: Int) {
        didChooseAction = true
        onAction(.snoozed(minutes: minutes))
    }

    private var characterSideLength: CGFloat {
        let sizeBasedLength = min(overlaySize.width * 0.43, overlaySize.height * 0.50)
        return min(220, max(145, sizeBasedLength))
    }

    private var timeText: String {
        "\(remainingSeconds / 60):\(String(format: "%02d", remainingSeconds % 60))"
    }
}
