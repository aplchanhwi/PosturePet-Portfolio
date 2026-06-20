import AppKit
import Foundation
import Combine

/// 앱 전체 상태를 관리하는 ViewModel입니다.
///
/// MVVM에서 ViewModel은 화면과 서비스 사이의 중간 관리자입니다.
/// View는 버튼 클릭을 ViewModel에 전달하고,
/// ViewModel은 서비스에게 일을 시키고,
/// 바뀐 상태를 다시 View가 표시합니다.
@MainActor
final class AppViewModel: ObservableObject {
    
    enum SettingsTab: Hashable {
        case general
        case overlay
        case characters
        case runningApps
    }
    
    /// 사용자가 설정 창에서 바꾸는 값입니다.
    @Published var settings: PosturePetSettings {
        didSet {
            settingsStore.save(settings)
        }
    }
    
    /// 현재 선택된 스트레칭 루틴입니다.
    @Published var selectedRoutine: StretchRoutine = .neckTilt
    
    /// 앱 사용량 감지 중인지 여부입니다.
    @Published var isMonitoring = false
    
    /// 설정 창과 메뉴바에 보여줄 현재 사용 상태입니다.
    @Published var usageState = AppUsageState(activeAppName: "알 수 없음".posturePetLocalized, elapsedFocusTime: 0, focusDuration: 25 * 60)
    
    @Published var runningApps: [RunningAppInfo] = []
    @Published var selectedRunningAppIDs: Set<String> = []
    
    @Published var isSnoozing = false
    
    @Published var isOverlayPresented = false
    
    @Published var characterImportErrorMessage: String?

    /// 캐릭터 슬롯 구매/구독 UI에 필요한 StoreKit 상태입니다.
    /// 가격 문자열, 구매 진행 중인 상품, 복원 중 여부처럼 화면 표시용 상태만 담습니다.
    @Published var characterSlotStoreState = CharacterSlotStoreState()

    /// 캐릭터 사진 등록이나 배경 제거처럼 시간이 걸리는 작업 중인 슬롯입니다.
    /// nil이면 현재 처리 중인 슬롯이 없다는 뜻입니다.
    @Published var processingCharacterSlotID: UUID?
    
    /// 사용자가 마지막으로 선택한 스누즈 시간입니다.
    /// `StretchOverlayView`는 오버레이가 닫힐 때 사라지므로, 다음 오버레이에서도 유지해야 하는 값은 ViewModel이 기억합니다.
    private var selectedSnoozeMinutes = 5

    /// 현재 활성 앱과 사용 시간을 감지하는 서비스입니다.
    private let usageMonitor = AppUsageMonitor()
    
    /// 화면 위 오버레이 창을 띄우는 서비스입니다.
    private let overlayWindowManager = OverlayWindowManager()
    
    /// 1초마다 `usageMonitor`의 값을 읽어 ViewModel 상태로 옮기는 작업입니다.
    private var observationTask: Task<Void, Never>?
    
    private let settingsStore: SettingsStore
    
    private let runningApplicationProvider = RunningApplicationProvider()
    
    private let characterStore = CharacterStore()

    private let characterSlotPurchaseService = CharacterSlotPurchaseService()
    
    private var snoozeTask: Task<Void, Never>?

    private var transactionListenerTask: Task<Void, Never>?
    
    init(settingsStore: SettingsStore? = nil) {
        let settingsStore = settingsStore ?? SettingsStore()
        self.settingsStore = settingsStore
        self.settings = settingsStore.load()
        self.selectedRunningAppIDs = Set(self.settings.monitoredApps.map(\.id))
        self.usageState = AppUsageState(
            activeAppName: "알 수 없음".posturePetLocalized,
            elapsedFocusTime: 0,
            focusDuration: self.settings.focusDurationMinutes * 60
        )
        self.selectedRoutine = self.settings.selectedRoutine

        Task { [weak self] in
            await self?.prepareCharacterSlotStore()
        }

        startMonitoringIfNeededOnLaunch()
    }

    deinit {
        observationTask?.cancel()
        snoozeTask?.cancel()
        transactionListenerTask?.cancel()
    }
    
