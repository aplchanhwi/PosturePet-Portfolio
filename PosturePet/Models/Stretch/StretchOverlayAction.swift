//
//  StretchOverlayAction.swift
//  PosturePet
//
//  Created by 강찬휘 on 6/9/26.
//

import Foundation

/// 스트레칭 오버레이에서 사용자가 선택한 행동입니다.
///
/// 버튼은 UI일 뿐이고, 실제 의미는 enum으로 분리해두는 게 좋습니다.
/// 이렇게 하면 ViewModel에서 "완료"와 "나중에"를 명확하게 다르게 처리할 수 있습니다.
enum StretchOverlayAction {
    /// 사용자가 스트레칭을 완료했습니다.
    /// 집중 타이머를 리셋해도 되는 액션입니다.
    case completed

    /// 사용자가 스트레칭을 미뤘습니다.
    /// 집중 타이머는 리셋하지 않고, 선택한 시간 뒤 다시 오버레이를 띄웁니다.
    case snoozed(minutes: Int)
}
