# Screen State And Model Scaffold Design

## Goal

Give every screen both a screen-owned `State` scaffold and a screen-owned
`Model` scaffold while leaving presentation `Item` models in `Model`.

## Architecture

Screen state belongs beside the screen because it is owned and mutated by that
screen's ViewModel. Screen models also belong beside the screen because they are
the local extension point for presentation mapping and UI-only data. Shared
reusable state stays in `App/Models/State`. Feature-scoped state shared by
multiple screens stays at `Features/<Feature>/State`.

## Ownership Rules

- `App/Models/State` owns app-wide state and generic reusable state containers.
- `Features/<Feature>/State` owns state or failures shared by multiple screens
  inside one feature.
- `Features/<Feature>/Screens/<Screen>/State` owns render state used only by
  that screen's ViewModel.
- `Features/<Feature>/Screens/<Screen>/Model` owns the screen's `<Screen>Model`
  scaffold even when unused, plus screen-specific presentation models such as
  rows, cards, and `Item` types.
- `Item` naming does not decide ownership.

## Target Structure

Every current screen has a `State` folder with one screen state scaffold:

```text
Features/Authentication/Screens/Authentication/State/AuthenticationState.swift
Features/Browse/Screens/Browse/State/BrowseListState.swift
Features/Browse/Screens/BrowseDetail/State/BrowseDetailState.swift
Features/Home/Screens/Home/State/HomeState.swift
Features/Home/Screens/HomeDetails/State/HomeDetailsState.swift
Features/Home/Screens/NavigationGuide/State/NavigationGuideState.swift
Features/Settings/Screens/About/State/AboutState.swift
Features/Settings/Screens/Settings/State/SettingsState.swift
```

Every current screen also has a `Model` folder with one screen model scaffold:

```text
Features/Authentication/Screens/Authentication/Model/AuthenticationModel.swift
Features/Browse/Screens/Browse/Model/BrowseModel.swift
Features/Browse/Screens/BrowseDetail/Model/BrowseDetailModel.swift
Features/Home/Screens/Home/Model/HomeModel.swift
Features/Home/Screens/HomeDetails/Model/HomeDetailsModel.swift
Features/Home/Screens/NavigationGuide/Model/NavigationGuideModel.swift
Features/Settings/Screens/About/Model/AboutModel.swift
Features/Settings/Screens/Settings/Model/SettingsModel.swift
```

`NavigationGuideItem` remains in
`Features/Home/Screens/NavigationGuide/Model/NavigationGuideItem.swift` because
it is a presentation item, not render state.

`BrowseFailure` moves to `Features/Browse/State/BrowseFailure.swift` because it
is shared by the Browse list and Browse detail screen states, but not by the
whole app.

## Testing

Run the full app test suite on macOS and iOS simulator after the move. Update
generic state tests so `LoadableStateTests` does not depend on Browse-specific
state.