    /// 메뉴바에서 "시작"을 눌렀을 때 호출됩니다.
    func startMonitoring() {
        guard !isMonitoring else { return }

        isMonitoring = true
        /// 감지 대상 앱의 전체 정보를 넘깁니다.
        /// `AppUsageMonitor`는 bundleIdentifier가 있으면 그것을 우선 사용하고,
        /// 없을 때만 앱 이름을 fallback으로 비교합니다.
        usageMonitor.start(monitoredApps: settings.monitoredApps)
        observeUsage()
    }
    
    /// 메뉴바에서 "일시정지"를 눌렀을 때 호출됩니다.
    func pauseMonitoring() {
        isMonitoring = false
        isSnoozing = false
        isOverlayPresented = false
        snoozeTask?.cancel()
        snoozeTask = nil
        overlayWindowManager.hide()
        usageMonitor.stop()
        observationTask?.cancel()
        observationTask = nil
        usageState = makeUsageState()
    }

    private func startMonitoringIfNeededOnLaunch() {
        guard settings.shouldStartMonitoringOnLaunch else { return }
        startMonitoring()
    }
    
    /// 집중 타이머를 처음부터 다시 세고 싶을 때 사용합니다.
    func resetFocusTimer() {
        usageMonitor.resetElapsedTime()
        usageState = makeUsageState()
    }
    
    /// 메뉴바나 설정 창에서 바로 오버레이를 확인할 때 사용합니다.
    func startBreakNow() {
        showOverlay()
    }

    func resetOverlayWindowSettings() {
        setOverlayWindowSettings(.defaults)
    }

    func selectRoutine(_ routine: StretchRoutine) {
        /// Picker가 SwiftUI View를 갱신하는 중에 @Published 값을 바로 바꾸면
        /// "Publishing changes from within view updates" 경고가 날 수 있습니다.
        /// 다음 메인 루프에서 앱 상태와 저장 설정을 함께 바꿔 그 타이밍을 피합니다.
        DispatchQueue.main.async { [weak self] in
            self?.selectedRoutine = routine
            self?.settings.selectedRoutineID = routine.id
        }
    }

    func setOverlayWindowSize(_ size: OverlayWindowSize) {
        DispatchQueue.main.async { [weak self] in
            self?.settings.overlayWindow.size = size
        }
    }

    func setOverlayWindowPosition(_ position: OverlayWindowPosition) {
        DispatchQueue.main.async { [weak self] in
            self?.settings.overlayWindow.position = position
        }
    }

    private func setOverlayWindowSettings(_ overlayWindow: OverlayWindowSettings) {
        DispatchQueue.main.async { [weak self] in
            self?.settings.overlayWindow = overlayWindow
        }
    }
    
    /// 앱 종료 버튼에서 호출됩니다.
    func quit() {
        NSApp.terminate(nil)
    }
    
    func refreshRunningApps() {
        runningApps = runningApplicationProvider.fetchRunningApps()
    }
    
    func toggleRunningApp(_ app: RunningAppInfo) {
        if selectedRunningAppIDs.contains(app.id) {
            selectedRunningAppIDs.remove(app.id)
        } else {
            selectedRunningAppIDs.insert(app.id)
        }
        
        /// 설정에는 선택된 앱의 전체 정보(id, 이름, bundleIdentifier)를 저장합니다.
        /// 그래야 앱을 다시 켰을 때 왼쪽 체크 상태를 복원할 수 있습니다.
        settings.monitoredApps = runningApps
            .filter { selectedRunningAppIDs.contains($0.id) }
    }
    
    var selectedCharacterSkin: CharacterSkin? {
        settings.selectedCharacterSkin
    }

    func accessState(for slot: CharacterSlot) -> CharacterSlotAccessState {
        if slot.access == .free {
            return .free
        }

        if settings.characterSlotEntitlements.permanentlyUnlockedSlotIDs.contains(slot.id) {
            return .permanent
        }

        if settings.characterSlotEntitlements.isAllSlotsSubscriptionActive {
            return .subscription
        }

        return .locked
    }

    func isCharacterSlotUnlocked(_ slot: CharacterSlot) -> Bool {
        accessState(for: slot).isUnlocked
    }

    func permanentPurchasePrice(for slot: CharacterSlot) -> String? {
        characterSlotStoreState.displayPrice(
            for: CharacterSlotProductCatalog.permanentProductID(for: slot)
        )
    }

    var allSlotsSubscriptionPrice: String? {
        characterSlotStoreState.displayPrice(
            for: CharacterSlotProductCatalog.allSlotsSubscriptionProductID
        )
    }

