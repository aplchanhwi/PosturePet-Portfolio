//
//  PosturePetApp.swift
//  PosturePet
//
//  Created by 강찬휘 on 6/9/26.
//

import SwiftUI

/// 앱의 시작점입니다.
///
/// iOS 앱에서는 보통 `WindowGroup { ContentView() }` 하나로 시작하지만,
/// macOS에는 메뉴바 앱, 여러 창, Dock 표시 여부 같은 데스크톱 앱 개념이 추가됩니다.
/// PosturePet은 메뉴바에 조용히 머무는 macOS 앱이므로 `MenuBarExtra`를 먼저 둡니다.
///
/// 구조를 보면:
/// - `MenuBarExtra`: 상단 메뉴바 아이콘과 메뉴
/// - `Window`: 설정 창
/// - `AppViewModel`: 메뉴바, 설정 창, 오버레이가 공유하는 앱 상태
@main
struct PosturePetApp: App {
    /// 앱 전체에서 공유하는 ViewModel입니다.
    ///
    /// `@StateObject`를 쓰는 이유:
    /// SwiftUI가 화면을 다시 그려도 ViewModel 인스턴스가 새로 만들어지지 않게 하기 위해서입니다.
    @StateObject private var appViewModel = AppViewModel()

    var body: some Scene {
        /// 메뉴바에 나타나는 PosturePet 메뉴입니다.
/// `MenuBarExtra`는 macOS 전용에 가까운 SwiftUI API로, iOS 앱에는 대응되는 개념이 없습니다.
        /// 사용자는 여기서 감시 시작/일시정지, 즉시 스트레칭, 설정 열기를 할 수 있습니다.
        MenuBarExtra {
            MenuBarContentView(viewModel: appViewModel)
        } label: {
            Label("PosturePet", systemImage: appViewModel.isMonitoring ? "figure.mind.and.body" : "pause.circle")
        }
        .menuBarExtraStyle(.menu)

        /// 설정 창입니다.
/// iOS에서는 보통 화면 안에서 이동하지만, macOS에서는 설정을 별도의 창으로 여는 UX가 자연스럽습니다.
        /// 메뉴바의 "설정 열기" 버튼에서 `openWindow(id: "settings")`로 이 창을 엽니다.
        Window("설정", id: "settings") {
            SettingsView(viewModel: appViewModel)
                .frame(minWidth: 420, minHeight: 460)
        }
        .defaultSize(width: 460, height: 520)
    }
}
		
