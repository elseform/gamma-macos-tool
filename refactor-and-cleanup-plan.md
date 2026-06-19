# Refactor And Cleanup Plan

## Summary

Continue the conservative cleanup on `refactor-and-cleanup`. Port only the remaining low-risk value from `refactor`: readability, small duplication reduction, and tiny UI organization improvements. Do not cherry-pick the broken branch wholesale, and do not intentionally change setup behavior, engine commands, install flow, failure handling, saved logs, or wrapper-setting detection.

## Current Status

- Branch `refactor-and-cleanup` exists and is active.
- `AppModel` has been split into `AppModel+Computed.swift`, `AppModel+Actions.swift`, `AppModel+Engine.swift`, and `AppModel+WrapperSettings.swift`.
- Completed tiny polish:
  - Footer uses bundle `CFBundleShortVersionString` with fallback `"0.69"`.
  - Header title/subtitle switch logic is combined into one private computed value.
  - Footer link URLs are local constants.
  - `OutputBuffer.stringValue()` releases its lock with `defer`.
- Completed follow-up cleanup:
  - Extension-file helpers were tightened back to `private` where cross-file access is not needed.
  - Existing SwiftUI page files now have `MARK` sections and private page-local helpers.
  - Simple immutable data holders use `let` where behavior is unchanged.
- Final checkpoint passed `git diff --check` and `./test.sh`.

## Remaining Work

- None for the conservative cleanup slice.

## Implementation Order

1. Prepare the diff for review or commit.

## Tests And Verification

- `git diff --check` passed.
- `./test.sh` passed.
- Behavior-sensitive diff review passed:
  - Engine command arguments remain unchanged.
  - `enableFnToggle` remains wired through `AppModel`, `SetupConfiguration`, UI, and tests.
  - Install failure and saved-log behavior remains present.
  - Existing wrapper settings detection still reads marker/plist/registry fallbacks.

## Assumptions

- Conservative means behavior-preserving refactor first, not redesigning app state or UI flow.
- Tiny UI polish is allowed only when it is low-risk and easy to review.
- The broken `refactor` branch is reference material only; implementation should be manual, selective, and based on `master`.