    func canPurchasePermanentAccess(to slot: CharacterSlot) -> Bool {
        guard !isCharacterSlotUnlocked(slot),
              let productID = CharacterSlotProductCatalog.permanentProductID(for: slot) else {
            return false
        }

        return characterSlotStoreState.hasLoadedProduct(productID)
            && characterSlotStoreState.purchasingProductID == nil
            && !characterSlotStoreState.isRestoringPurchases
    }

    var canSubscribeToAllCharacterSlots: Bool {
        !settings.characterSlotEntitlements.isAllSlotsSubscriptionActive
            && characterSlotStoreState.hasLoadedProduct(CharacterSlotProductCatalog.allSlotsSubscriptionProductID)
            && characterSlotStoreState.purchasingProductID == nil
            && !characterSlotStoreState.isRestoringPurchases
    }

    func isPurchasingPermanentAccess(to slot: CharacterSlot) -> Bool {
        guard let productID = CharacterSlotProductCatalog.permanentProductID(for: slot) else {
            return false
        }

        return characterSlotStoreState.purchasingProductID == productID
    }

    var isPurchasingAllSlotsSubscription: Bool {
        characterSlotStoreState.purchasingProductID == CharacterSlotProductCatalog.allSlotsSubscriptionProductID
    }

    func purchasePermanentAccess(to slot: CharacterSlot) {
        guard canPurchasePermanentAccess(to: slot),
              let productID = CharacterSlotProductCatalog.permanentProductID(for: slot) else {
            return
        }

        purchaseCharacterSlotProduct(productID)
    }

    func subscribeToAllCharacterSlots() {
        guard canSubscribeToAllCharacterSlots else { return }
        purchaseCharacterSlotProduct(CharacterSlotProductCatalog.allSlotsSubscriptionProductID)
    }

    func restoreCharacterSlotPurchases() {
        guard !characterSlotStoreState.isRestoringPurchases else { return }

        characterSlotStoreState.isRestoringPurchases = true
        characterSlotStoreState.message = nil

        Task { [weak self] in
            guard let self else { return }

            do {
                try await characterSlotPurchaseService.restorePurchases()
                await refreshCharacterSlotEntitlements(successMessage: "구매 내역을 복원했어요.".posturePetLocalized)
            } catch {
                characterSlotStoreState.message = error.localizedDescription
            }

            characterSlotStoreState.isRestoringPurchases = false
        }
    }
    
    func isSelectedCharacterSlot(_ slot: CharacterSlot) -> Bool {
        settings.selectedCharacterSlotID == slot.id
    }
    
    func isProcessingCharacterSlot(_ slot: CharacterSlot) -> Bool {
        processingCharacterSlotID == slot.id
    }
    
    func selectCharacterSlot(_ slot: CharacterSlot) {
        guard isCharacterSlotUnlocked(slot), !isProcessingCharacterSlot(slot) else { return }
        setSelectedCharacterSlotID(slot.id)
    }
    
    func previewCharacterSlot(_ slot: CharacterSlot) {
        guard isCharacterSlotUnlocked(slot), !isProcessingCharacterSlot(slot) else { return }
        /// SwiftUI List row를 갱신하는 중에 @Published 값을 바로 바꾸면
        /// "Publishing changes from within view updates" 경고가 날 수 있습니다.
        /// 다음 메인 루프에서 선택 변경과 오버레이 표시를 처리해 그 타이밍을 피합니다.
        DispatchQueue.main.async { [weak self] in
            self?.settings.selectedCharacterSlotID = slot.id
            self?.startBreakNow()
        }
    }
    
    private func setSelectedCharacterSlotID(_ id: UUID) {
        DispatchQueue.main.async { [weak self] in
            self?.settings.selectedCharacterSlotID = id
        }
    }
    
