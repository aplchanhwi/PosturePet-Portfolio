import Foundation

/// StoreKit에서 사용할 상품 ID를 한 곳에 모아둡니다.
///
/// App Store Connect에 상품을 만들 때도 이 문자열과 똑같은 Product ID를 사용해야 합니다.
/// 코드 여기저기에 직접 문자열을 쓰면 오타를 찾기 어려워서, 카탈로그처럼 한 파일에서 관리합니다.
enum CharacterSlotProductCatalog {
    /// 월 구독 상품입니다.
    /// 이 구독이 활성화되어 있으면 모든 유료 캐릭터 슬롯을 사용할 수 있습니다.
    static let allSlotsSubscriptionProductID = "com.chk.posturepet.characters.all.monthly"

    /// 개별 슬롯 영구 구매 상품입니다.
    /// 슬롯 1, 2는 무료라서 StoreKit 상품을 만들지 않습니다.
    private static let permanentSlotProductIDs: [UUID: String] = [
        UUID(uuidString: "00000000-0000-0000-0000-000000000003")!: "com.chk.posturepet.characters.additionalSlot3.permanent",
        UUID(uuidString: "00000000-0000-0000-0000-000000000004")!: "com.chk.posturepet.characters.additionalSlot4.permanent"
    ]

    static var allProductIDs: Set<String> {
        Set(permanentSlotProductIDs.values)
            .union([allSlotsSubscriptionProductID])
    }

    static func permanentProductID(for slot: CharacterSlot) -> String? {
        permanentSlotProductIDs[slot.id]
    }

    static func slotID(forPermanentProductID productID: String) -> UUID? {
        permanentSlotProductIDs.first { $0.value == productID }?.key
    }
}
