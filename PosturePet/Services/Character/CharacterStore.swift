import AppKit
import Foundation
import UniformTypeIdentifiers

/// 커스텀 캐릭터 이미지 파일을 고르고, 앱 내부 저장소에 복사하는 서비스입니다.
///
/// macOS 샌드박스 앱은 사용자의 Downloads 같은 파일에 마음대로 계속 접근할 수 없습니다.
/// 그래서 사용자가 고른 이미지는 즉시 Application Support 안의 앱 전용 폴더로 복사해 둡니다.
@MainActor
final class CharacterStore {
    enum CharacterStoreError: LocalizedError {
        case applicationSupportDirectoryNotFound
        case imageLoadFailed
        case foregroundMaskFailed
        case pngWriteFailed

        var errorDescription: String? {
            switch self {
            case .applicationSupportDirectoryNotFound:
                return "앱 저장 폴더를 찾지 못했어요.".posturePetLocalized
            case .imageLoadFailed:
                return "사진을 불러오지 못했어요.".posturePetLocalized
            case .foregroundMaskFailed:
                return "사진에서 캐릭터를 찾지 못했어요.".posturePetLocalized
            case .pngWriteFailed:
                return "이미지를 저장하지 못했어요.".posturePetLocalized
            }
        }
    }

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// 이미지 선택 창을 열고, 사용자가 고른 이미지를 앱 내부 폴더에 복사합니다.
    /// 사용자가 취소하면 nil을 반환합니다.
    func pickAndImportImage(replacing existingSkin: CharacterSkin?) throws -> CharacterSkin? {
        let panel = NSOpenPanel()
        panel.title = "캐릭터 사진 고르기".posturePetLocalized
        panel.prompt = "고르기".posturePetLocalized
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]

        guard panel.runModal() == .OK, let sourceURL = panel.url else {
            return nil
        }

        return try importImage(from: sourceURL, replacing: existingSkin)
    }

    /// 선택된 원본 이미지를 앱 내부 저장소에 복사하고 CharacterSkin을 만듭니다.
    private func importImage(from sourceURL: URL, replacing existingSkin: CharacterSkin?) throws -> CharacterSkin {
        let directory = try characterDirectoryURL()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let fileExtension = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension
        let destinationURL = directory.appendingPathComponent("character-\(UUID().uuidString).\(fileExtension)")

        try fileManager.copyItem(at: sourceURL, to: destinationURL)

        if let existingSkin {
            deleteImage(for: existingSkin)
        }

        return CharacterSkin(
            displayName: sourceURL.deletingPathExtension().lastPathComponent,
            imagePath: destinationURL.path,
            rig: .defaults
        )
    }

    func deleteImage(for skin: CharacterSkin) {
        try? fileManager.removeItem(at: skin.imageURL)
    }

    /// Apple Vision으로 이미지의 전경 마스크를 만든 뒤 투명 PNG로 저장합니다.
    /// 실제 Vision/CoreImage 처리는 CharacterBackgroundRemovalService에 맡깁니다.
    func removeBackground(from skin: CharacterSkin) throws -> CharacterSkin {
        try CharacterBackgroundRemovalService.removeBackground(from: skin)
    }

    private func characterDirectoryURL() throws -> URL {
        guard let applicationSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw CharacterStoreError.applicationSupportDirectoryNotFound
        }

        return applicationSupportURL
            .appendingPathComponent("PosturePet", isDirectory: true)
            .appendingPathComponent("Characters", isDirectory: true)
    }
}
