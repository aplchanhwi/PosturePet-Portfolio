import Foundation

/// 코드에서 변수로 전달되는 문자열은 SwiftUI가 자동으로 현지화하지 못합니다.
/// 예를 들어 `Text("설정")`은 자동 현지화 대상이지만, `Text(title)`은 title 값을 그대로 보여줍니다.
/// 그래서 모델이나 계산 프로퍼티에서 만든 표시 문자열은 이 helper를 거쳐 번역합니다.
extension String {
    var posturePetLocalized: String {
        NSLocalizedString(self, comment: "")
    }
}

func posturePetLocalizedFormat(_ key: String, _ arguments: CVarArg...) -> String {
    String(
        format: key.posturePetLocalized,
        locale: Locale.current,
        arguments: arguments
    )
}
