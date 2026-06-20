import Foundation

extension CharacterRig {
    /// 표시용으로 투명 여백을 잘라낸 경우, 원본 이미지 기준 리그 좌표를 잘린 영역 기준으로 다시 맞춥니다.
    func remapped(to visibleRect: NormalizedImageRect) -> CharacterRig {
        CharacterRig(
            faceCenter: visibleRect.remap(faceCenter),
            foreheadPoint: visibleRect.remap(foreheadPoint),
            chinPoint: visibleRect.remap(chinPoint),
            neckPoint: visibleRect.remap(neckPoint),
            leftShoulder: visibleRect.remap(leftShoulder),
            rightShoulder: visibleRect.remap(rightShoulder)
        )
    }
}
