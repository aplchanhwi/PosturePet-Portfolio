import SwiftUI

struct CharacterSlotEditorView: View {
    @ObservedObject var viewModel: AppViewModel
    let slotID: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var isAdjustingCharacter = false

    /// sheet가 열린 뒤에도 슬롯 내용은 바뀔 수 있습니다.
    /// 그래서 처음 받은 슬롯 값을 저장하지 않고, ViewModel의 최신 설정에서 매번 찾아옵니다.
    private var slot: CharacterSlot? {
        viewModel.settings.characterSlots.first { $0.id == slotID }
    }

    var body: some View {
        if let slot {
            if isAdjustingCharacter, let character = slot.character {
                CharacterRigAlignmentView(
                    character: character,
                    onCancel: {
                        isAdjustingCharacter = false
                    },
                    onSave: { rig in
                        viewModel.updateCharacterRig(for: slot.id, rig: rig)
                        isAdjustingCharacter = false
                    }
                )
                .padding(24)
                .frame(width: 560)
            } else {
                editorContent(for: slot)
            }
        } else {
            Text("슬롯을 찾을 수 없어요.")
                .padding(24)
        }
    }

    private func editorContent(for slot: CharacterSlot) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            editorHeader(for: slot)

            Divider()

            editorPreview(for: slot)

            Divider()

            editorActions(for: slot)

            HStack {
                Spacer()

                Button("닫기".posturePetLocalized) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(24)
        .frame(width: 440)
    }

    private func editorHeader(for slot: CharacterSlot) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Text(slot.localizedName)
                    .font(.title3.bold())

                Text(slot.displayName)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if viewModel.isProcessingCharacterSlot(slot) {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("처리 중".posturePetLocalized)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            } else if viewModel.isSelectedCharacterSlot(slot) {
                Text("사용 중".posturePetLocalized)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func editorPreview(for slot: CharacterSlot) -> some View {
        let isProcessing = viewModel.isProcessingCharacterSlot(slot)

        return HStack(spacing: 18) {
            ZStack {
                PosturePetCharacterView(characterSkin: slot.character)
                    .frame(width: 136, height: 136)
                    .opacity(isProcessing ? 0.45 : 1)

                if isProcessing {
                    ProgressView()
                        .controlSize(.large)
                }
            }
            .frame(width: 136, height: 136)

            VStack(alignment: .leading, spacing: 8) {
                Text("미리보기")
                    .font(.headline)

                Text(previewDescription(for: slot, isProcessing: isProcessing))
                    .foregroundStyle(.secondary)

                Button("움직임 보기".posturePetLocalized) {
                    viewModel.previewCharacterSlot(slot)
                }
                .disabled(isProcessing)
            }

            Spacer()
        }
    }

    private func editorActions(for slot: CharacterSlot) -> some View {
        let isProcessing = viewModel.isProcessingCharacterSlot(slot)

        return VStack(alignment: .leading, spacing: 18) {
            editorSection(title: "사진") {
                HStack(spacing: 8) {
                    Button((isProcessing ? "처리 중" : slot.character == nil ? "사진 고르기" : "사진 바꾸기").posturePetLocalized) {
                        viewModel.pickCharacterImage(for: slot)
                    }
                    .disabled(isProcessing)

                    if slot.character != nil {
                        Button("기본 캐릭터 사용".posturePetLocalized) {
                            viewModel.resetCharacterImage(for: slot)
                        }
                        .disabled(isProcessing)
                    }
                }
            }

            editorSection(title: "배경") {
                VStack(alignment: .leading, spacing: 6) {
                    Button((isProcessing ? "배경 제거 중" : "배경 제거 다시 시도").posturePetLocalized) {
                        viewModel.removeBackground(for: slot)
                    }
                    .disabled(slot.character == nil || isProcessing)

                    Text((isProcessing ? "이미지를 준비하는 중이에요." : "사진을 고르면 배경을 자동으로 지워요.").posturePetLocalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            editorSection(title: "맞춤") {
                Button("움직임 맞추기".posturePetLocalized) {
                    isAdjustingCharacter = true
                }
                .disabled(slot.character == nil || isProcessing)
            }

            if let message = viewModel.characterImportErrorMessage, !isProcessing {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func previewDescription(for slot: CharacterSlot, isProcessing: Bool) -> String {
        if isProcessing {
            return "캐릭터를 준비하는 중이에요.".posturePetLocalized
        }
        return (slot.character == nil ? "기본 실루엣" : "등록된 이미지").posturePetLocalized
    }

    private func editorSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.posturePetLocalized)
                .font(.headline)

            content()
        }
    }
}
