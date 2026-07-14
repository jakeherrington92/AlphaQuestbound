import SwiftUI

struct CharacterVaultView: View {
    @EnvironmentObject private var saveStore: SaveStore
    @State private var slotPendingDeletion: SaveSlot?

    var body: some View {
        ZStack {
            QuestboundTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Character Vault")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)
                        Text("Four local hero slots for this device.")
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    .padding(.top, 12)

                    VStack(spacing: 12) {
                        ForEach(saveStore.slots) { slot in
                            VaultSlotCard(
                                slot: slot,
                                onPlay: {
                                    saveStore.markPlayed(slotID: slot.id)
                                },
                                onDelete: {
                                    slotPendingDeletion = slot
                                }
                            )
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Vault")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Hero?", isPresented: deletePromptPresented) {
            Button("Delete", role: .destructive) {
                if let slotPendingDeletion {
                    saveStore.clearSlot(slotPendingDeletion.id)
                }
                slotPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                slotPendingDeletion = nil
            }
        } message: {
            Text("This will remove \(slotPendingDeletion?.hero?.name ?? "this hero") from Slot \(slotPendingDeletion?.id ?? 0).")
        }
    }

    private var deletePromptPresented: Binding<Bool> {
        Binding(
            get: { slotPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    slotPendingDeletion = nil
                }
            }
        )
    }
}

private struct VaultSlotCard: View {
    let slot: SaveSlot
    let onPlay: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                PortraitBadge(option: slot.hero?.portrait)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Slot \(slot.id)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    if let hero = slot.hero {
                        Text(hero.name)
                            .font(.headline)
                        Text("\(hero.origin.rawValue) • \(hero.path.rawValue)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)

                        VStack(alignment: .leading, spacing: 4) {
                            if let subpath = hero.subpath, !subpath.isEmpty {
                                detail("Subpath", subpath)
                            }
                            detail("Level", "\(hero.level)")
                            detail("Gold", "\(hero.gold)")
                            detail("Location", hero.currentLocation)
                            detail("Last Played", hero.lastPlayedAt.formatted(date: .abbreviated, time: .shortened))
                        }
                        .font(.caption)
                        .padding(.top, 2)
                    } else {
                        Text("Empty Slot — Create Hero")
                            .font(.headline)
                        Text("Start a new local hero save.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                if slot.hero != nil {
                    NavigationLink {
                        GreywickHubView(slotID: slot.id)
                            .onAppear(perform: onPlay)
                    } label: {
                        Label("Play", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }

                    NavigationLink {
                        CharacterSheetPreviewView(slotID: slot.id)
                    } label: {
                        Label("View Sheet", systemImage: "doc.text.magnifyingglass")
                            .frame(maxWidth: .infinity)
                    }

                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .frame(width: 34, height: 34)
                    }
                    .accessibilityLabel("Delete")
                } else {
                    NavigationLink {
                        HeroCreationView(slotID: slot.id)
                    } label: {
                        Label("Create Hero", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .buttonStyle(.bordered)
            .tint(QuestboundTheme.accent)
        }
        .padding(16)
        .background(QuestboundTheme.card)
        .questboundParchmentText()
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(QuestboundTheme.border, lineWidth: 1)
        }
    }

    private func detail(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label + ":")
                .foregroundStyle(.secondary)
            Text(value)
                .fontWeight(.semibold)
        }
    }
}

struct PortraitBadge: View {
    let option: PortraitOption?

    var body: some View {
        ZStack {
            Circle()
                .fill(QuestboundTheme.portraitFill(for: option))
            Text(option?.initials ?? "+")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
        }
        .frame(width: 56, height: 56)
        .accessibilityHidden(true)
    }
}

enum QuestboundTheme {
    static let background = Color(red: 0.12, green: 0.13, blue: 0.12)
    static let card = Color(red: 0.96, green: 0.92, blue: 0.84)
    static let border = Color(red: 0.35, green: 0.26, blue: 0.16).opacity(0.35)
    static let accent = Color(red: 0.59, green: 0.20, blue: 0.16)
    static let cardText = Color(red: 0.12, green: 0.10, blue: 0.08)

    static func portraitFill(for option: PortraitOption?) -> Color {
        switch option {
        case .bladeguardBaseMale, .bladeguardBaseFemale,
                .ironVanguardMale, .ironVanguardFemale,
                .stormDuelistMale, .stormDuelistFemale:
            return Color(red: 0.68, green: 0.38, blue: 0.12)
        case .shadowstepBaseMale, .shadowstepBaseFemale,
                .nightbladeMale, .nightbladeFemale,
                .trickhandMale, .trickhandFemale:
            return Color(red: 0.34, green: 0.36, blue: 0.38)
        case .wildwardenBaseMale, .wildwardenBaseFemale,
                .beastcallerMale, .beastcallerFemale,
                .deepwoodArcherMale, .deepwoodArcherFemale:
            return Color(red: 0.24, green: 0.45, blue: 0.30)
        case .embermageBaseMale, .embermageBaseFemale,
                .flamecallerMale, .flamecallerFemale,
                .starweaverMale, .starweaverFemale:
            return Color(red: 0.22, green: 0.36, blue: 0.57)
        case .oathkeeperBaseMale, .oathkeeperBaseFemale,
                .dawnshieldMale, .dawnshieldFemale,
                .judgementFlameMale, .judgementFlameFemale:
            return Color(red: 0.59, green: 0.20, blue: 0.16)
        case nil:
            return Color(red: 0.42, green: 0.25, blue: 0.18)
        }
    }
}

extension View {
    func questboundParchmentText() -> some View {
        foregroundStyle(QuestboundTheme.cardText)
            .environment(\.colorScheme, .light)
    }
}
