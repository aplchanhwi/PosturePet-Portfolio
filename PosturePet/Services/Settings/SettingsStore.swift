//
//  SettingsStore.swift
//  PosturePet
//
//  Created by 강찬휘 on 6/9/26.
//

import Foundation

/// 앱 설정을 UserDefaults에 저장하고 다시 불러오는 역할을 담당합니다.
///
/// `PosturePetSettings`는 설정 데이터의 모양만 표현하는 Model이고,
/// `SettingsStore`는 그 설정 데이터를 실제 저장소(UserDefaults)에 넣고 꺼내는 Service입니다.
final class SettingsStore {
    /// 실제 저장 공간입니다.
    ///
    /// `UserDefaults.standard`는 앱마다 제공되는 작은 설정 저장소라고 생각하면 됩니다.
    /// 집중 시간, 휴식 시간, 토글 값처럼 작은 설정값을 저장하기 좋습니다.
    private let defaults: UserDefaults

    /// UserDefaults에 값을 저장할 때 사용할 key 이름들을 한 곳에 모아둡니다.
    ///
    /// 문자열 key를 코드 여기저기에 직접 쓰면 오타가 나도 찾기 어렵습니다.
    /// 그래서 `Key.focusDurationMinutes`처럼 이름을 붙여서 사용합니다.
    private enum Key {
        static let focusDurationMinutes = "focusDurationMinutes"
        static let breakDurationMinutes = "breakDurationMinutes"
        static let isOverlayEnabled = "isOverlayEnabled"
        static let shouldStartMonitoringOnLaunch = "shouldStartMonitoringOnLaunch"
        static let monitoredApps = "monitoredApps"
        static let customCharacter = "customCharacter"
        static let characterSlots = "characterSlots"
        static let selectedCharacterSlotID = "selectedCharacterSlotID"
        static let overlayWindowSize = "overlayWindowSize"
        static let overlayWindowPosition = "overlayWindowPosition"
        static let selectedRoutineID = "selectedRoutineID"
        static let permanentlyUnlockedCharacterSlotIDs = "permanentlyUnlockedCharacterSlotIDs"
        static let isAllCharacterSlotsSubscriptionActive = "isAllCharacterSlotsSubscriptionActive"
    }

    /// 기본값은 실제 앱 저장소인 `.standard`를 사용합니다.
    ///
    /// 이렇게 init에서 UserDefaults를 주입받게 만들면,
    /// 나중에 테스트할 때는 임시 UserDefaults를 넣어서 테스트하기 쉬워집니다.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 저장되어 있던 설정값을 UserDefaults에서 불러옵니다.
    ///
    /// 이 함수의 핵심 흐름은 이렇습니다.
    ///
    /// 1. UserDefaults에서 focusDurationMinutes 값을 찾는다.
    /// 2. 값이 있고 Double 타입이면 그 값을 쓴다.
    /// 3. 값이 없거나 타입이 맞지 않으면 `PosturePetSettings.defaults`의 기본값을 쓴다.
    /// 4. 나머지 설정값도 같은 방식으로 읽는다.
    /// 5. 마지막에 읽어온 값들을 모아 `PosturePetSettings`를 새로 만들어 반환한다.
    func load() -> PosturePetSettings {
        let characterSlots = loadCharacterSlots()
        let characterSlotEntitlements = loadCharacterSlotEntitlements()
        let selectedCharacterSlotID = loadSelectedCharacterSlotID(
            from: characterSlots,
            entitlements: characterSlotEntitlements
        )

        return PosturePetSettings(
            /// 집중 시간 설정을 불러옵니다.
            ///
            /// `defaults.object(forKey:)`는 UserDefaults에 저장된 값을 Any? 형태로 꺼냅니다.
            /// 그래서 `as? Double`로 "이 값이 Double이면 사용하겠다"고 타입 변환을 시도합니다.
            ///
            /// `??`는 왼쪽 값이 nil이면 오른쪽 기본값을 사용한다는 뜻입니다.
            /// 즉 저장된 집중 시간이 없으면 기본 집중 시간 값을 사용합니다.
            focusDurationMinutes:
                defaults.object(forKey: Key.focusDurationMinutes) as? Double
            ?? PosturePetSettings.defaults.focusDurationMinutes,

            /// 휴식 시간 설정을 불러옵니다.
            ///
            /// 집중 시간과 같은 방식입니다.
            /// 저장된 Double 값이 있으면 사용하고, 없으면 기본 휴식 시간을 사용합니다.
            breakDurationMinutes:
                defaults.object(forKey: Key.breakDurationMinutes) as? Double
            ?? PosturePetSettings.defaults.breakDurationMinutes,

            /// 자동 오버레이 설정을 불러옵니다.
            ///
            /// `as? Bool`은 저장된 값이 true/false 타입일 때만 성공합니다.
            /// 저장된 값이 아직 없으면 기본 설정의 `isAutomaticOverlayEnabled` 값을 사용합니다.
            isAutomaticOverlayEnabled:
                defaults.object(forKey: Key.isOverlayEnabled) as? Bool
            ?? PosturePetSettings.defaults.isAutomaticOverlayEnabled,

            /// 앱 실행 시 감지를 자동으로 시작할지 불러옵니다.
            ///
            /// 예전 버전에는 이 값이 없었기 때문에, 저장된 값이 없으면 기본값 true를 사용합니다.
            shouldStartMonitoringOnLaunch:
                defaults.object(forKey: Key.shouldStartMonitoringOnLaunch) as? Bool
            ?? PosturePetSettings.defaults.shouldStartMonitoringOnLaunch,

            /// 감지할 앱 목록을 불러옵니다.
            ///
            /// `RunningAppInfo`는 직접 만든 struct라서 UserDefaults에서 바로 꺼낼 수 없습니다.
            /// 아래 helper에서 JSON Data를 `[RunningAppInfo]`로 복원합니다.
            monitoredApps: loadMonitoredApps(),

            /// 캐릭터 슬롯 목록과 현재 선택된 슬롯을 불러옵니다.
            characterSlots: characterSlots,
            selectedCharacterSlotID: selectedCharacterSlotID,

            /// 오버레이 창 크기와 위치를 불러옵니다.
            overlayWindow: loadOverlayWindowSettings(),

            /// 마지막으로 선택한 스트레칭 루틴을 불러옵니다.
            selectedRoutineID: loadSelectedRoutineID(),

            /// 캐릭터 슬롯 구매/구독 권한을 불러옵니다.
            characterSlotEntitlements: characterSlotEntitlements
        )
    }

