import Foundation

/// 캐릭터 슬롯 구매 UI가 보여줄 StoreKit 상태입니다.
///
/// 실제 `Product` 타입은 StoreKit 전용 타입이라 View에 직접 넘기지 않고,
/// View가 필요한 가격 문자열과 진행 상태만 가볍게 들고 있습니다.
struct CharacterSlotStoreState: Equatable {
    var isLoadingProducts = false
    var displayPricesByProductID: [String: String] = [:]
    var purchasingProductID: String?
    var isRestoringPurchases = false
    var message: String?

    var hasLoadedProducts: Bool {
        !displayPricesByProductID.isEmpty
    }

    func displayPrice(for productID: String?) -> String? {
        guard let productID else { return nil }
        return displayPricesByProductID[productID]
    }

    func hasLoadedProduct(_ productID: String?) -> Bool {
        guard let productID else { return false }
        return displayPricesByProductID[productID] != nil
    }
}

