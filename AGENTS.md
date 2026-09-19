# Project Agent Rules

## Git commits

- Commit messages must use the repository's Gitmoji format: `<emoji> <description>`.
- Choose a Gitmoji that matches the change type, following recent repository history (for example: `🐛` for fixes, `✨` for features, `♻️` for refactors, and `💄` for UI or style changes).
- Do not use Conventional Commit prefixes such as `fix:` or `feat:` without a Gitmoji.

## Tests

- Test files written while implementing a change are throwaway verification aids. After the feature or fix has been verified, delete them before creating the commit that delivers the change.
- Do not commit test files, test fixtures, or test-only helper scripts unless the user explicitly asks for them to be committed.
- If test files were already staged, unstage and delete them before committing.