    /// 설정 화면의 `사진 등록` 또는 `사진 변경` 버튼에서 호출됩니다.
    /// macOS 파일 선택 창은 AppKit 기능이므로 CharacterStore 서비스에 맡깁니다.
    func pickCharacterImage(for slot: CharacterSlot) {
        guard isCharacterSlotUnlocked(slot), !isProcessingCharacterSlot(slot) else { return }
        
        do {
            guard let character = try characterStore.pickAndImportImage(replacing: slot.character) else {
                return
            }
            
            processingCharacterSlotID = slot.id
            characterImportErrorMessage = nil
            
            Task { [weak self] in
                await Task.yield()
                do {
                    let finalCharacter = try await Task.detached(priority: .userInitiated) {
                        try CharacterBackgroundRemovalService.removeBackground(from: character)
                    }.value
                    self?.finishImportingCharacter(finalCharacter, for: slot.id, errorMessage: nil)
                } catch {
                    self?.finishImportingCharacter(
                        character,
                        for: slot.id,
                        errorMessage: "사진은 등록했지만 배경을 지우지 못했어요. 배경 제거 다시 시도를 눌러볼 수 있어요.".posturePetLocalized
                    )
                }
            }
        } catch {
            characterImportErrorMessage = error.localizedDescription
        }
    }
    
    func resetCharacterImage(for slot: CharacterSlot) {
        guard isCharacterSlotUnlocked(slot), !isProcessingCharacterSlot(slot) else { return }
        
        if let character = slot.character {
            characterStore.deleteImage(for: character)
        }
        characterImportErrorMessage = nil
        updateCharacterSlot(slot.id) { characterSlot in
            characterSlot.character = nil
        }
    }
    
    func removeBackground(for slot: CharacterSlot) {
        guard isCharacterSlotUnlocked(slot),
              !isProcessingCharacterSlot(slot),
              let character = slot.character else { return }
        
        processingCharacterSlotID = slot.id
        characterImportErrorMessage = nil
        
        Task { [weak self] in
            await Task.yield()
            do {
                let updatedCharacter = try await Task.detached(priority: .userInitiated) {
                    try CharacterBackgroundRemovalService.removeBackground(from: character)
                }.value
                self?.finishRemovingBackground(updatedCharacter, for: slot.id, errorMessage: nil)
            } catch {
                self?.finishRemovingBackground(nil, for: slot.id, errorMessage: error.localizedDescription)
            }
        }
    }
    
    private func finishImportingCharacter(
        _ character: CharacterSkin,
        for slotID: UUID,
        errorMessage: String?
    ) {
        defer {
            processingCharacterSlotID = nil
        }
        
        characterImportErrorMessage = errorMessage
        updateCharacterSlot(slotID) { characterSlot in
            characterSlot.character = character
        }
        setSelectedCharacterSlotID(slotID)
    }
    
    private func finishRemovingBackground(
        _ character: CharacterSkin?,
        for slotID: UUID,
        errorMessage: String?
    ) {
        defer {
            processingCharacterSlotID = nil
        }
        
        if let character {
            characterImportErrorMessage = nil
            updateCharacterSlot(slotID) { characterSlot in
                characterSlot.character = character
            }
            setSelectedCharacterSlotID(slotID)
        } else {
            characterImportErrorMessage = errorMessage
        }
    }
    
    /// 사용자가 맞춘 얼굴/목/어깨 위치를 슬롯의 캐릭터 정보에 저장합니다.
    /// `settings`가 @Published라서 이 값을 바꾸면 SettingsStore가 UserDefaults에도 저장합니다.
    func updateCharacterRig(for slotID: UUID, rig: CharacterRig) {
        characterImportErrorMessage = nil
        updateCharacterSlot(slotID) { characterSlot in
            characterSlot.character?.rig = rig
        }
        setSelectedCharacterSlotID(slotID)
    }
    
    private func updateCharacterSlot(_ id: UUID, update: (inout CharacterSlot) -> Void) {
        guard let index = settings.characterSlots.firstIndex(where: { $0.id == id }) else { return }
        update(&settings.characterSlots[index])
    }

    private func prepareCharacterSlotStore() async {
        await loadCharacterSlotProducts()
        await refreshCharacterSlotEntitlements(successMessage: nil)

        transactionListenerTask?.cancel()
        transactionListenerTask = characterSlotPurchaseService.startTransactionListener { [weak self] in
            await self?.refreshCharacterSlotEntitlements(successMessage: nil)
        }
    }

    private func loadCharacterSlotProducts() async {
        characterSlotStoreState.isLoadingProducts = true
        characterSlotStoreState.message = nil

        do {
            let displayPricesByProductID = try await characterSlotPurchaseService.loadProducts()
            characterSlotStoreState.displayPricesByProductID = displayPricesByProductID

            if displayPricesByProductID.isEmpty {
                characterSlotStoreState.message = "구매 정보를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.".posturePetLocalized
            }
        } catch {
            characterSlotStoreState.message = error.localizedDescription
        }

        characterSlotStoreState.isLoadingProducts = false
    }

