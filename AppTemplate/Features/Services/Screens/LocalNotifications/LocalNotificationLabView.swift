import SwiftUI

struct LocalNotificationLabView: View {
    private let guide: ServiceLabGuide
    @State private var model: LocalNotificationLabViewModel
    @State private var title = StoreServicesText.string("Services lab")
    @State private var bodyText = StoreServicesText.string("A safe local notification demo.")
    @State private var metadataValue = "guided"
    @State private var actionTitle = StoreServicesText.string("Open Lab")
    @State private var textInputTitle = StoreServicesText.string("Reply")
    @State private var selectedAsset: LocalNotificationLabAsset?
    @State private var useCustomSound = false
    @State private var badgeCount = 1
    @State private var selectedPending: Set<LocalNotificationID> = []
    @State private var selectedDelivered: Set<LocalNotificationID> = []
    @State private var confirmPendingRemoval = false
    @State private var confirmDeliveredRemoval = false

    init(
        guide: ServiceLabGuide,
        lab: any ILocalNotificationLabService,
        appWide: any ILocalNotificationAppWideCapabilities,
        history: any ILocalNotificationEventReading,
        assets: LocalNotificationLabAssetProvider
    ) {
        self.guide = guide
        _model = State(initialValue: LocalNotificationLabViewModel(
            lab: lab,
            appWide: appWide,
            history: history,
            assets: assets
        ))
    }

    var body: some View {
        ServiceLabGuideView(
            guide: guide,
            result: model.actualResult,
            resetDemoData: { Task { await model.resetLabData() } }
        ) {
            authorizationControls
            Button(StoreServicesText.resource("Schedule Immediate Lab Notification")) {
                Task { await model.scheduleLab(makeRequest(id: "services.lab.immediate", trigger: .immediate)) }
            }
            .accessibilityIdentifier("action.services.notifications.schedule-immediate")
            labLists
            historyPanel
        } advanced: {
            settingsPanel
            schedulingPanel
            categoryPanel
            contentPanel
            attachmentPanel
            labRemovalPanel
            appWidePanel
            badgePanel
        }
        .navigationTitle(StoreServicesText.resource("Local Notifications"))
        .accessibilityIdentifier("screen.services.local-notifications")
        .confirmationDialog(
            StoreServicesText.resource("Remove every app-owned pending notification?"),
            isPresented: $confirmPendingRemoval,
            titleVisibility: .visible
        ) {
            Button(StoreServicesText.resource("Remove All App-owned Pending"), role: .destructive) {
                Task { await model.removeAllAppOwnedPendingConfirmed() }
            }
        }
        .confirmationDialog(
            StoreServicesText.resource("Remove every app-owned delivered notification?"),
            isPresented: $confirmDeliveredRemoval,
            titleVisibility: .visible
        ) {
            Button(StoreServicesText.resource("Remove All App-owned Delivered"), role: .destructive) {
                Task { await model.removeAllAppOwnedDeliveredConfirmed() }
            }
        }
        .task {
            await model.startEventUpdates()
            await model.refreshSettings()
            await model.refreshLabLists()
            await model.refreshAppOwnedLists()
            do {
                try await Task.sleep(for: .seconds(31_536_000))
            } catch {}
            await model.stopEventUpdates()
        }
    }

    private var authorizationControls: some View {
        VStack(alignment: .leading) {
            Text(StoreServicesText.resource("Authorization Options")).font(.headline)
            authorizationToggle(StoreServicesText.string("Alert"), option: .alert)
            authorizationToggle(StoreServicesText.string("Sound"), option: .sound)
            authorizationToggle(StoreServicesText.string("Badge"), option: .badge)
            authorizationToggle(StoreServicesText.string("Provisional"), option: .provisional)
            Button(StoreServicesText.resource("Request Selected Authorization")) {
                Task { await model.requestSelectedAuthorization() }
            }
            .disabled(model.authorizationOptions.isEmpty)
            .accessibilityIdentifier("action.services.notifications.authorization")
        }
    }

    private func authorizationToggle(
        _ label: String,
        option: LocalNotificationAuthorizationOptions
    ) -> some View {
        Toggle(label, isOn: Binding(
            get: { model.authorizationOptions.contains(option) },
            set: { model.setAuthorizationOption(option, enabled: $0) }
        ))
    }

    @ViewBuilder
    private var labLists: some View {
        Text(StoreServicesText.resource("Lab-only Pending Notifications")).font(.headline)
        notificationIDs(
            model.pendingLab.map(\.id),
            empty: StoreServicesText.string("No lab-only pending notifications.")
        )
        Text(StoreServicesText.resource("Lab-only Delivered Notifications")).font(.headline)
        notificationIDs(
            model.deliveredLab.map(\.id),
            empty: StoreServicesText.string("No lab-only delivered notifications.")
        )
        Button(StoreServicesText.resource("Refresh Lab-only Lists")) { Task { await model.refreshLabLists() } }
    }

