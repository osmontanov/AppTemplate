import Foundation
import SwiftUI

struct ProductReminderView: View {
    private enum SelectionKind: Hashable {
        case quickTest
        case interval
        case calendar
    }

    let product: Product
    @State private var viewModel: ProductReminderViewModel
    @FocusState private var focusedField: ProductReminderField?
    @AccessibilityFocusState private var accessibilityFocusedField: ProductReminderField?
    @AccessibilityFocusState private var resultIsFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    init(
        product: Product,
        reminders: any IProductReminderRepository,
        clock: AppClock
    ) {
        self.product = product
        _viewModel = State(initialValue: ProductReminderViewModel(
            product: product,
            reminders: reminders,
            clock: clock
        ))
    }

    var body: some View {
        NavigationStack {
            Form {
                productSection
                selectionSection
                statusSection
                resultSection
                actionsSection
            }
            .navigationTitle(AppText.resource("Product reminder"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppText.resource("Done")) { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
            }
        }
        .task { await viewModel.refresh() }
        .onChange(of: viewModel.focusedField) { _, value in
            focusedField = value
            accessibilityFocusedField = value
        }
        .onChange(of: announcementText) { _, value in
            guard let value else { return }
            resultIsFocused = true
            AccessibilityNotification.Announcement(value).post()
        }
        .frame(minWidth: 360, minHeight: 460)
        .overlay(alignment: .topLeading) {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityIdentifier(AppAccessibilityIdentifier.screen(.productReminder))
        }
    }

    private var productSection: some View {
        Section(AppText.resource("Product")) {
            LabeledContent(AppText.resource("Name"), value: product.title)
            LabeledContent(AppText.resource("Price")) {
                Text(verbatim: AppFormatting.priceUSD(product.price, locale: locale))
            }
        }
    }

    private var selectionSection: some View {
        Section(AppText.resource("When")) {
            Picker(AppText.resource("Reminder type"), selection: selectionBinding) {
                Text(AppText.resource("Quick test")).tag(SelectionKind.quickTest)
                Text(AppText.resource("Interval")).tag(SelectionKind.interval)
                Text(AppText.resource("Date and time")).tag(SelectionKind.calendar)
            }
            .pickerStyle(.segmented)

            switch selectionBinding.wrappedValue {
            case .quickTest:
                Text(AppText.resource("Schedules a one-time reminder in five seconds."))
                    .foregroundStyle(.secondary)
            case .interval:
                TextField(AppText.resource("Seconds"), text: intervalTextBinding)
                    .focused($focusedField, equals: .interval)
                    .accessibilityFocused($accessibilityFocusedField, equals: .interval)
                    .accessibilityIdentifier("field.product-reminder.interval")
                Toggle(AppText.resource("Repeat"), isOn: repeatsBinding)
                Text(AppText.resource("Use 1 to 604,800 seconds. Repeating reminders require at least 60 seconds."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .calendar:
                DatePicker(
                    AppText.resource("Date and time"),
                    selection: calendarDateBinding,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .focused($focusedField, equals: .calendarDate)
                .accessibilityFocused($accessibilityFocusedField, equals: .calendarDate)
                .accessibilityIdentifier("field.product-reminder.calendar-date")
                Picker(AppText.resource("Time zone"), selection: calendarTimeZoneBinding) {
                    ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { identifier in
                        Text(verbatim: identifier).tag(identifier)
                    }
                }
                calendarResolution
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        Section(AppText.resource("Status")) {
            switch currentStatus {
            case .notScheduled:
                Label(AppText.resource("Not scheduled"), systemImage: "bell.slash")
                    .accessibilityIdentifier("status.product-reminder.not-scheduled")
            case let .scheduled(nextTriggerDate):
                if let nextTriggerDate {
                    LabeledContent(AppText.resource("Next reminder")) {
                        Text(verbatim: AppFormatting.dateTime(
                            nextTriggerDate,
                            locale: locale,
                            timeZone: viewModel.model.calendarTimeZone
                        ))
                    }
                } else {
                    Label(AppText.resource("Scheduled"), systemImage: "bell.badge")
                }
            }
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        switch viewModel.state {
        case .editing:
            EmptyView()
        case .scheduling:
            Section {
                HStack {
                    ProgressView()
                    Text(AppText.resource("Scheduling reminder…"))
                }
            }
            .accessibilityIdentifier(AppAccessibilityIdentifier.result(.loading))
        case let .scheduled(result):
            Section(AppText.resource("Result")) {
                Label(AppText.resource("Reminder scheduled"), systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityIdentifier("result.product-reminder.scheduled")
                if result == .scheduledWithWarning(.textOnlyAttachmentFallback) {
                    Label(
                        AppText.resource("The reminder was scheduled without a product image."),
                        systemImage: "exclamationmark.triangle"
                    )
                    .foregroundStyle(.orange)
                }
            }
            .accessibilityFocused($resultIsFocused)
            .accessibilityIdentifier(AppAccessibilityIdentifier.result(.actualSuccess))
        case let .failed(_, error):
            Section(AppText.resource("Result")) {
                Label(errorMessage(error), systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("result.product-reminder.failed")
            }
            .accessibilityFocused($resultIsFocused)
            .accessibilityIdentifier(AppAccessibilityIdentifier.result(.actualFailure))
        }
    }

    private var actionsSection: some View {
        Section {
            Button(AppText.resource("Schedule reminder")) {
                Task { await viewModel.schedule() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isScheduling)
            .frame(minHeight: 44)
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier(AppAccessibilityIdentifier.action(.scheduleReminder))

            if canCancel {
                Button(AppText.resource("Cancel reminder"), role: .destructive) {
                    Task { await viewModel.cancel() }
                }
                .disabled(isScheduling)
                .frame(minHeight: 44)
                .accessibilityIdentifier("action.product-reminder.cancel")
            }
        }
    }

    private var calendarResolution: some View {
        let presentation = viewModel.model.calendarPresentation(locale: locale)
        return VStack(alignment: .leading, spacing: 4) {
            LabeledContent(AppText.resource("Resolved date"), value: presentation.date)
            LabeledContent(AppText.resource("Resolved time"), value: presentation.time)
            LabeledContent(AppText.resource("Resolved time zone"), value: presentation.timeZone)
        }
    }

    private var selectionBinding: Binding<SelectionKind> {
        Binding(
            get: {
                switch viewModel.model.selection {
                case .quickTest: .quickTest
                case .interval: .interval
                case .calendar: .calendar
                }
            },
            set: { value in
                var model = viewModel.model
                switch value {
                case .quickTest:
                    model.selection = .quickTest
                case .interval:
                    model.selection = .interval(
                        seconds: TimeInterval(model.intervalText) ?? 60,
                        repeats: false
                    )
                case .calendar:
                    model.selection = .calendar(
                        date: model.calendarDate,
                        timeZone: model.calendarTimeZone
                    )
                }
                viewModel.model = model
            }
        )
    }

    private var intervalTextBinding: Binding<String> {
        Binding(
            get: { viewModel.model.intervalText },
            set: { value in
                var model = viewModel.model
                model.intervalText = String(value.prefix(12))
                viewModel.model = model
            }
        )
    }

    private var repeatsBinding: Binding<Bool> {
        Binding(
            get: {
                guard case let .interval(_, repeats) = viewModel.model.selection else {
                    return false
                }
                return repeats
            },
            set: { repeats in
                var model = viewModel.model
                model.selection = .interval(
                    seconds: TimeInterval(model.intervalText) ?? 0,
                    repeats: repeats
                )
                viewModel.model = model
            }
        )
    }

    private var calendarDateBinding: Binding<Date> {
        Binding(
            get: { viewModel.model.calendarDate },
            set: { date in
                var model = viewModel.model
                model.calendarDate = date
                model.selection = .calendar(date: date, timeZone: model.calendarTimeZone)
                viewModel.model = model
            }
        )
    }

    private var calendarTimeZoneBinding: Binding<String> {
        Binding(
            get: { viewModel.model.calendarTimeZone.identifier },
            set: { identifier in
                guard let timeZone = TimeZone(identifier: identifier) else { return }
                var model = viewModel.model
                model.calendarTimeZone = timeZone
                model.selection = .calendar(date: model.calendarDate, timeZone: timeZone)
                viewModel.model = model
            }
        )
    }

    private var currentStatus: ProductReminderStatus {
        switch viewModel.state {
        case .scheduled: .scheduled(nextTriggerDate: nil)
        case .editing, .scheduling, .failed: viewModel.currentStatus
        }
    }

    private var isScheduling: Bool {
        if case .scheduling = viewModel.state { return true }
        return false
    }

    private var canCancel: Bool {
        if case .scheduled = viewModel.state { return true }
        if case .scheduled = currentStatus { return true }
        return false
    }

    private var announcementText: String? {
        switch viewModel.state {
        case let .scheduled(result):
            if result == .scheduledWithWarning(.textOnlyAttachmentFallback) {
                return AppText.string("Reminder scheduled without a product image.")
            }
            return AppText.string("Reminder scheduled.")
        case let .failed(_, error):
            return errorMessage(error)
        case .editing, .scheduling:
            return nil
        }
    }

    private func errorMessage(_ error: ProductReminderViewError) -> String {
        switch error {
        case .invalid(.interval):
            AppText.string("Enter a valid reminder interval.")
        case .invalid(.calendarDate):
            AppText.string("Choose a future date within one year.")
        case .authorizationDenied:
            AppText.string("Notifications are not allowed. You can enable them in system settings.")
        case .schedule:
            AppText.string("The reminder could not be scheduled. Try again.")
        }
    }
}