    private func purchaseCharacterSlotProduct(_ productID: String) {
        characterSlotStoreState.purchasingProductID = productID
        characterSlotStoreState.message = nil

        Task { [weak self] in
            guard let self else { return }

            do {
                try await characterSlotPurchaseService.purchase(productID: productID)
                await refreshCharacterSlotEntitlements(successMessage: "구매가 반영됐어요.".posturePetLocalized)
            } catch {
                characterSlotStoreState.message = error.localizedDescription
            }

            characterSlotStoreState.purchasingProductID = nil
        }
    }

    private func refreshCharacterSlotEntitlements(successMessage: String?) async {
        let storeEntitlements = await characterSlotPurchaseService.currentEntitlements()

        /// 개발 중 StoreKit 상품이 아직 연결되지 않은 상태에서는
        /// `currentEntitlements`가 비어 있을 수 있습니다.
        /// 이때 기존 로컬 권한을 빈 값으로 덮어쓰면 테스트 중 열어둔 슬롯이 갑자기 잠길 수 있어서,
        /// 상품을 하나도 불러오지 못했고 StoreKit 권한도 비어 있으면 현재 설정을 유지합니다.
        let shouldKeepCurrentEntitlements =
            !characterSlotStoreState.hasLoadedProducts
            && storeEntitlements == .defaults

        guard !shouldKeepCurrentEntitlements else {
            if let successMessage {
                characterSlotStoreState.message = successMessage
            }
            return
        }

        settings.characterSlotEntitlements = storeEntitlements
        ensureSelectedCharacterSlotIsUnlocked()

        if let successMessage {
            characterSlotStoreState.message = successMessage
        }
    }

    private func ensureSelectedCharacterSlotIsUnlocked() {
        guard let selectedSlot = settings.characterSlots.first(where: { $0.id == settings.selectedCharacterSlotID }),
              !isCharacterSlotUnlocked(selectedSlot),
              let fallbackSlot = settings.characterSlots.first(where: { isCharacterSlotUnlocked($0) }) else {
            return
        }

        settings.selectedCharacterSlotID = fallbackSlot.id
    }
    
    /// 사용 시간 변화를 계속 관찰합니다.
    /// 집중 시간이 목표에 도달하면 오버레이를 띄우고 시간을 초기화합니다.
    private func observeUsage() {
        observationTask?.cancel()
        observationTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                usageState = makeUsageState()
                
                if !isSnoozing,
                   !isOverlayPresented,
                   settings.isAutomaticOverlayEnabled,
                   usageState.elapsedFocusTime >= usageState.focusDuration {
                    showOverlay()
                }
                
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
    
    /// 선택된 스트레칭 루틴으로 오버레이를 띄웁니다.
    private func showOverlay() {
        isOverlayPresented = true
        
        overlayWindowManager.show(
            routine: selectedRoutine,
            breakDuration: settings.breakDurationMinutes * 60,
            defaultSnoozeMinutes: selectedSnoozeMinutes,
            characterSkin: selectedCharacterSkin,
            overlaySettings: settings.overlayWindow
        ) {
            [weak self] action in
            self?.handleOverlayAction(action)
        }
    }
    
    /// Service가 가진 현재 값을 View에서 쓰기 좋은 `AppUsageState`로 바꿉니다.
    private func makeUsageState() -> AppUsageState {
        AppUsageState(
            activeAppName: usageMonitor.activeAppName,
            elapsedFocusTime: usageMonitor.elapsedFocusTime,
            focusDuration: settings.focusDurationMinutes * 60
        )
    }
    
    private func handleOverlayAction(_ action: StretchOverlayAction) {
        isOverlayPresented = false
        
        switch action {
        case .completed:
            isSnoozing = false
            snoozeTask?.cancel()
            usageMonitor.resetElapsedTime()
            usageState = makeUsageState()
        case .snoozed(let minutes):
            selectedSnoozeMinutes = minutes
            isSnoozing = true
            
            snoozeTask?.cancel()
            snoozeTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(minutes * 60))
                
                guard let self, !Task.isCancelled else { return }

                isSnoozing = false

                guard isMonitoring else { return }
                showOverlay()
            }
        }
    }
}
