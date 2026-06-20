import AppKit
import SwiftUI

/// SwiftUI 오버레이 화면을 macOS의 실제 떠 있는 창으로 만들어주는 관리자입니다.
///
/// SwiftUI만으로는 "항상 위에 떠 있는 투명한 보조 창"을 세밀하게 다루기 어렵습니다.
/// iOS에는 앱이 다른 앱 위에 마음대로 창을 띄우는 개념이 거의 없지만, macOS는 여러 창을 다루는 OS라 AppKit 창 제어가 가능합니다.
/// 그래서 이 파일에서 AppKit의 `NSPanel`을 사용합니다.
@MainActor
final class OverlayWindowManager {
    /// 재사용할 오버레이 패널입니다.
    /// 매번 새 창을 만들지 않고 하나를 만들어 두고 내용만 바꿉니다.
    private var window: NSPanel?
    
    /// 스트레칭 오버레이를 화면 위에 띄웁니다.
    func show(
        routine: StretchRoutine,
        breakDuration: TimeInterval,
        defaultSnoozeMinutes: Int,
        characterSkin: CharacterSkin?,
        overlaySettings: OverlayWindowSettings,
        onAction: @escaping (StretchOverlayAction) -> Void
    ) {
        let overlaySize = overlaySettings.size.windowSize

        if window == nil {
            let panel = NSPanel(
                contentRect: NSRect(origin: .zero, size: overlaySize),
                styleMask: [.nonactivatingPanel, .borderless],
                backing: .buffered,
                defer: false
            )
            
            /// floating panel로 만들어 일반 앱 창보다 위에 뜨게 합니다.
            panel.isFloatingPanel = true
            panel.level = .floating
            
            /// 배경을 투명하게 하고 SwiftUI view의 material 배경만 보이게 합니다.
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = true
            
            /// 전체 화면 Space에서도 보조 창으로 따라갈 수 있게 합니다.
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window = panel
        }
        
        window?.setContentSize(overlaySize)

        /// SwiftUI View를 AppKit 창 안에 넣기 위해 `NSHostingView`를 사용합니다.
        window?.contentView = NSHostingView(
            rootView: StretchOverlayView(
                routine: routine,
                breakDuration: breakDuration,
                defaultSnoozeMinutes: defaultSnoozeMinutes,
                characterSkin: characterSkin,
                overlaySize: overlaySize
            ) { [weak self] action in
                self?.hide()
                onAction(action)
            }
        )
        placeWindow(at: overlaySettings.position)
        window?.orderFrontRegardless()
    }
    
    /// 오버레이를 숨깁니다.
    func hide() {
        window?.orderOut(nil)
    }
    
    /// 사용자가 고른 위치 프리셋에 맞춰 오버레이를 배치합니다.
    private func placeWindow(at position: OverlayWindowPosition) {
        guard let window, let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let size = window.frame.size
        let edgeInset: CGFloat = 48
        let bottomInset: CGFloat = 96
        let topInset: CGFloat = 72

        let origin: NSPoint
        switch position {
        case .bottomCenter:
            origin = NSPoint(
                x: frame.midX - size.width / 2,
                y: frame.minY + bottomInset
            )
        case .center:
            origin = NSPoint(
                x: frame.midX - size.width / 2,
                y: frame.midY - size.height / 2
            )
        case .topCenter:
            origin = NSPoint(
                x: frame.midX - size.width / 2,
                y: frame.maxY - size.height - topInset
            )
        case .bottomLeft:
            origin = NSPoint(
                x: frame.minX + edgeInset,
                y: frame.minY + bottomInset
            )
        case .bottomRight:
            origin = NSPoint(
                x: frame.maxX - size.width - edgeInset,
                y: frame.minY + bottomInset
            )
        }

        window.setFrameOrigin(origin)
    }
}
