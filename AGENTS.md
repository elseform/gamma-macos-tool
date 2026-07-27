# Agent Workflow

This repository builds a native macOS SwiftUI setup tool for creating a Sikarugir wrapper around an existing S.T.A.L.K.E.R. G.A.M.M.A. install. Treat it as a user-facing installer: small behavioral changes can affect real game installs, Wine prefixes, downloaded archives, and wrapper settings.

## Current Project State

- The main implementation is Swift 5.9 targeting macOS 13.
- The package has three source areas:
  - `sources/GAMMASetupTool/`: SwiftUI app, state model, app settings, and user flow.
  - `sources/GAMMASetupCore/`: shared setup models, preflight checks, path helpers, wrapper setup engine, and installation logic.
  - `sources/GAMMASetupEngine/`: command-line backend launched by the GUI.
- The local build script creates `dist/GAMMA Setup Tool.app` and embeds `gamma-setup-engine`.

## Standard Workflow

1. Start with repository state.
   - Run `git status --short`.
   - Read the relevant files before editing; do not assume previous context is current.
   - If there are uncommitted changes you did not make, preserve them and work around them.

2. Scope the task.
   - Identify whether the change affects UI-only behavior, setup request construction, setup engine behavior, persisted settings, wrapper detection, build packaging, or tests.
   - Prefer the smallest change that satisfies the request.
   - Avoid broad rewrites unless the user explicitly asks for them.

3. Follow the existing split.
   - Put SwiftUI layout and controls in `ContentView*.swift` or `Components.swift`.
   - Put derived UI state in `AppModel+Computed.swift`.
   - Put selection and flow actions in `AppModel+Actions.swift`.
   - Put setup request construction, process execution, and event handling in `AppModel+Engine.swift`.
   - Put cross-target setup data and behavior in `GAMMASetupCore`.
   - Put CLI argument parsing and top-level command dispatch in `GAMMASetupEngine/main.swift`.

4. Edit conservatively.
   - Keep behavior-preserving cleanup separate from behavior changes when practical.
   - Keep UI copy direct and user-facing; this app is a wizard, not a marketing page.
   - Keep renderer strings stable: `d3dmetal`, `dxvk`, and `dxmt` are serialized into setup requests and tests.
   - Keep setup stages stable unless the UI progress mapping is updated with tests.

5. Verify the changed surface.
   - Run focused checks first when possible.
   - Run `git diff --check` before finishing.
   - Run `./test.sh` for normal code changes. It covers Swift model tests, setup engine CLI tests, and a build smoke test.
   - If a task only changes docs, `git diff --check` is usually enough.

6. Report honestly.
   - Mention tests run.
   - Mention tests not run and why.
   - Always state whether `dist/GAMMA Setup Tool.app` was rebuilt during the task.
   - Call out any behavior-sensitive areas touched, especially wrapper recreation, downloaded resources, Wine registry settings, or `winetricks`.

## Build And Test Commands

- Full verification:

  ```text
  ./test.sh
  ```

- Build app bundle:

  ```text
  ./build.sh
  ```

- Build and run app bundle:

  ```text
  ./build.sh run
  ```

- Clean local app build output:

  ```text
  ./build.sh clean
  ```

- SwiftPM build:

  ```text
  swift build
  ```

- SwiftPM run:

  ```text
  swift run GAMMASetupTool
  ```

Prefer `./test.sh` before handing off a code change because it matches this repo's non-SwiftPM test harness and build smoke test.

## Hard Rules

