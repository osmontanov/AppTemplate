import SwiftUI

struct LocalNotificationLabView: View {
    private let guide: ServiceLabGuide
    @State private var model: LocalNotificationLabViewModel
    @State private var title = AppText.string("Services lab")
    @State private var bodyText = AppText.string("A safe local notification demo.")
    @State private var metadataValue = "guided"
    @State private var actionTitle = AppText.string("Open Lab")
    @State private var textInputTitle = AppText.string("Reply")
    @State private var selectedAsset: LocalNotificationLabAsset?
    @State private var useCustomSound = false
    @State private var badgeCount = 1
    @State private var selectedPending: Set<LocalNotificationID> = []
    @State private var selectedDelivered: Set<LocalNotificationID> = []
    @State private var confirmPendingRemoval = false
    @State private var confirmDeliveredRemoval = false
    @State private var advancedIsExpanded = false

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
            Button(AppText.resource("Schedule Immediate Lab Notification")) {
                Task { await model.scheduleLab(makeRequest(id: "services.lab.immediate", trigger: .immediate)) }
            }
            .accessibilityIdentifier(AppAccessibilityIdentifier.action(.tryService))
            labLists
            historyPanel
        } advanced: {
            DisclosureGroup(isExpanded: $advancedIsExpanded) {
                settingsPanel
                schedulingPanel
                categoryPanel
                contentPanel
                attachmentPanel
                labRemovalPanel
                appWidePanel
                badgePanel
            } label: {
                Text(AppText.resource("Advanced"))
            }
            .accessibilityIdentifier("action.services.notifications.advanced")
        }
        .navigationTitle(AppText.resource("Local Notifications"))
        .overlay(alignment: .topLeading) {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityIdentifier("screen.services.local-notifications")
        }
        .confirmationDialog(
            AppText.resource("Remove every app-owned pending notification?"),
            isPresented: $confirmPendingRemoval,
            titleVisibility: .visible
        ) {
            Button(AppText.resource("Remove All App-owned Pending"), role: .destructive) {
                Task { await model.removeAllAppOwnedPendingConfirmed() }
            }
        }
        .confirmationDialog(
            AppText.resource("Remove every app-owned delivered notification?"),
            isPresented: $confirmDeliveredRemoval,
            titleVisibility: .visible
        ) {
            Button(AppText.resource("Remove All App-owned Delivered"), role: .destructive) {
                Task { await model.removeAllAppOwnedDeliveredConfirmed() }
            }
        }
        .task {
            await model.startEventUpdates()
            await model.loadInitialState()
            do {
                try await Task.sleep(for: .seconds(31_536_000))
            } catch {}
            await model.stopEventUpdates()
        }
    }

    private var authorizationControls: some View {
        VStack(alignment: .leading) {
            Text(AppText.resource("Authorization Options")).font(.headline)
            authorizationToggle(AppText.string("Alert"), option: .alert)
            authorizationToggle(AppText.string("Sound"), option: .sound)
            authorizationToggle(AppText.string("Badge"), option: .badge)
            authorizationToggle(AppText.string("Provisional"), option: .provisional)
            Button(AppText.resource("Request Selected Authorization")) {
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
        Text(AppText.resource("Lab-only Pending Notifications")).font(.headline)
        notificationIDs(
            model.pendingLab.map(\.id),
            empty: AppText.string("No lab-only pending notifications.")
        )
        Text(AppText.resource("Lab-only Delivered Notifications")).font(.headline)
        notificationIDs(
            model.deliveredLab.map(\.id),
            empty: AppText.string("No lab-only delivered notifications.")
        )
        Button(AppText.resource("Refresh Lab-only Lists")) { Task { await model.refreshLabLists() } }
    }

    @ViewBuilder
    private var historyPanel: some View {
        Text(AppText.resource("Safe Notification Event History")).font(.headline)
        if model.eventRecords.isEmpty {
            Text(AppText.resource("No safe event summaries.")).foregroundStyle(.secondary)
        } else {
            ForEach(model.eventRecords) { record in
                Text(AppText.resource("\(record.summary.kind.rawValue) • \(record.summary.status.rawValue)"))
            }
        }
        Button(AppText.resource("Clear Event History")) { Task { await model.clearEventHistory() } }
            .accessibilityIdentifier("action.services.notifications.clear-history")
    }

    @ViewBuilder
    private var settingsPanel: some View {
        Text(AppText.resource("Notification Settings")).font(.headline)
        if let settings = model.settings {
            Text(AppText.resource("Authorization: \(settings.authorizationStatus.rawValue)"))
            Text(AppText.resource("Alert: \(settings.alertSetting.rawValue) • Sound: \(settings.soundSetting.rawValue) • Badge: \(settings.badgeSetting.rawValue)"))
        } else {
            Text(AppText.resource("Settings have not been loaded.")).foregroundStyle(.secondary)
        }
        Button(AppText.resource("Refresh Settings")) { Task { await model.refreshSettings() } }
    }

    private var schedulingPanel: some View {
        VStack(alignment: .leading) {
            Text(AppText.resource("Interval and Calendar Scheduling")).font(.headline)
            Button(AppText.resource("Schedule 5-second Interval")) {
                Task { await model.scheduleLab(makeRequest(
                    id: "services.lab.interval",
                    trigger: .timeInterval(seconds: 5, repeats: false)
                )) }
            }
            Button(AppText.resource("Schedule Calendar Demo")) {
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
            Text(AppText.resource("Lab Category, Button, and Text Input")).font(.headline)
            TextField(AppText.resource("Button action title"), text: $actionTitle)
            TextField(AppText.resource("Text input action title"), text: $textInputTitle)
            Button(AppText.resource("Replace Lab Category Set")) {
                Task { await model.replaceLabCategories([makeCategory()]) }
            }
            Button(AppText.resource("Reset Lab Category Set")) { Task { await model.resetLabCategories() } }
        }
    }

    private var contentPanel: some View {
        VStack(alignment: .leading) {
            Text(AppText.resource("Content and Metadata")).font(.headline)
            TextField(AppText.resource("Notification title"), text: $title)
            TextField(AppText.resource("Notification body"), text: $bodyText)
            TextField(AppText.resource("Metadata value"), text: $metadataValue)
        }
    }

    private var attachmentPanel: some View {
        VStack(alignment: .leading) {
            Text(AppText.resource("Bundled Attachments and Sound")).font(.headline)
            Picker(AppText.resource("Attachment"), selection: $selectedAsset) {
                Text(AppText.resource("None")).tag(LocalNotificationLabAsset?.none)
                Text(AppText.resource("Image")).tag(LocalNotificationLabAsset?.some(.image))
                Text(AppText.resource("Audio")).tag(LocalNotificationLabAsset?.some(.audio))
                Text(AppText.resource("Video")).tag(LocalNotificationLabAsset?.some(.video))
            }
            Toggle(AppText.resource("Use named notification sound"), isOn: $useCustomSound)
            Button(AppText.resource("Schedule Advanced Content")) {
                Task { await model.scheduleLab(makeRequest(id: "services.lab.advanced", trigger: .immediate)) }
            }
        }
    }

    private var labRemovalPanel: some View {
        VStack(alignment: .leading) {
            Text(AppText.resource("Selected Lab-only Removal")).font(.headline)
            ForEach(model.pendingLab, id: \.id) { snapshot in
                Toggle(snapshot.id.value, isOn: selectionBinding(snapshot.id, selection: $selectedPending))
            }
            Button(AppText.resource("Remove Selected Lab-only Pending")) {
                Task { await model.removeSelectedPending(selectedPending); selectedPending = [] }
            }
            ForEach(model.deliveredLab, id: \.id) { snapshot in
                Toggle(snapshot.id.value, isOn: selectionBinding(snapshot.id, selection: $selectedDelivered))
            }
            Button(AppText.resource("Remove Selected Lab-only Delivered")) {
                Task { await model.removeSelectedDelivered(selectedDelivered); selectedDelivered = [] }
            }
        }
    }

    private var appWidePanel: some View {
        VStack(alignment: .leading) {
            Text(AppText.resource("App-wide Controls — Store + Lab")).font(.headline)
            Text(AppText.resource("App-wide Owned Pending (Store + Lab)"))
            notificationIDs(
                model.pendingAppOwned.map(\.id),
                empty: AppText.string("No app-owned pending notifications.")
            )
            Text(AppText.resource("App-wide Owned Delivered (Store + Lab)"))
            notificationIDs(
                model.deliveredAppOwned.map(\.id),
                empty: AppText.string("No app-owned delivered notifications.")
            )
            Button(AppText.resource("Refresh App-wide Owned Lists")) { Task { await model.refreshAppOwnedLists() } }
            Button(AppText.resource("Remove All App-owned Pending…"), role: .destructive) { confirmPendingRemoval = true }
            Button(AppText.resource("Remove All App-owned Delivered…"), role: .destructive) { confirmDeliveredRemoval = true }
        }
    }

    private var badgePanel: some View {
        VStack(alignment: .leading) {
            Text(AppText.resource("App-wide Badge")).font(.headline)
            Stepper(AppText.resource("Badge count: \(badgeCount)"), value: $badgeCount, in: 0...99)
            Button(AppText.resource("Set Badge Count")) { Task { await model.setBadgeCount(badgeCount) } }
            Button(AppText.resource("Clear Badge")) { Task { await model.clearBadge() } }
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
                    textInputButtonTitle: AppText.string("Send"),
                    textInputPlaceholder: AppText.string("Safe text")
                ))
            ],
            hiddenPreviewsBodyPlaceholder: AppText.string("Services lab notification"),
            categorySummaryFormat: AppText.string("%u lab notifications"),
            reportsDismissal: true
        )
    }
}
