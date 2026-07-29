import Observation

@MainActor
@Observable
final class QuickStartViewModel {
    let title = "Quick Start"
    let message =
        """
        Explore five independent flows—Authentication, Home, Browse, Projects, \
        and Settings—plus screen-owned simple sheets and the independent \
        create-project modal flow.
        """
}
