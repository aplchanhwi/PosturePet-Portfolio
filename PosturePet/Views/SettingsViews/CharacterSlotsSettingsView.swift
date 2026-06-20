import SwiftUI

struct CharacterSlotsSettingsView: View {
    /// 설정 창 전체에서 같은 ViewModel을 공유합니다.
    /// 캐릭터 슬롯도 앱 설정의 일부라서 여기서 ViewModel을 새로 만들지 않습니다.
    @ObservedObject var viewModel: AppViewModel

    /// macOS 설정창에서는 iOS처럼 화면을 깊게 push하기보다,
    /// 특정 항목을 고칠 때 작은 sheet를 띄우는 패턴이 자연스럽습니다.
    @State private var editingSlot: EditingSlot?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("캐릭터")
                .font(.title2.bold())

            monetizationSummary

            List {
                ForEach(viewModel.settings.characterSlots) { slot in
                    characterSlotRow(slot)
                }
            }
            .listStyle(.inset)
        }
        .padding(24)
        .sheet(item: $editingSlot) { editingSlot in
            CharacterSlotEditorView(
                viewModel: viewModel,
                slotID: editingSlot.id
            )
        }
    }

    /// 지금은 무료 슬롯 2개와 잠긴 유료 슬롯을 같은 row 구조로 보여줍니다.
    /// 잠긴 슬롯은 UI만 미리 만들어두고, 실제 액션 버튼은 비활성화합니다.
    private func characterSlotRow(_ slot: CharacterSlot) -> some View {
        let isProcessing = viewModel.isProcessingCharacterSlot(slot)
        let isUnlocked = viewModel.isCharacterSlotUnlocked(slot)

        return HStack(spacing: 16) {
            ZStack {
                PosturePetCharacterView(characterSkin: slot.character)
                    .frame(width: 88, height: 88)
                    .opacity(isUnlocked ? isProcessing ? 0.45 : 1 : 0.35)

                if isProcessing {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .frame(width: 88, height: 88)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(slot.localizedName)
                        .font(.headline)

                    statusLabel(for: slot)
                }

                Text(slotDescription(for: slot))
                    .foregroundStyle(.secondary)

                if isUnlocked,
                   !isProcessing,
                   let message = viewModel.characterImportErrorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Spacer()

            slotActions(for: slot)
        }
        .padding(.vertical, 8)
    }

    /// row 오른쪽에는 슬롯 단위의 핵심 액션만 둡니다.
    /// 사진 등록, 배경 제거, 얼굴/어깨 맞춤 같은 세부 작업은 `편집` sheet 안에서 처리합니다.
    @ViewBuilder
    private func slotActions(for slot: CharacterSlot) -> some View {
        let isProcessing = viewModel.isProcessingCharacterSlot(slot)
        let isUnlocked = viewModel.isCharacterSlotUnlocked(slot)

        VStack(alignment: .trailing, spacing: 8) {
            if isUnlocked {
                actionButton(
                    (viewModel.isSelectedCharacterSlot(slot) ? "사용 중" : "사용").posturePetLocalized,
                    isDisabled: isProcessing || viewModel.isSelectedCharacterSlot(slot)
                ) {
                    viewModel.selectCharacterSlot(slot)
                }

                actionButton("편집".posturePetLocalized, isDisabled: isProcessing) {
                    editingSlot = EditingSlot(id: slot.id)
                }

                actionButton("미리보기".posturePetLocalized, isDisabled: isProcessing) {
                    viewModel.previewCharacterSlot(slot)
                }
            } else {
                actionButton(
                    permanentPurchaseButtonTitle(for: slot),
                    isDisabled: !viewModel.canPurchasePermanentAccess(to: slot)
                ) {
                    viewModel.purchasePermanentAccess(to: slot)
                }

                actionButton(
                    subscriptionButtonTitle,
                    isDisabled: !viewModel.canSubscribeToAllCharacterSlots
                ) {
                    viewModel.subscribeToAllCharacterSlots()
                }
            }
        }
    }

    /// macOS 기본 Button은 바깥 `.frame(width:)`만으로는 배경 폭이 일정하지 않을 수 있습니다.
    /// 그래서 버튼 라벨인 `Text`에 직접 고정 폭을 줍니다.
    private func actionButton(
        _ title: String,
        width: CGFloat = 76,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .frame(width: width)
        }
        .disabled(isDisabled)
    }

    @ViewBuilder
    private func statusLabel(for slot: CharacterSlot) -> some View {
        if viewModel.isProcessingCharacterSlot(slot) {
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.small)
                Text("처리 중")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
        } else if viewModel.isSelectedCharacterSlot(slot) {
            Text("사용 중")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        } else {
            Text(viewModel.accessState(for: slot).displayName)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private func slotDescription(for slot: CharacterSlot) -> String {
        if viewModel.isProcessingCharacterSlot(slot) {
            return "캐릭터 이미지를 준비하고 있어요.".posturePetLocalized
        }
        if !viewModel.isCharacterSlotUnlocked(slot) {
            return "슬롯을 열면 캐릭터를 하나 더 등록할 수 있어요.".posturePetLocalized
        }
        return slot.displayName
    }

    private var monetizationSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("모든 캐릭터 슬롯")
                        .font(.headline)
                    Text(subscriptionStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(subscriptionSummaryButtonTitle) {
                    viewModel.subscribeToAllCharacterSlots()
                }
                .disabled(!viewModel.canSubscribeToAllCharacterSlots)

                Button("구매 내역 복원") {
                    viewModel.restoreCharacterSlotPurchases()
                }
                .disabled(viewModel.characterSlotStoreState.isRestoringPurchases)
            }

            if viewModel.characterSlotStoreState.isLoadingProducts
                || viewModel.characterSlotStoreState.isRestoringPurchases {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text((viewModel.characterSlotStoreState.isRestoringPurchases ? "구매 내역을 불러오고 있어요." : "구매 정보를 불러오고 있어요.").posturePetLocalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let message = viewModel.characterSlotStoreState.message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var subscriptionSummaryButtonTitle: String {
        if viewModel.isPurchasingAllSlotsSubscription {
            return "처리 중...".posturePetLocalized
        }

        if let price = viewModel.allSlotsSubscriptionPrice {
            return posturePetLocalizedFormat("%@ / 월", price)
        }

        return "구독".posturePetLocalized
    }

    private var subscriptionButtonTitle: String {
        if viewModel.isPurchasingAllSlotsSubscription {
            return "처리 중".posturePetLocalized
        }

        return "전체 슬롯 사용".posturePetLocalized
    }

    private func permanentPurchaseButtonTitle(for slot: CharacterSlot) -> String {
        if viewModel.isPurchasingPermanentAccess(to: slot) {
            return "처리 중".posturePetLocalized
        }

        if let price = viewModel.permanentPurchasePrice(for: slot) {
            return price
        }

        return "슬롯 열기".posturePetLocalized
    }

    private var subscriptionStatusText: String {
        if viewModel.settings.characterSlotEntitlements.isAllSlotsSubscriptionActive {
            return "모든 캐릭터 슬롯을 사용할 수 있어요.".posturePetLocalized
        }

        if let price = viewModel.allSlotsSubscriptionPrice {
            return posturePetLocalizedFormat("월 %@로 모든 캐릭터 슬롯을 사용할 수 있어요.", price)
        }

        return "구독하면 모든 캐릭터 슬롯을 사용할 수 있어요.".posturePetLocalized
    }
}

/// `.sheet(item:)`에 넘기기 위한 작은 식별자입니다.
/// UUID 자체를 바로 sheet item으로 쓰기 어렵기 때문에, Identifiable 래퍼를 하나 둡니다.
private struct EditingSlot: Identifiable {
    let id: UUID
}