    @ViewBuilder
    private var historyPanel: some View {
        Text(StoreServicesText.resource("Safe Notification Event History")).font(.headline)
        if model.eventRecords.isEmpty {
            Text(StoreServicesText.resource("No safe event summaries.")).foregroundStyle(.secondary)
        } else {
            ForEach(model.eventRecords) { record in
                Text(StoreServicesText.resource("\(record.summary.kind.rawValue) • \(record.summary.status.rawValue)"))
            }
        }
        Button(StoreServicesText.resource("Clear Event History")) { Task { await model.clearEventHistory() } }
            .accessibilityIdentifier("action.services.notifications.clear-history")
    }

    @ViewBuilder
    private var settingsPanel: some View {
        Text(StoreServicesText.resource("Notification Settings")).font(.headline)
        if let settings = model.settings {
            Text(StoreServicesText.resource("Authorization: \(settings.authorizationStatus.rawValue)"))
            Text(StoreServicesText.resource("Alert: \(settings.alertSetting.rawValue) • Sound: \(settings.soundSetting.rawValue) • Badge: \(settings.badgeSetting.rawValue)"))
        } else {
            Text(StoreServicesText.resource("Settings have not been loaded.")).foregroundStyle(.secondary)
        }
        Button(StoreServicesText.resource("Refresh Settings")) { Task { await model.refreshSettings() } }
    }

    private var schedulingPanel: some View {
        VStack(alignment: .leading) {
            Text(StoreServicesText.resource("Interval and Calendar Scheduling")).font(.headline)
            Button(StoreServicesText.resource("Schedule 5-second Interval")) {
                Task { await model.scheduleLab(makeRequest(
                    id: "services.lab.interval",
                    trigger: .timeInterval(seconds: 5, repeats: false)
                )) }
            }
            Button(StoreServicesText.resource("Schedule Calendar Demo")) {
                var components = DateComponents()
                components.second = (Calendar.current.component(.second, from: .now) + 10) % 60
                Task { await model.scheduleLab(makeRequest(
                    id: "services.lab.calendar",
                    trigger: .calendar(components, repeats: false)
                )) }
            }
        }
    }

    private var categoryPanel: some View {
        VStack(alignment: .leading) {
            Text(StoreServicesText.resource("Lab Category, Button, and Text Input")).font(.headline)
            TextField(StoreServicesText.resource("Button action title"), text: $actionTitle)
            TextField(StoreServicesText.resource("Text input action title"), text: $textInputTitle)
            Button(StoreServicesText.resource("Replace Lab Category Set")) {
                Task { await model.replaceLabCategories([makeCategory()]) }
            }
            Button(StoreServicesText.resource("Reset Lab Category Set")) { Task { await model.resetLabCategories() } }
        }
    }

    private var contentPanel: some View {
        VStack(alignment: .leading) {
            Text(StoreServicesText.resource("Content and Metadata")).font(.headline)
            TextField(StoreServicesText.resource("Notification title"), text: $title)
            TextField(StoreServicesText.resource("Notification body"), text: $bodyText)
            TextField(StoreServicesText.resource("Metadata value"), text: $metadataValue)
        }
    }

    private var attachmentPanel: some View {
        VStack(alignment: .leading) {
            Text(StoreServicesText.resource("Bundled Attachments and Sound")).font(.headline)
            Picker(StoreServicesText.resource("Attachment"), selection: $selectedAsset) {
                Text(StoreServicesText.resource("None")).tag(LocalNotificationLabAsset?.none)
                Text(StoreServicesText.resource("Image")).tag(LocalNotificationLabAsset?.some(.image))
                Text(StoreServicesText.resource("Audio")).tag(LocalNotificationLabAsset?.some(.audio))
                Text(StoreServicesText.resource("Video")).tag(LocalNotificationLabAsset?.some(.video))
            }
            Toggle(StoreServicesText.resource("Use named notification sound"), isOn: $useCustomSound)
            Button(StoreServicesText.resource("Schedule Advanced Content")) {
                Task { await model.scheduleLab(makeRequest(id: "services.lab.advanced", trigger: .immediate)) }
            }
        }
    }

