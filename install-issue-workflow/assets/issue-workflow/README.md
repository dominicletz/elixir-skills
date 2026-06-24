# Issue Workflow

This is a github label based simple workflow for having cursor work on issues and PRs. It's using "@cursor" comments to steer work.

## Labels

- `cursor-plan`: Optional pre-step on an issue — automation posts a `@cursor` prompt to produce a detailed feature design (aligned with product docs, market, and UX); removes this label only. The agent posts the plan as a comment and should add `cursor-pick` when ready to implement. (Only issues)
- `cursor-pick`: Assigns the issue to cursor. (Only issues)
- `cursor-pr-open`: Indicates that cursor has opened a PR (Only issues)
- `cursor-ignore`: Cursor will not work on this issue or PR.

- `cursor-waiting`: Cursor is done with the first pass, and is waiting 1h for gemini to review. If the PR has no comments yet, automation posts `@gemini review this PR` once, then waits. (Only PRs)
- `cursor-waiting-for-ci`: Automation is waiting for GitHub Actions on the PR; failures and **cancelled** runs get a `@cursor` prompt with details (still this label until CI is green). (Only PRs)
- `cursor-demo`: CI is green; automation posts a `@cursor` prompt to capture or refresh demo screenshots (computer use), then hands off. (Only PRs)
- `cursor-waiting-for-human`: Cursor automation is done; a human should review the PR. (Only PRs)

## Mermaid Diagram

```mermaid
flowchart TD
    P[cursor-plan · design in issue comments] -. optional .-> A[cursor-pick → work issue]
    A --> C[cursor-waiting · waiting for gemini review]
    C --> D[cursor-waiting-for-ci]
    D --> E[cursor-demo · screenshots]
    E --> F[cursor-waiting-for-human]
```

_Happy path only._ Retries (CI failures, cancelled runs, fix loops, `cursor-ignore`, and so on) are described in the label list above.
