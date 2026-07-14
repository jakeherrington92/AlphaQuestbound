import SwiftUI

struct AdventureRoomView: View {
    @EnvironmentObject private var saveStore: SaveStore
    @Environment(\.dismiss) private var dismiss

    let slotID: Int
    let startAdventureID: String?
    let onExitToGreywick: (() -> Void)?

    @State private var skillResultText: String?
    @State private var showExitPrompt = false
    @State private var completionReward: AdventureCompletionReward?
    @State private var completedAdventure: AdventureDefinition?
    @State private var outcomePopup: OutcomeResult?
    @State private var didHandleStartRequest = false

    init(slotID: Int, startAdventureID: String? = nil, onExitToGreywick: (() -> Void)? = nil) {
        self.slotID = slotID
        self.startAdventureID = startAdventureID
        self.onExitToGreywick = onExitToGreywick
    }

    private var hero: Hero? {
        saveStore.slots.first(where: { $0.id == slotID })?.hero
    }

    private var adventure: AdventureDefinition? {
        hero?.currentAdventureState.adventureID.flatMap(AdventureEngine.adventure(id:))
    }

    private var room: AdventureRoomDefinition? {
        hero.flatMap(AdventureEngine.currentRoom(for:))
    }

    var body: some View {
        ZStack {
            QuestboundTheme.background.ignoresSafeArea()

            ScrollView {
                if let hero, let adventure, let room {
                    VStack(alignment: .leading, spacing: 16) {
                        TutorialTipView(tip: .adventureRoom)
                        roomHeader(hero: hero, adventure: adventure, room: room)
                        helpCard
                        roomBody(hero: hero, room: room)
                        adventureLogCard(hero)
                        saveExitCard
                    }
                    .padding(20)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("No active adventure.")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        Text("Start or resume an adventure from the Adventure Board in Greywick.")
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle(adventure?.title ?? "Adventure")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: startIfNeeded)
        .alert("Exit Adventure", isPresented: $showExitPrompt) {
            Button("Save and Exit") {
                saveStore.saveAdventureProgress(slotID: slotID)
                exitToGreywick()
            }
            Button("Exit Without Saving", role: .destructive) {
                exitToGreywick()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Save and Exit preserves your current room and adventure state. Exit Without Saving returns to Greywick without an additional save; recent unsaved progress may be lost.")
        }
        .navigationDestination(item: Binding(
            get: { completedAdventure.map { AdventureCompletionRoute(adventure: $0) } },
            set: { if $0 == nil { completedAdventure = nil } }
        )) { route in
            if let completionReward {
                AdventureCompleteView(
                    slotID: slotID,
                    adventure: route.adventure,
                    reward: completionReward
                )
            }
        }
        .sheet(item: $outcomePopup) { outcome in
            OutcomePopupView(outcome: outcome) {
                outcomePopup = nil
            }
        }
    }

    private func startIfNeeded() {
        guard !didHandleStartRequest else { return }
        didHandleStartRequest = true
        guard let startAdventureID,
              let adventure = AdventureEngine.adventure(id: startAdventureID),
              let hero,
              !hero.currentAdventureState.isActive else { return }
        saveStore.startAdventure(adventure, in: slotID)
    }

    private func roomHeader(hero: Hero, adventure: AdventureDefinition, room: AdventureRoomDefinition) -> some View {
        roomCard(room.title) {
            detailRow("Type", room.type.displayName)
            detailRow("Room", roomProgress(hero: hero, adventure: adventure, room: room))
            detailRow("HP", "\(hero.currentHealth) / \(hero.maxHealth)")
            if hero.maxFocus > 0 {
                detailRow("Focus", "\(hero.currentFocus) / \(hero.maxFocus)")
            }
            if hero.maxStamina > 0 {
                detailRow("Stamina", "\(hero.currentStamina) / \(hero.maxStamina)")
            }
            Text(room.description)
                .foregroundStyle(.secondary)
        }
    }

    private var helpCard: some View {
        roomCard("Help") {
            Text("Choices and skill checks can change rewards, damage or future room bonuses. Save / Exit lets you preserve the current adventure and return to Greywick.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func roomBody(hero: Hero, room: AdventureRoomDefinition) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if !room.choices.isEmpty {
                roomCard("Choices") {
                    ForEach(room.choices) { choice in
                        Button {
                            resolveChoice(choice, roomID: room.id)
                        } label: {
                            Text(choice.text)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }

            if !room.skillChecks.isEmpty {
                roomCard("Skill Checks") {
                    ForEach(room.skillChecks) { check in
                        Button {
                            resolveSkillCheck(check, roomID: room.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(skillCheckTitle(check))
                                    .font(.subheadline.weight(.semibold))
                                Text(check.skill.usageDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    if let skillResultText {
                        Text(skillResultText)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if room.type == .combat || room.type == .boss {
                roomCard("Combat") {
                    if room.enemyIDs.isEmpty {
                        Text("Combat hook ready. Enemies will be added in Milestone 12.")
                            .foregroundStyle(.secondary)
                    } else {
                        if hero.currentAdventureState.defeatedEnemyIDs.contains(room.id) {
                            Text("Combat completed.")
                                .foregroundStyle(.secondary)
                            if room.id == "rat-nest", !hero.currentAdventureState.collectedRewardIDs.contains("rat-nest-search") {
                                Button {
                                    resolveRatNestSearch(roomID: room.id)
                                } label: {
                                    Text("Search the Nest: Awareness vs Standard 12")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                            } else if room.nextRoomID != nil {
                                Button {
                                    move(to: room.nextRoomID, completing: room.id)
                                } label: {
                                    Text("Continue")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        } else {
                            NavigationLink {
                                CombatView(
                                    slotID: slotID,
                                    encounterID: room.id,
                                    title: room.title,
                                    enemyIDs: combatEnemyIDs(for: room, hero: hero),
                                    onRewardComplete: {
                                        completeCombatRoom(room)
                                    },
                                    onDefeat: {
                                        saveStore.applyAdventureDefeat(slotID: slotID)
                                    },
                                    onEscape: {
                                        saveStore.abandonAdventure(slotID: slotID)
                                    }
                                )
                            } label: {
                                Text("Start Combat")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)

                            DisclosureGroup {
                                Text("Debug only. Skips this required fight with no enemy XP, gold, loot or Boss Fortune Roll.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Button {
                                    developerSkipCombat(room)
                                } label: {
                                    Label("Developer: Skip Fight", systemImage: "forward.end")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .tint(QuestboundTheme.accent)
                            } label: {
                                Label("Developer Test Tools", systemImage: "hammer")
                                    .font(.caption.weight(.semibold))
                            }
                            .padding(.top, 6)
                        }
                    }
                }
            }

            if room.type == .rest {
                roomCard("Short Rest") {
                    detailRow("Used", hero.currentAdventureState.shortRestUsed ? "Yes" : "No")
                    Button {
                        let rested = AdventureEngine.shortRest(hero: hero)
                        saveStore.updateHero(rested, in: slotID)
                    } label: {
                        Text("Take Short Rest")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(hero.currentAdventureState.shortRestUsed)
                }
            }

            if room.type == .treasure, let treasure = room.treasurePreview {
                roomCard("Treasure") {
                    Text(treasure)
                        .foregroundStyle(.secondary)
                }
            }

            if room.type == .exit {
                roomCard("Exit") {
                    if let treasure = room.treasurePreview {
                        Text(treasure)
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        completeAdventure()
                    } label: {
                        Text("Complete Adventure")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if room.choices.isEmpty && room.skillChecks.isEmpty && room.nextRoomID != nil && room.type != .combat && room.type != .boss {
                roomCard("Continue") {
                    Button {
                        move(to: room.nextRoomID, completing: room.id)
                    } label: {
                        Text("Continue")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func developerSkipCombat(_ room: AdventureRoomDefinition) {
        guard let hero else { return }
        var updated = hero
        updated.currentAdventureState.defeatedEnemyIDs.insert(room.id)
        updated.combatState = nil
        updated.currentAdventureState.currentCombatState = nil
        updated = AdventureEngine.appendLog(hero: updated, "Developer skipped combat in \(room.title).")

        if room.id == "deep-chamber" || room.type == .boss {
            saveStore.updateHero(updated, in: slotID)
            completeAdventure()
        } else {
            updated = AdventureEngine.markRoomComplete(hero: updated, roomID: room.id, nextRoomID: room.nextRoomID)
            saveStore.updateHero(updated, in: slotID)
        }
    }

    private var saveExitCard: some View {
        roomCard("Adventure Options") {
            Button {
                showExitPrompt = true
            } label: {
                Label("Save / Exit", systemImage: "rectangle.portrait.and.arrow.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func exitToGreywick() {
        dismiss()
        if let onExitToGreywick {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                onExitToGreywick()
            }
        }
    }

    private func adventureLogCard(_ hero: Hero) -> some View {
        roomCard("Adventure Log") {
            if hero.currentAdventureState.adventureLog.isEmpty {
                Text("No entries yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(hero.currentAdventureState.adventureLog.suffix(8).enumerated()), id: \.offset) { _, entry in
                    Text(entry)
                        .font(.footnote)
                    Divider()
                }
            }
        }
    }

    private func resolveSkillCheck(_ check: AdventureSkillCheckDefinition, roomID: String) {
        guard let hero else { return }
        let before = hero
        let floodingBonus = ["crypt-wade", "crypt-search-water", "crypt-pillars-athletics", "crypt-pillars-agility"].contains(check.id)
            ? hero.currentAdventureState.temporaryBonuses["cryptFloodingBonus", default: 0]
            : 0
        let smokeBonus = check.id.hasPrefix("ember-cross-bridge")
            ? hero.currentAdventureState.temporaryBonuses["emberSmokeHazardBonus", default: 0]
            : 0
        let result = SkillCheckHelper.check(
            hero: hero,
            skill: check.skill,
            target: max(1, check.difficulty.rawValue - floodingBonus - smokeBonus)
        )
        let outcome = result.success ? check.successText : check.failureText
        skillResultText = "\(result.explanation) \(outcome)"
        var updated = AdventureEngine.appendLog(hero: hero, "Skill check: \(result.explanation)")
        updated = AdventureEngine.appendLog(hero: updated, result.success ? "Success: \(check.successText)" : "Failure: \(check.failureText)")
        updated = applyAdventureOutcome(hero: updated, check: check, result: result)
        var completed = AdventureEngine.markRoomComplete(
            hero: updated,
            roomID: roomID,
            nextRoomID: result.success ? check.successNextRoomID : check.failureNextRoomID
        )
        let popup = adventureSkillOutcome(check: check, result: result, before: before, after: completed)
        for line in popup.details + popup.rewards + popup.consequences {
            completed = AdventureEngine.appendLog(hero: completed, line)
        }
        outcomePopup = popup
        saveStore.updateHero(completed, in: slotID)
    }

    private func move(to roomID: String?, completing currentRoomID: String) {
        guard let hero else { return }
        let updated = AdventureEngine.markRoomComplete(hero: hero, roomID: currentRoomID, nextRoomID: roomID)
        saveStore.updateHero(updated, in: slotID)
    }

    private func resolveChoice(_ choice: AdventureChoiceDefinition, roomID: String) {
        guard let hero else { return }
        var updated = hero
        updated = AdventureEngine.appendLog(hero: updated, "Choice selected: \(choice.text)")
        if choice.id == "smoky-tunnel" {
            updated.currentAdventureState.temporaryBonuses["room5EnemyFirstAttackBonus"] = 1
        }
        updated = applyCryptChoice(hero: updated, choice: choice)
        updated = applyEmberChoice(hero: updated, choice: choice)
        let outcome = adventureChoiceOutcome(choice)
        updated = AdventureEngine.appendLog(hero: updated, "\(outcome.title): \(outcome.mainResult)")
        for line in outcome.details + outcome.rewards + outcome.consequences {
            updated = AdventureEngine.appendLog(hero: updated, line)
        }
        updated = AdventureEngine.markRoomComplete(hero: updated, roomID: roomID, nextRoomID: choice.nextRoomID)
        outcomePopup = outcome
        saveStore.updateHero(updated, in: slotID)
    }

    private func completeAdventure() {
        guard let adventure else { return }
        guard let reward = saveStore.completeAdventure(adventure, slotID: slotID) else { return }
        completionReward = reward
        completedAdventure = adventure
    }

    private func completeCombatRoom(_ room: AdventureRoomDefinition) {
        guard let hero else { return }
        var updated = hero
        updated.currentAdventureState.defeatedEnemyIDs.insert(room.id)
        updated.combatState = nil
        updated.currentAdventureState.currentCombatState = nil
        updated = AdventureEngine.appendLog(hero: updated, "Combat won: \(room.title).")
        updated = applyPostCombatRoomReward(hero: updated, roomID: room.id)
        if AdventureEngine.isFinalBossRoom(room) {
            saveStore.updateHero(updated, in: slotID)
            completeAdventure()
        } else {
            updated = AdventureEngine.markRoomComplete(hero: updated, roomID: room.id, nextRoomID: room.nextRoomID)
            saveStore.updateHero(updated, in: slotID)
        }
    }

    private func combatEnemyIDs(for room: AdventureRoomDefinition, hero: Hero) -> [String] {
        guard room.id == "crypt-bone-watch" else { return room.enemyIDs }
        if hero.currentAdventureState.temporaryBonuses["cryptBellRung"] == 1 {
            return ["drowned-skeleton", "crypt-shambler", "bell-touched-warden"]
        }
        return room.enemyIDs
    }

    private func resolveRatNestSearch(roomID: String) {
        guard let hero else { return }
        let before = hero
        let result = SkillCheckHelper.check(hero: hero, skill: .awareness, target: SkillDifficulty.standard.rawValue)
        let items = result.success ? ["Bone Splinters": 2] : ["Bone Splinters": 1]
        let gold = result.success ? 5 : 0
        skillResultText = "\(result.explanation) \(result.success ? "You find 5 gold and useful bone scraps." : "You recover a single useful scrap.")"
        var logged = AdventureEngine.appendLog(hero: hero, "Post-combat search: \(result.explanation)")
        logged = AdventureEngine.appendLog(hero: logged, result.success ? "Reward gained: 5 gold and 2 Bone Splinters." : "Reward gained: 1 Bone Splinter.")
        let rewarded = AdventureEngine.applyRoomReward(hero: logged, rewardID: "rat-nest-search", gold: gold, items: items)
        var updated = AdventureEngine.markRoomComplete(hero: rewarded, roomID: roomID, nextRoomID: "split-tunnel")
        let popup = OutcomeResult(
            title: result.success ? "Awareness Check Successful" : "Awareness Check Failed",
            mainResult: result.success ? "You search the nest and find useful scraps among the debris." : "You recover only a single useful scrap.",
            rollBreakdown: result.explanation,
            rewards: rewardDeltaLines(before: before, after: updated)
        )
        for line in popup.rewards {
            updated = AdventureEngine.appendLog(hero: updated, line)
        }
        outcomePopup = popup
        saveStore.updateHero(updated, in: slotID)
    }

    private func adventureChoiceOutcome(_ choice: AdventureChoiceDefinition) -> OutcomeResult {
        switch choice.id {
        case "march-in":
            return OutcomeResult(
                title: "Into the Mine",
                mainResult: "You enter without delay.",
                details: ["No bonus or penalty."]
            )
        case "leave-cart":
            return OutcomeResult(
                title: "Lockbox Left Behind",
                mainResult: "You leave the lockbox untouched.",
                details: ["No reward, no risk."]
            )
        case "smoky-tunnel":
            return OutcomeResult(
                title: "Smoky Tunnel",
                mainResult: "You take the quickest route, but smoke stings your eyes and alerts the raiders.",
                consequences: ["Enemies gain +1 to their first attack in the next fight."]
            )
        case "leave-store-room":
            return OutcomeResult(
                title: "Store Room Left Behind",
                mainResult: "You leave the store room behind.",
                details: ["No reward gained."]
            )
        case "crypt-bold-entry":
            return OutcomeResult(
                title: "Bold Descent",
                mainResult: "Torchlight drives back the blue gloom, but the dead hear you coming.",
                details: ["Your first attack gains +1."],
                consequences: ["The first enemy group gains +1 initiative."]
            )
        case "crypt-pull-chain":
            return OutcomeResult(
                title: "The Bell Rings",
                mainResult: "The funeral bell sounds beneath the water and a hidden niche opens.",
                rewards: ["+10 gold", "+1 Relic Fragment"],
                consequences: ["A Bell-Touched Warden joins the Bone Watch."]
            )
        case "crypt-ignore-chain":
            return OutcomeResult(title: "Chain Untouched", mainResult: "You leave the rusted chain alone.", details: ["No reward and no alarm."])
        case "crypt-route-hall":
            return OutcomeResult(title: "Hall of Names", mainResult: "You choose the safer upper passage where carved names cover the walls.")
        case "crypt-route-floodway":
            return OutcomeResult(title: "Lower Floodway", mainResult: "You descend into the deeper flooded route in search of better treasure.")
        case "crypt-turn-back":
            return OutcomeResult(title: "Safer Stones", mainResult: "You abandon the submerged chest and cross without further risk.", details: ["No damage and no treasure."])
        case "crypt-leave-reliquary":
            return OutcomeResult(title: "Reliquary Sealed", mainResult: "You leave the ancient stone seal untouched.")
        case "crypt-bind-wounds":
            return OutcomeResult(
                title: "Wounds Bound",
                mainResult: "You bind your wounds before entering the black pool.",
                details: ["Restore 1d6 + Endurance modifier HP."],
                consequences: ["The boss gains +1 initiative."]
            )
        case "ember-route-vein":
            return OutcomeResult(
                title: "Ember Vein",
                mainResult: "You follow the glittering crystal seam.",
                details: ["More treasure is available, but the patrol is more alert."],
                consequences: ["The next enemy group gains +1 initiative."]
            )
        case "ember-route-channel":
            return OutcomeResult(
                title: "Old Cooling Channel",
                mainResult: "You take the darker cooling channel.",
                details: ["This route can weaken the next forge patrol or reveal guardian patterns."]
            )
        case "ember-leave-vein":
            return OutcomeResult(title: "Crystals Left Alone", mainResult: "You leave the ember vein untouched.", details: ["No reward and no heat flare."])
        case "ember-offer-gold":
            if hero?.gold ?? 0 >= 10 {
                return OutcomeResult(
                    title: "Gold Offered",
                    mainResult: "The shrine drinks the coin and leaves emberlight on your weapon.",
                    rewards: [],
                    consequences: ["-10 gold", "Your next damage against the Furnace Hound gains a blessing."]
                )
            }
            return OutcomeResult(
                title: "Not Enough Gold",
                mainResult: "The shrine waits, but you do not have 10 gold to offer.",
                details: ["No blessing gained."]
            )
        case "ember-offer-blood":
            return OutcomeResult(
                title: "Blood Offered",
                mainResult: "The shrine accepts a drop of blood and answers with heat.",
                details: ["Your next damage against the Furnace Hound gains +1."],
                consequences: ["You take 1d4 damage."]
            )
        case "ember-leave-shrine":
            return OutcomeResult(title: "Shrine Left Alone", mainResult: "You leave the hungry shrine untouched.", details: ["No blessing and no cost."])
        case "ember-leave-cache":
            return OutcomeResult(title: "Cache Left Sealed", mainResult: "You leave the forge cache sealed.", details: ["No reward and no flame trap."])
        case "ember-rest-before-boss":
            return OutcomeResult(
                title: "Brief Rest",
                mainResult: "You rest in the cooler stone before the deep forge.",
                details: ["Restore 1 Stamina or 1 Focus if possible; otherwise restore 1d6 HP."],
                consequences: ["The boss gains +1 initiative."]
            )
        case "ember-enter-forge":
            return OutcomeResult(title: "Deep Forge", mainResult: "You enter the deep forge and face the Emberheart Golem.")
        default:
            return OutcomeResult(title: choice.text, mainResult: "You continue deeper into the adventure.")
        }
    }

    private func adventureSkillOutcome(check: AdventureSkillCheckDefinition, result: SkillCheckResult, before: Hero, after: Hero) -> OutcomeResult {
        let title = "\(check.skill.displayName) Check \(result.success ? "Successful" : "Failed")"
        var details = [result.success ? check.successText : check.failureText]
        if result.natural20 {
            details.append("Natural 20.")
        }
        if result.natural1 {
            details.append("Natural 1.")
        }
        details.append(contentsOf: visibleEffectLines(check: check, result: result))
        let rewards = rewardDeltaLines(before: before, after: after)
        let consequences = consequenceDeltaLines(before: before, after: after)
        return OutcomeResult(
            title: customOutcomeTitle(for: check, result: result, fallback: title),
            mainResult: mainOutcomeText(for: check, result: result),
            rollBreakdown: result.explanation,
            details: details,
            rewards: rewards,
            consequences: consequences
        )
    }

    private func customOutcomeTitle(for check: AdventureSkillCheckDefinition, result: SkillCheckResult, fallback: String) -> String {
        if ["search-wreckage", "open-lockbox", "smash-lockbox"].contains(check.id), result.success {
            return "Treasure Found"
        }
        if ["open-lockbox", "smash-lockbox"].contains(check.id), !result.success {
            return result.natural1 ? "Trap Triggered" : "Lockbox Trouble"
        }
        if ["pick-store-lock", "force-store-door", "search-side-panel-awareness", "search-side-panel-survival"].contains(check.id), result.success {
            return "Store Room Opened"
        }
        if check.id == "force-store-door", !result.success {
            return "Door Holds"
        }
        if check.id == "pick-store-lock", !result.success {
            return "Lock Jammed"
        }
        return fallback
    }

    private func mainOutcomeText(for check: AdventureSkillCheckDefinition, result: SkillCheckResult) -> String {
        switch check.id {
        case "search-tracks-awareness", "search-tracks-survival":
            return result.success ? "You spot fresh tracks in the mud and scrape marks leading deeper into the mine." : "The tracks are muddled and unclear."
        case "enter-quietly":
            if result.success { return "You move quietly and gain a better opening position." }
            if result.natural1 { return "Your movement echoes through the tunnel." }
            return "Loose stones shift under your boots and the sound carries into the tunnel."
        case "search-wreckage":
            return result.success ? "You search the wreckage and find supplies tucked beneath the broken cart." : "You search the wreckage, but most of it is ruined."
        case "open-lockbox":
            return result.success ? "The lock clicks open cleanly." : "A rusted spike snaps from the lockbox."
        case "smash-lockbox":
            return result.success ? "The lockbox breaks open." : "The box cracks, but most of its contents scatter into the stones."
        case "narrow-tunnel-agility", "narrow-tunnel-athletics":
            return result.success ? "You crawl into a better position before the raider camp." : "You scrape through unstable stone."
        case "study-supports-lore", "study-supports-survival":
            return result.success ? "You find the safest route and notice useful stone fragments." : "You cannot make sense of the supports."
        case "pick-store-lock":
            return result.success ? "The lock opens safely." : "The lock jams loudly."
        case "force-store-door":
            return result.success ? "The door gives way." : "The door holds, and the effort hurts."
        case "search-side-panel-awareness", "search-side-panel-survival":
            return result.success ? "You find a side panel and slip inside safely." : "You find no safe way in."
        case "ember-study-smoke-awareness", "ember-study-smoke-survival":
            return result.success ? "You read the smoke and find a safer path through the heat." : "The smoke shifts too quickly to read."
        case "ember-push-smoke":
            return result.success ? "You cover your mouth and push through the smoke." : "The smoke catches in your lungs."
        case "ember-rush-smoke":
            return result.success ? "You move quickly through the choking entrance and gain momentum." : "Loose ash sends you stumbling."
        case "ember-cross-bridge-agility", "ember-cross-bridge-athletics":
            return result.success ? "You cross the unstable bridge safely." : "A slab shifts and the fissure scorches you."
        case "ember-reinforce-bridge-athletics", "ember-reinforce-bridge-survival":
            return result.success ? "You secure the cracked bridge stones for a safer retreat." : "The bridge refuses to settle."
        case "ember-search-fissure":
            return result.success ? "You spot ember deposits under the bridge." : "The smoke burns your lungs before you find anything useful."
        case "ember-mine-vein-athletics", "ember-mine-vein-endurance":
            return result.success ? "You break valuable crystal and ore from the ember vein." : "The vein flares violently."
        case "ember-extract-vein-thievery", "ember-extract-vein-survival":
            return result.success ? "You loosen the crystals without disturbing the hottest seams." : "You recover only a few hot fragments."
        case "ember-clear-channel-athletics":
            return result.success ? "Water coughs through the channel and cools the chambers ahead." : "The channel remains blocked."
        case "ember-study-markings-lore", "ember-study-markings-arcana":
            return result.success ? "The forge marks reveal patterns in the guardians' design." : "The markings offer no useful pattern."
        case "ember-search-channel":
            return result.success ? "You find coins and ore caught in the channel floor." : "The channel holds nothing useful."
        case "ember-clean-shrine-presence", "ember-clean-shrine-lore":
            return result.success ? "The cleaned shrine grants protection from the next flame." : "The shrine remains cold and silent."
        case "ember-pick-cache", "ember-force-cache", "ember-runes-cache-arcana", "ember-runes-cache-lore":
            return result.success ? "The cache opens and its heat fades." : "The cache flares against you."
        case "ember-open-vents-athletics", "ember-open-vents-thievery":
            return result.success ? "The vents open and cold air spills toward the deep forge." : "A burst of heat catches you."
        case "ember-study-rhythm-awareness", "ember-study-rhythm-arcana":
            return result.success ? "You learn the rhythm of the forge-heart and prepare your first strike." : "The rhythm shifts too quickly."
        case "ember-draw-heat":
            return result.success ? "You draw the forge heat into your next blow." : "The heat scorches through your guard."
        default:
            return result.success ? "The attempt succeeds." : "The attempt fails."
        }
    }

    private func visibleEffectLines(check: AdventureSkillCheckDefinition, result: SkillCheckResult) -> [String] {
        if ["search-tracks-awareness", "search-tracks-survival"].contains(check.id), result.natural20 {
            return ["First combat bonus gained."]
        }
        if check.id == "enter-quietly", result.success {
            return ["You gain a better opening position for the first fight."]
        }
        if check.id == "enter-quietly", result.natural1 {
            return ["Enemies are more alert in the first fight."]
        }
        if check.id == "smash-lockbox", result.natural1 {
            return ["The crash echoes through the mine. Raiders will be more alert in the next fight."]
        }
        if ["narrow-tunnel-agility", "narrow-tunnel-athletics"].contains(check.id), result.success {
            return ["Your first attack in the next fight gains +2 to hit."]
        }
        if ["narrow-tunnel-agility", "narrow-tunnel-athletics"].contains(check.id), result.natural1 {
            return ["You start the next combat Knocked Down."]
        }
        if ["study-supports-lore", "study-supports-survival"].contains(check.id), result.success {
            return ["No combat penalty."]
        }
        if check.id == "pick-store-lock", result.natural1 {
            return ["The noise carries deep into the mine. The boss will be more alert."]
        }
        if ["ember-study-smoke-awareness", "ember-study-smoke-survival"].contains(check.id), result.success {
            return ["The bridge crossing target is reduced by 2."]
        }
        if check.id == "ember-push-smoke", !result.success {
            return ["The first Ember Cave enemy group gains +1 initiative."]
        }
        if check.id == "ember-rush-smoke", result.success {
            return ["You gain +1 initiative in the first Ember Cave combat."]
        }
        if ["ember-cross-bridge-agility", "ember-cross-bridge-athletics"].contains(check.id), !result.success {
            return ["Fire hazard damage is applied immediately."]
        }
        if ["ember-reinforce-bridge-athletics", "ember-reinforce-bridge-survival"].contains(check.id), result.success {
            return ["The secured bridge helps your approach to the Furnace Hound."]
        }
        if check.id == "ember-clear-channel-athletics", result.success {
            return ["The next forge patrol starts Exposed."]
        }
        if ["ember-study-markings-lore", "ember-study-markings-arcana"].contains(check.id), result.success {
            return ["Your first attack against forge guardians gains +1 to hit."]
        }
        if ["ember-clean-shrine-presence", "ember-clean-shrine-lore"].contains(check.id), result.success {
            return ["The next incoming fire damage is reduced by 2."]
        }
        if ["ember-open-vents-athletics", "ember-open-vents-thievery"].contains(check.id), result.success {
            return ["The Emberheart Golem starts Exposed for 2 turns."]
        }
        if ["ember-study-rhythm-awareness", "ember-study-rhythm-arcana"].contains(check.id), result.success {
            return ["Your first attack against the Emberheart Golem gains +1 to hit."]
        }
        if check.id == "ember-draw-heat", result.success {
            return ["Your first damage against the Emberheart Golem gains +1."]
        }
        return []
    }

    private func rewardDeltaLines(before: Hero, after: Hero) -> [String] {
        var lines: [String] = []
        let goldDelta = after.gold - before.gold
        if goldDelta > 0 {
            lines.append("+\(goldDelta) gold")
        }
        for (name, quantity) in itemQuantityDeltas(before: before, after: after) where quantity > 0 {
            lines.append("+\(quantity) \(name)")
        }
        return lines
    }

    private func consequenceDeltaLines(before: Hero, after: Hero) -> [String] {
        var lines: [String] = []
        let hpLoss = before.currentHealth - after.currentHealth
        if hpLoss > 0 {
            lines.append("-\(hpLoss) HP")
        }
        for (name, quantity) in itemQuantityDeltas(before: before, after: after) where quantity < 0 {
            lines.append("\(quantity) \(name)")
        }
        let newConditions = after.currentAdventureState.activeConditions.filter { condition in
            !before.currentAdventureState.activeConditions.contains(where: { $0.type == condition.type })
        }
        for condition in newConditions {
            let duration = condition.remainingTurns.map { " for \($0) turn\($0 == 1 ? "" : "s")" } ?? ""
            lines.append("\(condition.type.displayName) applied\(duration).")
        }
        return lines
    }

    private func itemQuantityDeltas(before: Hero, after: Hero) -> [(String, Int)] {
        let names = Set(before.inventory.itemQuantities.keys).union(after.inventory.itemQuantities.keys)
        return names.compactMap { name in
            let delta = (after.inventory.itemQuantities[name] ?? 0) - (before.inventory.itemQuantities[name] ?? 0)
            return delta == 0 ? nil : (name, delta)
        }
        .sorted { $0.0 < $1.0 }
    }

    private func applyAdventureOutcome(hero: Hero, check: AdventureSkillCheckDefinition, result: SkillCheckResult) -> Hero {
        var updated = hero
        switch check.id {
        case "search-tracks-awareness", "search-tracks-survival":
            if result.natural20 {
                updated.currentAdventureState.temporaryBonuses["firstCombatHeroInitiativeBonus"] = 1
            }
        case "enter-quietly":
            if result.success {
                updated.currentAdventureState.temporaryBonuses["firstCombatHeroInitiativeBonus"] = 2
            }
            if result.natural1 {
                updated.currentAdventureState.temporaryBonuses["firstCombatEnemyInitiativeBonus"] = 1
            }
        case "search-wreckage":
            if result.success {
                updated = AdventureEngine.applyRoomReward(
                    hero: updated,
                    rewardID: "broken-cart-search",
                    gold: 8,
                    items: result.natural20 ? ["Minor Healing Draught": 1, "Stone Shards": 2] : ["Minor Healing Draught": 1]
                )
            } else {
                updated = AdventureEngine.applyRoomReward(hero: updated, rewardID: "broken-cart-search", gold: 3)
            }
        case "open-lockbox":
            if result.success {
                updated = applyLockboxTreasure(hero: updated, rewardID: "broken-cart-lockbox", natural20: result.natural20)
            } else {
                updated = damage(updated, dice: 6)
                if result.natural1 {
                    updated.currentAdventureState.activeConditions.append(Condition(type: .bleeding, remainingTurns: 1))
                }
            }
        case "smash-lockbox":
            if result.success {
                updated = applySmashTreasure(hero: updated, rewardID: "broken-cart-smash")
            } else if result.natural1 {
                updated = damage(updated, dice: 4)
                updated.currentAdventureState.temporaryBonuses["room5EnemyFirstAttackBonus"] = 1
            } else {
                updated = AdventureEngine.applyRoomReward(hero: updated, rewardID: "broken-cart-smash", gold: 3)
            }
        case "narrow-tunnel-agility", "narrow-tunnel-athletics":
            if result.success {
                updated.currentAdventureState.temporaryBonuses["room5HeroFirstAttackBonus"] = 2
            } else {
                updated = damage(updated, dice: 4)
                if result.natural1 {
                    updated.currentAdventureState.activeConditions.append(Condition(type: .knockedDown, remainingTurns: 1))
                }
            }
        case "study-supports-lore", "study-supports-survival":
            if result.success {
                updated = AdventureEngine.applyRoomReward(hero: updated, rewardID: "split-tunnel-supports", items: ["Stone Shards": 2])
            }
        case "pick-store-lock":
            if result.success {
                updated = applyStoreRoomReward(hero: updated)
            } else if result.natural1 {
                updated.currentAdventureState.temporaryBonuses["bossInitiativeBonus"] = 1
            }
        case "force-store-door":
            if result.success {
                updated = applyStoreRoomReward(hero: updated)
            } else {
                updated = damage(updated, dice: 4)
                if result.natural1, let count = updated.inventory.itemQuantities["Minor Healing Draught"], count > 0 {
                    updated.inventory.itemQuantities["Minor Healing Draught"] = count == 1 ? nil : count - 1
                }
            }
        case "search-side-panel-awareness", "search-side-panel-survival":
            if result.success {
                updated = applyStoreRoomReward(hero: updated)
            }
        case "crypt-inspect-awareness", "crypt-inspect-survival":
            if result.success {
                updated.currentAdventureState.temporaryBonuses["cryptFloodingBonus"] = 2
            } else if result.natural1 {
                updated = damage(updated, dice: 4)
            }
        case "crypt-quiet-entry":
            if result.success {
                updated.currentAdventureState.temporaryBonuses["cryptFirstAttackBonus"] = 2
            } else if result.natural1 {
                updated.currentAdventureState.temporaryBonuses["cryptFirstEnemyInitiative"] = 3
            }
        case "crypt-wade":
            if !result.success { updated = damage(updated, dice: 4) }
        case "crypt-search-water":
            if result.success {
                var items = ["Minor Healing Draught": 1]
                if result.natural20 { items["Relic Fragment"] = 1 }
                updated = AdventureEngine.applyRoomReward(hero: updated, rewardID: "crypt-antechamber-water", gold: Int.random(in: 8...12), items: items)
            } else {
                updated.currentHealth = max(0, updated.currentHealth - 1)
            }
        case "crypt-pillars-athletics", "crypt-pillars-agility":
            if result.success {
                updated.currentAdventureState.temporaryBonuses["cryptNextHeroInitiative"] = 1
            } else {
                updated = damage(updated, dice: 4)
            }
        case "crypt-jam-chain-thievery", "crypt-jam-chain-athletics":
            if result.success {
                updated.currentAdventureState.temporaryBonuses["cryptBellSilenced"] = 1
                updated.currentAdventureState.temporaryBonuses["cryptBoneWatchHeroInitiative"] = 2
            } else {
                updated.currentAdventureState.temporaryBonuses["cryptBellRung"] = 1
            }
        case "crypt-read-names-lore", "crypt-read-names-presence":
            if result.success {
                updated.currentAdventureState.temporaryBonuses["cryptGraveward"] = 1
                if result.natural20 {
                    if updated.maxFocus > 0 {
                        updated.currentFocus = min(updated.maxFocus, updated.currentFocus + 1)
                    } else {
                        updated.currentHealth = min(updated.maxHealth, updated.currentHealth + Int.random(in: 1...4))
                    }
                }
            }
        case "crypt-search-plaques":
            if result.success {
                updated = AdventureEngine.applyRoomReward(hero: updated, rewardID: "crypt-hall-relic", gold: 12, items: ["Relic Fragment": 1])
            } else {
                updated.currentHealth = max(0, updated.currentHealth - 1)
            }
        case "crypt-mark-wall":
            if result.success {
                updated.currentAdventureState.temporaryBonuses["cryptNextAttackBonus"] = 1
            } else {
                updated.currentAdventureState.temporaryBonuses["cryptStartExposed"] = 1
            }
        case "crypt-push-floodway":
            if result.success {
                updated = applyCryptTreasure(hero: updated, rewardID: "crypt-floodway-shelf", improved: false)
            } else {
                updated = damage(updated, dice: 4)
                updated.currentAdventureState.temporaryBonuses["cryptStartSlowed"] = 1
            }
        case "crypt-dive-chest":
            if result.success {
                updated = applyCryptTreasure(hero: updated, rewardID: "crypt-floodway-chest", improved: true)
            } else {
                updated = damage(updated, dice: 6)
                if result.natural1 {
                    updated.currentAdventureState.temporaryBonuses["cryptStartSlowed"] = 1
                }
            }
        case "crypt-study-symbols-lore", "crypt-study-symbols-arcana", "crypt-pick-reliquary", "crypt-force-reliquary":
            if result.success {
                updated = applyCryptReliquary(hero: updated, improved: result.natural20)
            } else if ["crypt-pick-reliquary", "crypt-force-reliquary"].contains(check.id) {
                updated = damage(updated, dice: 4)
            }
        case "crypt-study-chamber-awareness", "crypt-study-chamber-lore":
            if result.success {
                updated.currentAdventureState.temporaryBonuses["cryptBossExposed"] = 1
            }
        case "crypt-challenge":
            if result.success {
                updated.currentAdventureState.temporaryBonuses["cryptBossWeakened"] = 1
            } else {
                updated.currentAdventureState.temporaryBonuses["cryptStartMarked"] = 1
            }
        case "crypt-enter-silently":
            if result.success {
                updated.currentAdventureState.temporaryBonuses["cryptBossHeroInitiative"] = 4
            } else {
                updated.currentAdventureState.temporaryBonuses["cryptBossEnemyInitiative"] = 4
            }
        case "ember-study-smoke-awareness", "ember-study-smoke-survival":
            if result.success {
                updated.currentAdventureState.temporaryBonuses["emberSmokeHazardBonus"] = 2
            } else if result.natural1 {
                updated = damage(updated, dice: 4)
            }
        case "ember-push-smoke":
            if !result.success {
                updated.currentHealth = max(0, updated.currentHealth - 1)
                updated.currentAdventureState.temporaryBonuses["emberFirstEnemyInitiative"] = 1
            }
        case "ember-rush-smoke":
            if result.success {
                updated.currentAdventureState.temporaryBonuses["emberFirstHeroInitiative"] = 1
            }
        case "ember-cross-bridge-agility", "ember-cross-bridge-athletics":
            if !result.success { updated = fireDamage(updated, dice: 4) }
        case "ember-reinforce-bridge-athletics", "ember-reinforce-bridge-survival":
            if result.success {
                updated.currentAdventureState.temporaryBonuses["bridgeSecured"] = 1
            }
        case "ember-search-fissure":
            if result.success {
                updated = AdventureEngine.applyRoomReward(
                    hero: updated,
                    rewardID: "ember-bridge-deposit",
                    items: ["Ember Shard": Int.random(in: 1...2)]
                )
            } else {
                updated.currentHealth = max(0, updated.currentHealth - 1)
            }
        case "ember-mine-vein-athletics", "ember-mine-vein-endurance":
            if result.success {
                updated = AdventureEngine.applyRoomReward(
                    hero: updated,
                    rewardID: "ember-vein-mined",
                    gold: Int.random(in: 12...22),
                    items: ["Ember Shard": Int.random(in: 2...4)]
                )
            } else {
                updated = fireDamage(updated, dice: result.natural1 ? 6 : 4)
                if result.natural1 {
                    updated.currentAdventureState.activeConditions.append(Condition(type: .burning, remainingTurns: 1))
                }
            }
        case "ember-extract-vein-thievery", "ember-extract-vein-survival":
            let shardCount = result.success ? 2 : 1
            var items = ["Ember Shard": shardCount]
            if result.natural20 { items["Scorched Ore"] = 1 }
            updated = AdventureEngine.applyRoomReward(hero: updated, rewardID: "ember-vein-extracted", items: items)
        case "ember-clear-channel-athletics":
            if result.success {
                updated.currentAdventureState.temporaryBonuses["coolingChannelCleared"] = 1
            }
        case "ember-study-markings-lore", "ember-study-markings-arcana":
            if result.success {
                updated.currentAdventureState.temporaryBonuses["forgeMarkingsStudied"] = 1
            }
        case "ember-search-channel":
            if result.success {
                updated = AdventureEngine.applyRoomReward(
                    hero: updated,
                    rewardID: "ember-channel-floor",
                    gold: Int.random(in: 8...14),
                    items: ["Scorched Ore": 1]
                )
            }
        case "ember-clean-shrine-presence", "ember-clean-shrine-lore":
            if result.success {
                updated.currentAdventureState.temporaryBonuses["emberShrineFireReduction"] = 2
            }
        case "ember-pick-cache", "ember-force-cache", "ember-runes-cache-arcana", "ember-runes-cache-lore":
            if result.success {
                updated = applyEmberCache(hero: updated, improved: result.natural20)
            } else {
                updated = fireDamage(updated, dice: 4)
            }
        case "ember-open-vents-athletics", "ember-open-vents-thievery":
            if result.success {
                updated.currentAdventureState.temporaryBonuses["ventsOpened"] = 1
            } else {
                updated = fireDamage(updated, dice: 4)
            }
        case "ember-study-rhythm-awareness", "ember-study-rhythm-arcana":
            if result.success {
                updated.currentAdventureState.temporaryBonuses["flameRhythmStudied"] = 1
            }
        case "ember-draw-heat":
            if result.success {
                updated.currentHealth = max(0, updated.currentHealth - 1)
                updated.currentAdventureState.temporaryBonuses["heatDrawn"] = 1
            } else {
                updated = fireDamage(updated, dice: 4)
            }
        default:
            break
        }
        return updated
    }

    private func applyPostCombatRoomReward(hero: Hero, roomID: String) -> Hero {
        switch roomID {
        case "rat-nest":
            return hero
        case "raider-camp":
            var items = ["Torn Raider Cloth": 1, "Stone Shards": 1, "Iron Ingots": 1]
            if Int.random(in: 1...100) <= 10 {
                items["Minor Healing Draught"] = 1
            }
            return AdventureEngine.applyRoomReward(
                hero: hero,
                rewardID: "raider-camp-loot",
                gold: 15,
                items: items
            )
        case "crypt-restless-dead":
            var items: [String: Int] = ["Relic Fragment": 1]
            if Int.random(in: 1...100) <= 35,
               let gear = LootEngine.pathMatchedGear(for: hero, rarity: Int.random(in: 1...100) <= 75 ? .common : .uncommon) {
                items[gear.name] = 1
            }
            return AdventureEngine.applyRoomReward(hero: hero, rewardID: "crypt-restless-dead-cache", gold: Int.random(in: 8...15), items: items)
        case "crypt-bone-watch":
            var items: [String: Int] = ["Relic Fragment": 1]
            if let gear = LootEngine.pathMatchedGear(for: hero, rarity: .uncommon) {
                items[gear.name] = 1
            }
            return AdventureEngine.applyRoomReward(hero: hero, rewardID: "crypt-bone-watch-cache", gold: Int.random(in: 15...25), items: items)
        case "crypt-bell-drowned-warden":
            return AdventureEngine.applyRoomReward(hero: hero, rewardID: "crypt-boss-fixed-reward", items: ["Crypt Bell Shard": 1])
        case "ember-ash-beetle-nest":
            var items: [String: Int] = ["Ember Shard": 1]
            let supply: String
            if hero.maxStamina > 0 {
                supply = "Minor Stamina Draught"
            } else if hero.maxFocus > 0 {
                supply = "Focus Tonic"
            } else {
                supply = "Minor Healing Draught"
            }
            if Int.random(in: 1...100) <= 45 { items[supply] = 1 }
            return AdventureEngine.applyRoomReward(hero: hero, rewardID: "ember-beetle-nest-loot", gold: Int.random(in: 8...15), items: items)
        case "emberbound-patrol":
            var items: [String: Int] = ["Ember Shard": 2]
            if let gear = LootEngine.pathMatchedGear(for: hero, rarity: Int.random(in: 1...100) <= 70 ? .uncommon : .common) {
                items[gear.name] = 1
            }
            return AdventureEngine.applyRoomReward(hero: hero, rewardID: "ember-patrol-loot", gold: Int.random(in: 15...25), items: items)
        case "ember-furnace-hound":
            var items: [String: Int] = ["Scorched Ore": 1]
            if let gear = LootEngine.pathMatchedGear(for: hero, rarity: .uncommon),
               [.armour, .charm].contains(gear.category) {
                items[gear.name] = 1
            }
            return AdventureEngine.applyRoomReward(hero: hero, rewardID: "ember-hound-loot", gold: Int.random(in: 22...35), items: items)
        case "emberheart-golem":
            return AdventureEngine.applyRoomReward(
                hero: hero,
                rewardID: "emberheart-fixed-material",
                items: ["Emberheart Fragment": 1]
            )
        default:
            return hero
        }
    }

    private func applyCryptChoice(hero: Hero, choice: AdventureChoiceDefinition) -> Hero {
        var updated = hero
        switch choice.id {
        case "crypt-bold-entry":
            updated.currentAdventureState.temporaryBonuses["cryptFirstAttackBonus"] = 1
            updated.currentAdventureState.temporaryBonuses["cryptFirstEnemyInitiative"] = 1
        case "crypt-pull-chain":
            updated.currentAdventureState.temporaryBonuses["cryptBellRung"] = 1
            updated = AdventureEngine.applyRoomReward(hero: updated, rewardID: "crypt-bell-niche", gold: 10, items: ["Relic Fragment": 1])
        case "crypt-ignore-chain":
            updated.currentAdventureState.temporaryBonuses["cryptBellIgnored"] = 1
        case "crypt-route-hall":
            updated.currentAdventureState.temporaryBonuses["cryptRouteHall"] = 1
        case "crypt-route-floodway":
            updated.currentAdventureState.temporaryBonuses["cryptRouteFloodway"] = 1
        case "crypt-bind-wounds":
            let healing = max(1, Int.random(in: 1...6) + updated.attributes.modifier(for: .endurance))
            updated.currentHealth = min(updated.maxHealth, updated.currentHealth + healing)
            updated.currentAdventureState.temporaryBonuses["cryptBossEnemyInitiative"] = 1
        default:
            break
        }
        return updated
    }

    private func applyEmberChoice(hero: Hero, choice: AdventureChoiceDefinition) -> Hero {
        var updated = hero
        switch choice.id {
        case "ember-route-vein":
            updated.currentAdventureState.temporaryBonuses["emberVeinRoute"] = 1
        case "ember-route-channel":
            updated.currentAdventureState.temporaryBonuses["coolingChannelRoute"] = 1
        case "ember-offer-gold":
            if updated.gold >= 10 {
                updated.gold -= 10
                updated.inventory.gold = updated.gold
                updated.currentAdventureState.temporaryBonuses["emberBlessingDamage"] =
                    updated.subpath == "Flamecaller" ? 2 : 1
            } else {
                updated.currentAdventureState.temporaryBonuses["emberOfferingFailed"] = 1
            }
        case "ember-offer-blood":
            updated = damage(updated, dice: 4)
            updated.currentAdventureState.temporaryBonuses["emberBloodDamage"] = 1
        case "ember-rest-before-boss":
            updated.currentAdventureState.temporaryBonuses["restedBeforeBoss"] = 1
            if updated.maxStamina > 0 {
                updated.currentStamina = min(updated.maxStamina, updated.currentStamina + 1)
            } else if updated.maxFocus > 0 {
                updated.currentFocus = min(updated.maxFocus, updated.currentFocus + 1)
            } else {
                updated.currentHealth = min(updated.maxHealth, updated.currentHealth + Int.random(in: 1...6))
            }
        default:
            break
        }
        return updated
    }

    private func applyEmberCache(hero: Hero, improved: Bool) -> Hero {
        var items: [String: Int] = [
            "Scorched Ore": 1,
            hero.maxStamina > 0 ? "Stamina Draught" : (hero.maxFocus > 0 ? "Focus Tonic" : "Healing Draught"): 1
        ]
        let rarity: Rarity = improved ? .rare : .uncommon
        if let gear = LootEngine.pathMatchedGear(for: hero, rarity: rarity) {
            items[gear.name] = 1
        }
        return AdventureEngine.applyRoomReward(
            hero: hero,
            rewardID: "ember-sealed-cache",
            gold: improved ? 30 : 20,
            items: items
        )
    }

    private func fireDamage(_ hero: Hero, dice: Int) -> Hero {
        var updated = hero
        let rolled = Int.random(in: 1...dice)
        let reduction = min(rolled, updated.currentAdventureState.temporaryBonuses["emberShrineFireReduction", default: 0])
        if reduction > 0 {
            updated.currentAdventureState.temporaryBonuses["emberShrineFireReduction"] = 0
            updated.currentAdventureState.adventureLog.append("Shrine protection reduces fire damage by \(reduction).")
        }
        updated.currentHealth = max(0, updated.currentHealth - max(0, rolled - reduction))
        return updated
    }

    private func roomProgress(hero: Hero, adventure: AdventureDefinition, room: AdventureRoomDefinition) -> String {
        guard adventure.id == "the-ember-cave" else {
            return "\(hero.currentAdventureState.currentRoomIndex + 1) / \(max(1, adventure.rooms.count))"
        }
        let conceptualRoom: Int
        switch room.id {
        case "ember-vein", "ember-cooling-channel": conceptualRoom = 5
        case "emberbound-patrol": conceptualRoom = 6
        case "ember-charred-shrine": conceptualRoom = 7
        case "ember-sealed-forge-cache": conceptualRoom = 8
        case "ember-furnace-hound": conceptualRoom = 9
        case "ember-cooling-choice": conceptualRoom = 10
        case "ember-deep-forge-door": conceptualRoom = 11
        case "emberheart-golem": conceptualRoom = 12
        default: conceptualRoom = hero.currentAdventureState.currentRoomIndex + 1
        }
        return "\(conceptualRoom) / 12"
    }

    private func applyCryptTreasure(hero: Hero, rewardID: String, improved: Bool) -> Hero {
        var items: [String: Int] = ["Relic Fragment": improved ? 2 : 1]
        if Int.random(in: 1...100) <= (improved ? 70 : 35),
           let gear = LootEngine.pathMatchedGear(for: hero, rarity: improved && hero.level >= 3 ? .rare : .uncommon) {
            items[gear.name] = 1
        } else {
            items["Healing Draught"] = 1
        }
        return AdventureEngine.applyRoomReward(hero: hero, rewardID: rewardID, gold: improved ? 25 : 15, items: items)
    }

    private func applyCryptReliquary(hero: Hero, improved: Bool) -> Hero {
        var items: [String: Int] = ["Relic Fragment": improved ? 2 : 1]
        if let gear = LootEngine.pathMatchedGear(for: hero, rarity: hero.level >= 3 ? .rare : .uncommon) {
            items[gear.name] = 1
        }
        return AdventureEngine.applyRoomReward(hero: hero, rewardID: "crypt-reliquary", gold: improved ? 30 : 20, items: items)
    }

    private func applySmallTreasure(hero: Hero, rewardID: String) -> Hero {
        let roll = Int.random(in: 1...100)
        if roll <= 50 {
            return AdventureEngine.applyRoomReward(hero: hero, rewardID: rewardID, gold: Int.random(in: 8...15))
        }
        if roll <= 75 {
            return AdventureEngine.applyRoomReward(hero: hero, rewardID: rewardID, items: ["Minor Healing Draught": 1])
        }
        if roll <= 90 {
            return AdventureEngine.applyRoomReward(hero: hero, rewardID: rewardID, items: ["Stone Shards": 2])
        }
        if let gear = LootEngine.pathMatchedGear(for: hero, rarity: .common) {
            return AdventureEngine.applyRoomReward(hero: hero, rewardID: rewardID, items: [gear.name: 1])
        }
        return AdventureEngine.applyRoomReward(hero: hero, rewardID: rewardID, gold: 15)
    }

    private func applyLockboxTreasure(hero: Hero, rewardID: String, natural20: Bool) -> Hero {
        var items: [String: Int] = [:]
        let gold = Int.random(in: natural20 ? 20...25 : 15...25)
        let roll = Int.random(in: 1...100)
        if natural20 || roll <= 35 {
            items["Minor Healing Draught", default: 0] += 1
        } else if roll <= 70 {
            items["Stone Shards", default: 0] += 2
        } else if roll <= 90, let gear = LootEngine.pathMatchedGear(for: hero, rarity: .common) {
            items[gear.name, default: 0] += 1
        }
        if natural20 {
            items["Stone Shards", default: 0] += 2
        }
        return AdventureEngine.applyRoomReward(hero: hero, rewardID: rewardID, gold: gold, items: items)
    }

    private func applySmashTreasure(hero: Hero, rewardID: String) -> Hero {
        var items: [String: Int] = [:]
        if Int.random(in: 1...100) <= 25 {
            items["Stone Shards"] = 1
        }
        return AdventureEngine.applyRoomReward(hero: hero, rewardID: rewardID, gold: Int.random(in: 8...15), items: items)
    }

    private func applyStoreRoomReward(hero: Hero) -> Hero {
        var items = ["Minor Healing Draught": 1, "Iron Ingots": 1]
        if let gear = LootEngine.pathMatchedGear(for: hero, rarity: Int.random(in: 1...100) <= 70 ? .common : .uncommon) {
            items[gear.name, default: 0] += 1
        }
        return AdventureEngine.applyRoomReward(hero: hero, rewardID: "store-room-reward", gold: 25, items: items)
    }

    private func damage(_ hero: Hero, dice: Int) -> Hero {
        var updated = hero
        updated.currentHealth = max(0, updated.currentHealth - Int.random(in: 1...dice))
        if updated.currentHealth == 0 {
            updated = AdventureEngine.applyDefeat(hero: updated)
        }
        return updated
    }

    private func roomCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(QuestboundTheme.card)
        .questboundParchmentText()
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(QuestboundTheme.border, lineWidth: 1)
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
    }

    private func skillCheckTitle(_ check: AdventureSkillCheckDefinition) -> String {
        switch check.id {
        case "search-tracks-awareness", "search-tracks-survival": return "Search tracks: \(check.skill.displayName) vs \(check.difficulty.rawValue)"
        case "enter-quietly": return "Enter quietly: Stealth vs \(check.difficulty.rawValue)"
        case "search-wreckage": return "Search wreckage: Awareness vs \(check.difficulty.rawValue)"
        case "open-lockbox": return "Open lockbox carefully: Thievery vs \(check.difficulty.rawValue)"
        case "smash-lockbox": return "Smash lockbox: Athletics vs \(check.difficulty.rawValue)"
        case "narrow-tunnel-agility": return "Crawl through narrow tunnel: Stealth vs \(check.difficulty.rawValue)"
        case "narrow-tunnel-athletics": return "Crawl through narrow tunnel: Athletics vs \(check.difficulty.rawValue)"
        case "study-supports-lore", "study-supports-survival": return "Study the supports: \(check.skill.displayName) vs \(check.difficulty.rawValue)"
        case "pick-store-lock": return "Pick lock: Thievery vs \(check.difficulty.rawValue)"
        case "force-store-door": return "Force door: Athletics vs \(check.difficulty.rawValue)"
        case "search-side-panel-awareness", "search-side-panel-survival": return "Search side panel: \(check.skill.displayName) vs \(check.difficulty.rawValue)"
        default: return "\(check.skill.displayName) vs \(check.difficulty.displayName) \(check.difficulty.rawValue)"
        }
    }
}

private struct AdventureCompletionRoute: Identifiable, Hashable {
    let adventure: AdventureDefinition
    var id: String { adventure.id }
}
