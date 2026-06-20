//
//  RunningAppsSettingsView.swift
//  PosturePet
//
//  Created by 강찬휘 on 6/9/26.
//

import SwiftUI

struct RunningAppsSettingsView: View {
    /// 부모인 SettingsView에서 이미 만들어진 ViewModel을 전달받습니다.
    /// 이 View가 ViewModel을 소유하지 않으므로 `@ObservedObject`가 맞습니다.
    @ObservedObject var viewModel: AppViewModel
    var body: some View {
        VStack(alignment: .leading,spacing: 16) {
            HStack {
                Text("감지할 앱")
                    .font(.title2.bold())
                Spacer()
                Button("새로고침") {
                    viewModel.refreshRunningApps()
                }
            }
            
            Text("앱을 선택하지 않으면 모든 앱의 사용 시간을 감지해요.")
                .foregroundStyle(.secondary)
            
            List(viewModel.runningApps) { app in
                Toggle(app.name, isOn: Binding(
                    get: {
                        viewModel.selectedRunningAppIDs.contains(app.id)
                    },
                    set: { _ in
                        viewModel.toggleRunningApp(app)
                    }
                ))
            }
        }
        .padding(24)
        .onAppear {
            viewModel.refreshRunningApps()
        }
    }
}
