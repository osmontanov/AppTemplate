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
            .navigationTitle("Product reminder")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { await viewModel.refresh() }
        .onChange(of: viewModel.focusedField) { _, value in
            focusedField = value
        }
        .onChange(of: announcementText) { _, value in
            guard let value else { return }
            AccessibilityNotification.Announcement(value).post()
        }
        .frame(minWidth: 360, minHeight: 460)
        .accessibilityIdentifier("screen.store.product-reminder")
    }

    private var productSection: some View {
        Section("Product") {
            LabeledContent("Name", value: product.title)
            LabeledContent("Price") {
                Text(product.price, format: .currency(code: currencyCode))
            }
        }
    }

    private var selectionSection: some View {
        Section("When") {
            Picker("Reminder type", selection: selectionBinding) {
                Text("Quick test").tag(SelectionKind.quickTest)
                Text("Interval").tag(SelectionKind.interval)
                Text("Date and time").tag(SelectionKind.calendar)
            }
            .pickerStyle(.segmented)

            switch selectionBinding.wrappedValue {
            case .quickTest:
                Text("Schedules a one-time reminder in five seconds.")
                    .foregroundStyle(.secondary)
            case .interval:
                TextField("Seconds", text: intervalTextBinding)
                    .focused($focusedField, equals: .interval)
                    .accessibilityIdentifier("field.product-reminder.interval")
                Toggle("Repeat", isOn: repeatsBinding)
                Text("Use 1 to 604,800 seconds. Repeating reminders require at least 60 seconds.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .calendar:
                DatePicker(
                    "Date and time",
                    selection: calendarDateBinding,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .focused($focusedField, equals: .calendarDate)
                .accessibilityIdentifier("field.product-reminder.calendar-date")
                Picker("Time zone", selection: calendarTimeZoneBinding) {
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
        Section("Status") {
            switch currentStatus {
            case .notScheduled:
                Label("Not scheduled", systemImage: "bell.slash")
                    .accessibilityIdentifier("status.product-reminder.not-scheduled")
            case let .scheduled(nextTriggerDate):
                if let nextTriggerDate {
                    LabeledContent("Next reminder") {
                        Text(nextTriggerDate, format: triggerDateStyle)
                    }
                } else {
                    Label("Scheduled", systemImage: "bell.badge")
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
                    Text("Scheduling reminder…")
                }
            }
        case let .scheduled(result):
            Section("Result") {
                Label("Reminder scheduled", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityIdentifier("result.product-reminder.scheduled")
                if result == .scheduledWithWarning(.textOnlyAttachmentFallback) {
                    Label(
                        "The reminder was scheduled without a product image.",
                        systemImage: "exclamationmark.triangle"
                    )
                    .foregroundStyle(.orange)
                }
            }
        case let .failed(_, error):
            Section("Result") {
                Label(errorMessage(error), systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("result.product-reminder.failed")
            }
        }
    }

    private var actionsSection: some View {
        Section {
            Button("Schedule reminder") {
                Task { await viewModel.schedule() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isScheduling)
            .accessibilityIdentifier("action.product-reminder.schedule")

            if canCancel {
                Button("Cancel reminder", role: .destructive) {
                    Task { await viewModel.cancel() }
                }
                .disabled(isScheduling)
                .accessibilityIdentifier("action.product-reminder.cancel")
            }
        }
    }

    private var calendarResolution: some View {
        let presentation = viewModel.model.calendarPresentation(locale: locale)
        return VStack(alignment: .leading, spacing: 4) {
            LabeledContent("Resolved date", value: presentation.date)
            LabeledContent("Resolved time", value: presentation.time)
            LabeledContent("Resolved time zone", value: presentation.timeZone)
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

    private var currencyCode: String {
        locale.currency?.identifier ?? "USD"
    }

    private var triggerDateStyle: Date.FormatStyle {
        var style = Date.FormatStyle(date: .abbreviated, time: .shortened)
            .timeZone(.specificName(.short))
            .locale(locale)
        style.timeZone = viewModel.model.calendarTimeZone
        return style
    }

    private var announcementText: String? {
        switch viewModel.state {
        case let .scheduled(result):
            if result == .scheduledWithWarning(.textOnlyAttachmentFallback) {
                return "Reminder scheduled without a product image."
            }
            return "Reminder scheduled."
        case let .failed(_, error):
            return errorMessage(error)
        case .editing, .scheduling:
            return nil
        }
    }

    private func errorMessage(_ error: ProductReminderViewError) -> String {
        switch error {
        case .invalid(.interval):
            "Enter a valid reminder interval."
        case .invalid(.calendarDate):
            "Choose a future date within one year."
        case .authorizationDenied:
            "Notifications are not allowed. You can enable them in system settings."
        case .schedule:
            "The reminder could not be scheduled. Try again."
        }
    }
}
