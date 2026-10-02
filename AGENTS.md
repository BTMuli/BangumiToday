# Project Agent Rules

## Git commits

- Commit messages must use the repository's Gitmoji format: `<emoji> <description>`.
- Choose a Gitmoji that matches the change type, following recent repository history (for example: `🐛` for fixes, `✨` for features, `♻️` for refactors, and `💄` for UI or style changes).
- Do not use Conventional Commit prefixes such as `fix:` or `feat:` without a Gitmoji.

## Tests

- Test files written while implementing a change are throwaway verification aids. After the feature or fix has been verified, delete them before creating the commit that delivers the change.
- Do not commit test files, test fixtures, or test-only helper scripts unless the user explicitly asks for them to be committed.
- If test files were already staged, unstage and delete them before committing.
- Unless explicitly told otherwise, do not write tests that require UI interaction (widget/page interaction, taps, navigation, dialogs, screenshots, and the like). The developer triggers those flows by hand.
- Only test functional behavior (pure logic, parsing, data transformations, protocol handling, persistence queries, and similar non-UI code). Do not go out of your way to build UI verification harnesses.
- Do not spend time verifying compilation (full builds, `flutter analyze`, `analyze_files`, and similar compile checks). The only exception is `bt_download`, which is still tested by hand by the developer.
- Do not start the app, drive it through MCP tooling, or run manual UI verification unless the user explicitly asks for it.

## AniBT integration

- For AniBT RSS, Open API, release metadata, subscriptions, downloads, or AniBT UI changes, read the project [anibt skill](.agents/skills/anibt/SKILL.md).
- Verify API behavior against the current official Markdown or OpenAPI documents linked by the skill before changing endpoints, parameters, authentication, or parsing.
- Use the [bangumi-today skill](.agents/skills/bangumi-today/SKILL.md) for repository architecture and the [flutter-mcp skill](.agents/skills/flutter-mcp/SKILL.md) for Flutter tooling alongside the AniBT skill.