    /// 현재 설정값을 UserDefaults에 저장합니다.
    ///
    /// `load()`가 UserDefaults에서 Model을 만드는 함수라면,
    /// `save(_:)`는 Model을 UserDefaults에 다시 적어두는 함수입니다.
    func save(_ settings: PosturePetSettings) {
        defaults.set(settings.focusDurationMinutes, forKey: Key.focusDurationMinutes)
        defaults.set(settings.breakDurationMinutes, forKey: Key.breakDurationMinutes)
        defaults.set(settings.isAutomaticOverlayEnabled, forKey: Key.isOverlayEnabled)
        defaults.set(settings.shouldStartMonitoringOnLaunch, forKey: Key.shouldStartMonitoringOnLaunch)
        saveMonitoredApps(settings.monitoredApps)
        saveCharacterSlots(settings.characterSlots)
        defaults.set(settings.selectedCharacterSlotID.uuidString, forKey: Key.selectedCharacterSlotID)
        defaults.set(settings.overlayWindow.size.rawValue, forKey: Key.overlayWindowSize)
        defaults.set(settings.overlayWindow.position.rawValue, forKey: Key.overlayWindowPosition)
        defaults.set(settings.selectedRoutineID, forKey: Key.selectedRoutineID)
        saveCharacterSlotEntitlements(settings.characterSlotEntitlements)
    }

    private func loadOverlayWindowSettings() -> OverlayWindowSettings {
        let size = defaults
            .string(forKey: Key.overlayWindowSize)
            .flatMap(OverlayWindowSize.init(rawValue:))
        ?? OverlayWindowSettings.defaults.size

        let position = defaults
            .string(forKey: Key.overlayWindowPosition)
            .flatMap(OverlayWindowPosition.init(rawValue:))
        ?? OverlayWindowSettings.defaults.position

        return OverlayWindowSettings(size: size, position: position)
    }

    private func loadSelectedRoutineID() -> String {
        guard let id = defaults.string(forKey: Key.selectedRoutineID),
              StretchRoutine.mvpRoutines.contains(where: { $0.id == id }) else {
            return PosturePetSettings.defaults.selectedRoutineID
        }

        return id
    }

