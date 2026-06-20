import Foundation
import StoreKit

/// StoreKit과 직접 대화하는 서비스입니다.
///
/// ViewModel은 "슬롯을 구매해줘", "구매 내역을 복원해줘" 같은 요청만 보내고,
/// StoreKit의 `Product`, `Transaction`, 검증 결과 처리는 이 서비스가 담당합니다.
@MainActor
final class CharacterSlotPurchaseService {
    private var productsByID: [String: Product] = [:]

    /// App Store Connect 또는 Xcode StoreKit 테스트 설정에서 상품 정보를 불러옵니다.
    func loadProducts() async throws -> [String: String] {
        let products = try await Product.products(for: CharacterSlotProductCatalog.allProductIDs)
        productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
        return Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0.displayPrice) })
    }

    /// 개별 슬롯 영구 구매 또는 월 구독 구매를 시작합니다.
    func purchase(productID: String) async throws {
        guard let product = productsByID[productID] else {
            throw CharacterSlotPurchaseError.productUnavailable
        }

        let result = try await product.purchase()

        switch result {
        case .success(let verificationResult):
            let transaction = try verifiedTransaction(from: verificationResult)
            await transaction.finish()
        case .userCancelled:
            throw CharacterSlotPurchaseError.userCancelled
        case .pending:
            throw CharacterSlotPurchaseError.pending
        @unknown default:
            throw CharacterSlotPurchaseError.unknown
        }
    }

    /// 사용자의 Apple ID에 남아 있는 구매 권한을 다시 가져옵니다.
    func restorePurchases() async throws {
        try await AppStore.sync()
    }

    /// 현재 StoreKit이 알려주는 유효한 구매 권한을 앱 내부 권한 모델로 변환합니다.
    func currentEntitlements() async -> CharacterSlotEntitlements {
        var permanentlyUnlockedSlotIDs = Set<UUID>()
        var isAllSlotsSubscriptionActive = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }

            if transaction.productID == CharacterSlotProductCatalog.allSlotsSubscriptionProductID {
                isAllSlotsSubscriptionActive = true
            }

            if let slotID = CharacterSlotProductCatalog.slotID(forPermanentProductID: transaction.productID) {
                permanentlyUnlockedSlotIDs.insert(slotID)
            }
        }

        return CharacterSlotEntitlements(
            permanentlyUnlockedSlotIDs: permanentlyUnlockedSlotIDs,
            isAllSlotsSubscriptionActive: isAllSlotsSubscriptionActive
        )
    }

    /// 앱 실행 중 다른 기기/시스템에서 거래 상태가 바뀌면 앱 설정도 따라 갱신합니다.
    func startTransactionListener(
        onChange: @escaping @MainActor () async -> Void
    ) -> Task<Void, Never> {
        Task {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                await onChange()
            }
        }
    }

    private func verifiedTransaction(
        from result: VerificationResult<Transaction>
    ) throws -> Transaction {
        switch result {
        case .verified(let transaction):
            return transaction
        case .unverified:
            throw CharacterSlotPurchaseError.failedVerification
        }
    }
}

enum CharacterSlotPurchaseError: LocalizedError {
    case productUnavailable
    case failedVerification
    case userCancelled
    case pending
    case unknown

    var errorDescription: String? {
        switch self {
        case .productUnavailable:
            return "구매 정보를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.".posturePetLocalized
        case .failedVerification:
            return "구매 검증에 실패했어요. 잠시 후 다시 시도해 주세요.".posturePetLocalized
        case .userCancelled:
            return "구매를 취소했어요.".posturePetLocalized
        case .pending:
            return "구매 승인을 기다리고 있어요. 승인되면 자동으로 반영돼요.".posturePetLocalized
        case .unknown:
            return "알 수 없는 구매 상태예요. 잠시 후 다시 시도해 주세요.".posturePetLocalized
        }
    }
}
