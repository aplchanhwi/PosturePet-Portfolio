import CoreImage
import Foundation
import Vision

/// Apple Vision으로 캐릭터 이미지의 전경만 남기는 서비스입니다.
///
/// `NSOpenPanel`처럼 macOS UI를 직접 만지는 일은 MainActor에서 해야 하지만,
/// Vision/CoreImage 이미지 처리는 시간이 걸릴 수 있으므로 백그라운드 Task에서 실행할 수 있게 별도 서비스로 분리했습니다.
enum CharacterBackgroundRemovalService {
    enum BackgroundRemovalError: LocalizedError {
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

    /// 무거운 이미지 처리만 담당하므로 ViewModel에서는 `Task.detached` 안에서 호출합니다.
    nonisolated static func removeBackground(from skin: CharacterSkin) throws -> CharacterSkin {
        let sourceURL = skin.imageURL
        guard let inputImage = CIImage(contentsOf: sourceURL) else {
            throw BackgroundRemovalError.imageLoadFailed
        }

        let requestHandler = VNImageRequestHandler(url: sourceURL)
        let request = VNGenerateForegroundInstanceMaskRequest()
        try requestHandler.perform([request])

        guard let observation = request.results?.first else {
            throw BackgroundRemovalError.foregroundMaskFailed
        }

        let maskBuffer = try observation.generateScaledMaskForImage(
            forInstances: observation.allInstances,
            from: requestHandler
        )
        let maskImage = CIImage(cvPixelBuffer: maskBuffer)
        let transparentBackground = CIImage(color: .clear).cropped(to: inputImage.extent)

        guard let blendFilter = CIFilter(name: "CIBlendWithMask") else {
            throw BackgroundRemovalError.foregroundMaskFailed
        }
        blendFilter.setValue(inputImage, forKey: kCIInputImageKey)
        blendFilter.setValue(transparentBackground, forKey: kCIInputBackgroundImageKey)
        blendFilter.setValue(maskImage, forKey: kCIInputMaskImageKey)

        guard let outputImage = blendFilter.outputImage?.cropped(to: inputImage.extent) else {
            throw BackgroundRemovalError.foregroundMaskFailed
        }

        let fileManager = FileManager.default
        let directory = try characterDirectoryURL(fileManager: fileManager)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let outputURL = directory.appendingPathComponent("character-cutout-\(UUID().uuidString).png")

        let context = CIContext()
        try context.writePNGRepresentation(
            of: outputImage,
            to: outputURL,
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        guard fileManager.fileExists(atPath: outputURL.path) else {
            throw BackgroundRemovalError.pngWriteFailed
        }

        try? fileManager.removeItem(at: sourceURL)

        return CharacterSkin(
            id: skin.id,
            displayName: skin.displayName,
            imagePath: outputURL.path,
            rig: skin.rig
        )
    }

    nonisolated private static func characterDirectoryURL(fileManager: FileManager) throws -> URL {
        guard let applicationSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw BackgroundRemovalError.applicationSupportDirectoryNotFound
        }

        return applicationSupportURL
            .appendingPathComponent("PosturePet", isDirectory: true)
            .appendingPathComponent("Characters", isDirectory: true)
    }
}
