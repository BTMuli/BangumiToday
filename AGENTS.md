# Project Agent Rules

## Git commits

- Never commit on your own initiative. After finishing a change, stop at the working tree and report it; only run `git commit` (or any other history-changing command such as `amend`, `rebase`, `cherry-pick`, `revert`, or `push`) when the user explicitly asks you to commit in that request.
- Deleting throwaway test files and other cleanup is still expected before you report the change as done.
- When you are asked to commit, commit messages must use the repository's Gitmoji format: `<emoji> <description>`.
- Commit subjects and bodies use Chinese, with a concise imperative description in the subject. This project's commit language and style are fixed by these rules; do not read Git history to infer them or imitate past wording.
- Use the project [gitmoji-commit skill](.agents/skills/gitmoji-commit/SKILL.md) and its [selection reference](.agents/skills/gitmoji-commit/references/emoji-selection.md). Choose the emoji from the commit's primary intent and actual staged diff, using the [official Gitmoji semantics](https://gitmoji.dev/); consider specific-purpose icons before generic ones.
- Do not limit selection to familiar icons or force variety. Prefer a specific icon when it describes the primary intent; an incidental implementation detail does not override that intent.
- Do not add Conventional Commit prefixes such as `fix:` or `feat:` after the emoji.

## Dependencies

- Keep package entries in `pubspec.yaml` alphabetically ordered by package name within `dependencies`, `dev_dependencies`, and `dependency_overrides` when present. Preserve each package's version, source configuration, and associated comments when reordering.

## Tests

- Test files written while implementing a change are throwaway verification aids. After the feature or fix has been verified, delete them before creating the commit that delivers the change.
- Do not commit test files, test fixtures, or test-only helper scripts unless the user explicitly asks for them to be committed.
- If test files were already staged, unstage and delete them before committing.
- Unless explicitly told otherwise, do not write tests that require UI interaction (widget/page interaction, taps, navigation, dialogs, screenshots, and the like). The developer triggers those flows by hand.
- Only test functional behavior (pure logic, parsing, data transformations, protocol handling, persistence queries, and similar non-UI code). Do not go out of your way to build UI verification harnesses.
- Unless the user explicitly requests it, do not compile or build the entire project (for example, `flutter build` or `dev_build.ps1`) just to verify a change.
- This restriction does not apply to static code analysis. `flutter analyze`, `dart analyze`, MCP `analyze_files`, and similar code evaluation tools are allowed as needed; prefer analyzing the affected files when the tool supports it.
- The `bt_download` test suite remains opt-in and is run by hand by the developer: inside `repos/bt_download` run `cmake --preset windows-x64-debug-tests`, `cmake --build --preset windows-x64-debug-tests`, then `ctest --preset windows-x64-debug-tests`. Neither `dev_build.ps1` nor the release workflow may build or run it.
- Do not start the app, drive it through MCP tooling, or run manual UI verification unless the user explicitly asks for it.

## UI interaction

- Position flyouts outside their triggering controls with a visible gap, keeping the trigger fully visible while the panel is open.
- Open select and dropdown option panels below the selection field, or above it when space is limited. Never align the selected option over the field; constrain and scroll the panel when necessary to preserve the field's visibility.

## AniBT integration

- For AniBT RSS, Open API, release metadata, subscriptions, downloads, or AniBT UI changes, read the project [anibt skill](.agents/skills/anibt/SKILL.md).
- Verify API behavior against the current official Markdown or OpenAPI documents linked by the skill before changing endpoints, parameters, authentication, or parsing.
- Use the [bangumi-today skill](.agents/skills/bangumi-today/SKILL.md) for repository architecture and the [flutter-mcp skill](.agents/skills/flutter-mcp/SKILL.md) for Flutter tooling alongside the AniBT skill.