    /// `RunningAppInfo` 배열을 JSON Data로 바꿔 저장합니다.
    ///
    /// UserDefaults가 바로 저장할 수 있는 대표 타입은 `String`, `Bool`, `Double`, `Data` 등입니다.
    /// `RunningAppInfo`는 우리가 만든 struct라서 그대로 `defaults.set()` 할 수 없고,
    /// `Codable` + `JSONEncoder`로 Data로 변환해 저장합니다.
    private func saveMonitoredApps(_ apps: [RunningAppInfo]) {
        do {
            let data = try JSONEncoder().encode(apps)
            defaults.set(data, forKey: Key.monitoredApps)
        } catch {
            assertionFailure("Failed to encode monitored apps: \(error)")
        }
    }

    private func saveCharacterSlots(_ slots: [CharacterSlot]) {
        do {
            let data = try JSONEncoder().encode(slots)
            defaults.set(data, forKey: Key.characterSlots)
        } catch {
            assertionFailure("Failed to encode character slots: \(error)")
        }
    }

    private func loadCharacterSlots() -> [CharacterSlot] {
        if let data = defaults.data(forKey: Key.characterSlots) {
            do {
                return try JSONDecoder().decode([CharacterSlot].self, from: data)
            } catch {
                assertionFailure("Failed to decode character slots: \(error)")
            }
        }

        /// 예전 단일 캐릭터 저장 구조에서 넘어오는 경우, 슬롯 1에 넣어줍니다.
        var slots = CharacterSlot.defaults
        if let legacyCharacter = loadLegacyCustomCharacter(), !slots.isEmpty {
            slots[0].character = legacyCharacter
        }
        return slots
    }

    private func loadSelectedCharacterSlotID(
        from slots: [CharacterSlot],
        entitlements: CharacterSlotEntitlements
    ) -> UUID {
        let fallbackID = slots
            .first { isCharacterSlotUnlocked($0, entitlements: entitlements) }?
            .id
        ?? PosturePetSettings.defaults.selectedCharacterSlotID

        guard let value = defaults.string(forKey: Key.selectedCharacterSlotID),
              let id = UUID(uuidString: value),
              slots.contains(where: { $0.id == id && isCharacterSlotUnlocked($0, entitlements: entitlements) }) else {
            return fallbackID
        }

        return id
    }

    private func isCharacterSlotUnlocked(
        _ slot: CharacterSlot,
        entitlements: CharacterSlotEntitlements
    ) -> Bool {
        slot.access == .free
        || entitlements.permanentlyUnlockedSlotIDs.contains(slot.id)
        || entitlements.isAllSlotsSubscriptionActive
    }

    private func saveCharacterSlotEntitlements(_ entitlements: CharacterSlotEntitlements) {
        let unlockedSlotIDs = entitlements.permanentlyUnlockedSlotIDs.map(\.uuidString)
        defaults.set(unlockedSlotIDs, forKey: Key.permanentlyUnlockedCharacterSlotIDs)
        defaults.set(
            entitlements.isAllSlotsSubscriptionActive,
            forKey: Key.isAllCharacterSlotsSubscriptionActive
        )
    }

    private func loadCharacterSlotEntitlements() -> CharacterSlotEntitlements {
        let unlockedSlotIDs = defaults
            .stringArray(forKey: Key.permanentlyUnlockedCharacterSlotIDs)?
            .compactMap(UUID.init(uuidString:))
        ?? []

        let isSubscriptionActive =
            defaults.object(forKey: Key.isAllCharacterSlotsSubscriptionActive) as? Bool
            ?? CharacterSlotEntitlements.defaults.isAllSlotsSubscriptionActive

        return CharacterSlotEntitlements(
            permanentlyUnlockedSlotIDs: Set(unlockedSlotIDs),
            isAllSlotsSubscriptionActive: isSubscriptionActive
        )
    }

    private func loadLegacyCustomCharacter() -> CharacterSkin? {
        guard let data = defaults.data(forKey: Key.customCharacter) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(CharacterSkin.self, from: data)
        } catch {
            assertionFailure("Failed to decode legacy custom character: \(error)")
            return nil
        }
    }

    /// UserDefaults에 저장된 JSON Data를 다시 `[RunningAppInfo]`로 복원합니다.
    private func loadMonitoredApps() -> [RunningAppInfo] {
        guard let data = defaults.data(forKey: Key.monitoredApps) else {
            return PosturePetSettings.defaults.monitoredApps
        }

        do {
            return try JSONDecoder().decode([RunningAppInfo].self, from: data)
        } catch {
            assertionFailure("Failed to decode monitored apps: \(error)")
            return PosturePetSettings.defaults.monitoredApps
        }
    }
}
