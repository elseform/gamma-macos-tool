# Refactor And Cleanup Plan

## Summary

Create a new branch from `master` named `refactor-and-cleanup`. Port only the conservative cleanup value from `refactor`: organization, readability, small duplication reduction, and tiny low-risk UI polish. Do not cherry-pick the broken branch wholesale, and do not intentionally change setup behavior, engine commands, install flow, failure handling, saved logs, or wrapper-setting detection.

## Key Changes

- Branch setup:
  - Start from current `master`.
  - Create/switch to exact branch name `refactor-and-cleanup`.
  - If the worktree is dirty before branching, stop and consult instead of stashing or overwriting.

- `AppModel` cleanup:
  - Keep stored `@Published` state, small supporting structs/enums, and `init` in `AppModel.swift`.
  - Split existing behavior into extension files without changing API names or logic:
    - `AppModel+Computed.swift`: configuration-derived computed properties, setup summary, environment messages.
    - `AppModel+Actions.swift`: directory pickers, preflight/create/install/open actions.
    - `AppModel+Engine.swift`: engine request construction, process execution, log streaming, stage/event handling.
    - `AppModel+WrapperSettings.swift`: existing wrapper detection, settings application, plist/registry/marker parsing.
  - Preserve all current engine integration exactly: `--request-file`, `install-dependencies`, `install-dependency`, `SetupEngineEvent`, stage tracking, artifact log path handling, and fallback stage inference.

- SwiftUI cleanup:
  - Keep the existing page-file split (`ContentView+Environment.swift`, `ContentView+Setup.swift`, `ContentView+CreateComplete.swift`, and `ContentView+Navigation.swift`) and add clear `MARK` sections/private helpers only where it improves scanability.
  - Keep current environment/create/complete behavior intact, including setup review before create, failure view, output disclosure, saved-log link, and install buttons.
  - Apply tiny polish only:
    - Use bundle `CFBundleShortVersionString` in footer with fallback `"0.69"`.
    - Combine duplicated header title/subtitle switch logic into one private computed value.
    - Move repeated link URL strings into local constants.

- Helper cleanup:
  - Use `defer` in `OutputBuffer.stringValue()` for lock release.
  - Convert simple immutable data holders to `let` where behavior is unchanged.
  - Remove trailing whitespace and ensure final newlines.
  - Do not introduce new app state names from the broken refactor branch.

## Implementation Order

1. Create `refactor-and-cleanup` from current `master`.
2. Apply tiny helper/UI cleanups that are easy to verify independently.
3. Split `AppModel` mechanically into extensions by responsibility, changing cross-file helpers from `private` to module-internal only where needed.
4. Run verification after each meaningful slice, with a final full `./test.sh` pass.

## Tests And Verification

- Run `git diff --check`.
- Run the existing test entrypoint, preferably `./test.sh`.
- Run `swift build` if needed to verify SwiftPM compilation; if sandbox cache permissions block it, rerun with approval rather than changing project files.
- Compare behavior-sensitive diffs manually:
  - Engine command arguments remain unchanged.
  - `enableFnToggle` remains wired through `AppModel`, `SetupConfiguration`, UI, and tests.
  - Install failure and saved-log behavior remains present.
  - Existing wrapper settings detection still reads marker/plist/registry fallbacks.

## Assumptions

- Conservative means behavior-preserving refactor first, not redesigning app state or UI flow.
- Tiny UI polish is allowed only when it is low-risk and easy to review.
- The broken `refactor` branch is reference material only; implementation should be manual, selective, and based on `master`.
