//
//  SettingsView.swift
//  PosturePet
//
//  Created by 강찬휘 on 6/9/26.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel

    /// 설정창 사이드바에서 어떤 탭을 보고 있는지는 앱 데이터가 아니라 화면 내부 상태입니다.
    /// 이 값을 ViewModel의 @Published로 두면 SwiftUI List가 선택을 갱신하는 도중 publish가 발생할 수 있습니다.
    @State private var selectedTab: AppViewModel.SettingsTab = .general

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                Label("설정", systemImage: "slider.horizontal.3")
                    .tag(AppViewModel.SettingsTab.general)

                Label("오버레이 설정", systemImage: "rectangle.on.rectangle")
                    .tag(AppViewModel.SettingsTab.overlay)

                Label("캐릭터", systemImage: "person.crop.circle")
                    .tag(AppViewModel.SettingsTab.characters)

                Label("감지할 앱", systemImage: "macwindow")
                    .tag(AppViewModel.SettingsTab.runningApps)
            }
        } detail: {
            switch selectedTab {
            case .general:
                GeneralSettingsView(viewModel: viewModel)
            case .overlay:
                OverlaySettingsView(viewModel: viewModel)
            case .characters:
                CharacterSlotsSettingsView(viewModel: viewModel)
            case .runningApps:
                RunningAppsSettingsView(viewModel: viewModel)
            }
        }
    }
}
