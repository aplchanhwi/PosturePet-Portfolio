import Foundation

/// 사용자가 캐릭터를 등록할 수 있는 한 칸입니다.
///
/// MVP에서는 무료 슬롯 2개를 제공하고, 추가 슬롯은 UI만 보여주되 잠긴 상태로 둡니다.
/// 나중에 StoreKit 구매가 붙으면 `access`를 바꾸거나 구매 권한에 따라 열어주면 됩니다.
struct CharacterSlot: Codable, Equatable, Identifiable {
    enum Access: String, Codable {
        case free
        case locked
    }

    let id: UUID
    var name: String
    var access: Access
    var character: CharacterSkin?

    var isLocked: Bool {
        access == .locked
    }

    var displayName: String {
        character?.displayName ?? "기본 실루엣".posturePetLocalized
    }

    var localizedName: String {
        switch id {
        case CharacterSlot.firstFreeSlotID:
            return "슬롯 1".posturePetLocalized
        case CharacterSlot.secondFreeSlotID:
            return "슬롯 2".posturePetLocalized
        case UUID(uuidString: "00000000-0000-0000-0000-000000000003")!:
            return "추가 슬롯 1".posturePetLocalized
        case UUID(uuidString: "00000000-0000-0000-0000-000000000004")!:
            return "추가 슬롯 2".posturePetLocalized
        default:
            return name.posturePetLocalized
        }
    }

    static let firstFreeSlotID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let secondFreeSlotID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    static let defaults: [CharacterSlot] = [
        CharacterSlot(
            id: firstFreeSlotID,
            name: "슬롯 1",
            access: .free,
            character: nil
        ),
        CharacterSlot(
            id: secondFreeSlotID,
            name: "슬롯 2",
            access: .free,
            character: nil
        ),
        CharacterSlot(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            name: "추가 슬롯 1",
            access: .locked,
            character: nil
        ),
        CharacterSlot(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
            name: "추가 슬롯 2",
            access: .locked,
            character: nil
        )
    ]
}
