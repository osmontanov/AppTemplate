import Observation

@MainActor
@Observable
final class HomeRouter: StackRouting {
    var path: [HomeRoute]
    var sheet: HomeSheetRoute?
    var alert: HomeAlertRoute?

    init(
        path: [HomeRoute] = [],
        sheet: HomeSheetRoute? = nil,
        alert: HomeAlertRoute? = nil
    ) {
        self.path = path
        self.sheet = sheet
        self.alert = alert
    }
}
