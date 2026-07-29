import SwiftUI

struct ProjectInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ProjectInfoViewModel

    init(
        projectID: ProjectItem.ID,
        store: ProjectsStore
    ) {
        _viewModel = State(
            initialValue: ProjectInfoViewModel(
                projectID: projectID,
                store: store
            )
        )
    }

    var body: some View {
        Group {
            if let project = viewModel.project {
                Form {
                    Section("Project") {
                        LabeledContent("Name", value: project.title)
                        LabeledContent("Summary", value: project.summary)
                        LabeledContent("Color", value: project.colorName)
                        LabeledContent(
                            "Tasks",
                            value: String(project.tasks.count)
                        )
                    }

                    Section {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            } else {
                VStack(spacing: 16) {
                    EmptyStateView(
                        title: "Project Unavailable",
                        systemImage: "questionmark.folder",
                        message: "This project no longer exists."
                    )

                    Button("Done") {
                        dismiss()
                    }
                }
                .padding()
            }
        }
    }
}