    private var labRemovalPanel: some View {
        VStack(alignment: .leading) {
            Text(StoreServicesText.resource("Selected Lab-only Removal")).font(.headline)
            ForEach(model.pendingLab, id: \.id) { snapshot in
                Toggle(snapshot.id.value, isOn: selectionBinding(snapshot.id, selection: $selectedPending))
            }
            Button(StoreServicesText.resource("Remove Selected Lab-only Pending")) {
                Task { await model.removeSelectedPending(selectedPending); selectedPending = [] }
            }
            ForEach(model.deliveredLab, id: \.id) { snapshot in
                Toggle(snapshot.id.value, isOn: selectionBinding(snapshot.id, selection: $selectedDelivered))
            }
            Button(StoreServicesText.resource("Remove Selected Lab-only Delivered")) {
                Task { await model.removeSelectedDelivered(selectedDelivered); selectedDelivered = [] }
            }
        }
    }

    private var appWidePanel: some View {
        VStack(alignment: .leading) {
            Text(StoreServicesText.resource("App-wide Controls — Store + Lab")).font(.headline)
            Text(StoreServicesText.resource("App-wide Owned Pending (Store + Lab)"))
            notificationIDs(
                model.pendingAppOwned.map(\.id),
                empty: StoreServicesText.string("No app-owned pending notifications.")
            )
            Text(StoreServicesText.resource("App-wide Owned Delivered (Store + Lab)"))
            notificationIDs(
                model.deliveredAppOwned.map(\.id),
                empty: StoreServicesText.string("No app-owned delivered notifications.")
            )
            Button(StoreServicesText.resource("Refresh App-wide Owned Lists")) { Task { await model.refreshAppOwnedLists() } }
            Button(StoreServicesText.resource("Remove All App-owned Pending…"), role: .destructive) { confirmPendingRemoval = true }
            Button(StoreServicesText.resource("Remove All App-owned Delivered…"), role: .destructive) { confirmDeliveredRemoval = true }
        }
    }

    private var badgePanel: some View {
        VStack(alignment: .leading) {
            Text(StoreServicesText.resource("App-wide Badge")).font(.headline)
            Stepper(StoreServicesText.resource("Badge count: \(badgeCount)"), value: $badgeCount, in: 0...99)
            Button(StoreServicesText.resource("Set Badge Count")) { Task { await model.setBadgeCount(badgeCount) } }
            Button(StoreServicesText.resource("Clear Badge")) { Task { await model.clearBadge() } }
        }
    }

    @ViewBuilder
    private func notificationIDs(_ ids: [LocalNotificationID], empty: String) -> some View {
        if ids.isEmpty {
            Text(empty).foregroundStyle(.secondary)
        } else {
            ForEach(ids, id: \.self) { Text($0.value).textSelection(.enabled) }
        }
    }

    private func selectionBinding(
        _ id: LocalNotificationID,
        selection: Binding<Set<LocalNotificationID>>
    ) -> Binding<Bool> {
        Binding(
            get: { selection.wrappedValue.contains(id) },
            set: { enabled in
                if enabled { selection.wrappedValue.insert(id) }
                else { selection.wrappedValue.remove(id) }
            }
        )
    }

    private func makeRequest(
        id: String,
        trigger: LocalNotificationTrigger
    ) -> LocalNotificationRequest {
        var attachments: [LocalNotificationAttachment] = []
        if let selectedAsset,
           let url = try? model.attachmentURL(selectedAsset),
           let attachmentID = try? LocalNotificationAttachmentID("services.lab.attachment") {
            attachments = [.init(id: attachmentID, fileURL: url)]
        }
        let sound: LocalNotificationSound
        if useCustomSound, let name = try? model.notificationSoundName() {
            sound = .named(resourceName: name)
        } else {
            sound = .default
        }
        return LocalNotificationRequest(
            id: try! LocalNotificationID(id),
            content: LocalNotificationContent(
                title: title,
                body: bodyText,
                badge: badgeCount,
                sound: sound,
                attachments: attachments,
                metadata: ["source": .string(metadataValue)],
                foregroundPresentation: [.banner, .list, .sound, .badge]
            ),
            trigger: trigger
        )
    }

    private func makeCategory() -> LocalNotificationCategory {
        LocalNotificationCategory(
            id: try! LocalNotificationCategoryID("services.lab"),
            actions: [
                .button(.init(
                    id: try! LocalNotificationActionID("services.lab.action.open"),
                    title: actionTitle,
                    options: .foreground
                )),
                .textInput(.init(
                    id: try! LocalNotificationActionID("services.lab.action.reply"),
                    title: textInputTitle,
                    options: .foreground,
                    deepLink: nil,
                    textInputButtonTitle: StoreServicesText.string("Send"),
                    textInputPlaceholder: StoreServicesText.string("Safe text")
                ))
            ],
            hiddenPreviewsBodyPlaceholder: StoreServicesText.string("Services lab notification"),
            categorySummaryFormat: StoreServicesText.string("%u lab notifications"),
            reportsDismissal: true
        )
    }
}