- Do not run the GUI or setup engine against a real GAMMA install unless the user explicitly asks for that validation.
- Do not intentionally modify files under a user's GAMMA install, Anomaly folder, Wine prefix, Sikarugir app, Homebrew installation, or cache while testing unless the user approved the exact live-system operation.
- Use dry-run behavior, temporary directories, and fake tools for setup engine tests.
- Do not remove or rewrite user-created wrappers while debugging. Wrapper recreation is user-visible and can destroy local prefix state.
- Do not change the required `winetricks` group casually. `corefonts`, `d3dx9_43`, `d3dx11_43`, `d3dcompiler_47`, and `vcrun2026` are the expected wrapper baseline.
- Do not change renderer option semantics without checking all paths: UI controls, `SetupConfiguration`, request construction, engine application, and tests.
- Do not write to `user.ltx`. The setup tool reads game resolution for context only.
- Do not commit build output, logs, module caches, local reports, temporary archives, or generated app bundles.
- Do not commit local machine paths except in ignored local notes. Repository docs should use placeholders for user-specific paths.
- Do not hide failing tests by weakening assertions around setup behavior. If behavior changed intentionally, update tests to state the new contract.

## Behavior-Sensitive Areas

- Existing targets: normal setup must refuse to inspect, update, or overwrite an existing app. Explicit engine replacement remains a separate destructive operation.
- Display settings: forced Wine display mode writes Retina/DPI compatibility keys; default Wine mode removes only keys managed by this tool.
- Renderer setup: D3DMetal is the default; DXVK and DXMT have separate config and HUD/log options.
- Short Wine drive mapping: path mapping is based on the detected macOS install path and `ModOrganizer.ini`.
- `mo2.bat`: generated launch script sets ModOrganizer Qt variables and selected renderer environment.
- Cached downloads: engine/template resources may come from Sikarugir's app support folder or this tool's cache.
- Verbose logs: saved logs live in `~/` and should remain opt-in.

## UI Rules

- Keep the wizard flow simple and default-driven. Advanced settings should not block the normal default path.
- Keep explanatory text short enough to scan inside the app window.
- Prefer existing reusable controls in `Components.swift` and spacing constants in `Layout.swift`.
- Keep state derivation in `AppModel` extensions instead of embedding complex logic directly in SwiftUI view builders.
- Any new user-facing option needs:
  - a stored/default value in `AppModel` or settings as appropriate
  - request serialization in `AppModel+Engine.swift`
  - backend handling in `GAMMASetupCore` or `GAMMASetupEngine`
  - tests for request construction when practical

## Testing Rules

- Add or update Swift tests in `tests/swift/` for pure model/configuration behavior.
- Add or update shell tests in `tests/shell/gamma_setup_engine_tests.sh` for CLI behavior and setup engine command effects.
- Tests should use temporary directories and fake executables rather than live tools.
- Keep tests deterministic; avoid network, Homebrew, Sikarugir, or real `winetricks` calls.
- When a change touches process output or progress stages, verify both human-readable messages and machine-readable event handling.

## Repository Todo

Keep this list current. Move items to a task-specific plan when actively working on them.

### High Priority

- Add focused tests for display mode transitions: forced mode writes managed keys, default mode removes only managed keys, and `user.ltx` remains read-only.
- Keep release packaging reproducible: verify `build.sh` embeds the backend, icons, SVG resources, `usvfs`, and bundled reticle-fix archive after resource changes.

### Medium Priority

- Split very large setup-engine helper sections only when doing so reduces risk and keeps behavior unchanged.
- Improve setup-engine test fixtures for fake Sikarugir templates and cached engine archives.
- Add a small developer note for the release process if releases continue to be built outside CI.
- Review user-facing error text for setup failures and make sure each failure has a concrete recovery action.
- Keep README setup-engine details synchronized when engine behavior changes.

### Low Priority

- Consider a small manual QA checklist for the app flow with screenshots or notes for each wizard page.
- Consider adding a lightweight changelog once release cadence becomes regular.
- Consider extracting repeated SwiftUI row patterns only if duplication starts obscuring behavior.

## Definition Of Done

- The requested change is implemented or the blocker is clearly documented.
- Relevant tests pass, or skipped tests are named with a concrete reason.
- `git diff --check` passes.
- Docs and README updates are included when behavior or commands change.
- No unrelated user changes were reverted.
- The final response names the files changed and the verification performed.
- The final response explicitly states whether the app bundle was rebuilt.
