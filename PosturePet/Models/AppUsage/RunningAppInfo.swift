//
//  RunningAppInfo.swift
//  PosturePet
//
//  Created by 강찬휘 on 6/9/26.
//

/// 현재 실행 중인 앱 목록과 사용자가 선택한 감지 대상 앱을 표현하는 모델입니다.
///
/// `Codable`을 채택한 이유:
/// `UserDefaults`는 우리가 직접 만든 Swift struct를 그대로 저장할 수 없습니다.
/// 그래서 `SettingsStore`에서 이 값을 JSON Data로 바꿔 저장하고, 다시 앱을 켤 때 복원합니다.
struct RunningAppInfo: Identifiable, Hashable, Codable {
    /// UI에서 Toggle 선택 상태를 구분하는 안정적인 ID입니다.
    /// bundleIdentifier가 있으면 그 값을 쓰고, 없으면 앱 이름을 fallback으로 씁니다.
    let id: String

    /// 사용자에게 보여줄 앱 이름입니다. 예: Xcode, Safari
    let name: String

    /// macOS 앱의 고유 식별자입니다. 예: com.apple.dt.Xcode
    let bundleIdentifier: String?
}
