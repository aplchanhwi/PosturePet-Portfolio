import SwiftUI

struct StretchOverlayPreview: View {
    let routine: StretchRoutine
    let characterSkin: CharacterSkin?

    init(routine: StretchRoutine, characterSkin: CharacterSkin? = nil) {
        self.routine = routine
        self.characterSkin = characterSkin
    }

    var body: some View {
        VStack(spacing: 12) {
            PosturePetCharacterView(characterSkin: characterSkin, routine: routine)
                .frame(width: 150, height: 150)

            VStack(spacing: 4) {
                Text(routine.name)
                    .font(.headline)
                Text(routine.instruction)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
