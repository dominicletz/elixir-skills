---
name: branch-code-review
description: Use when the user asks to review a branch, review code changes, code review a PR, check branch quality, or evaluate changes against project guidelines.
---

# Branch Code Review

Reviews code changes in the current or specified branch against project guidelines in `AGENTS.md`. Finds real bugs first, guideline violations second. Scores by a fixed formula, so the score reflects the open findings and nothing else.

This project copy is the authoritative version of this skill. Other copies (`~/.cursor/skills/...`) can be out of date.

## Principles

- **Correctness first.** A review that finds only style issues has probably not read the code deeply enough. See "Behavior checks".
- **Unrelated changes are fine.** Do not flag a change because it is outside the PR goal. Review it like any other change: it must be correct and follow the guidelines.
- **No flip-flopping.** If an earlier review recommended a pattern and the code follows it, do not recommend the opposite pattern. Only report it if it is a bug.
- **Respect decisions.** Never re-report an item listed under "Review decisions".
- **Do not edit guidelines inside the loop.** If you find a gap in `AGENTS.md` or the docs, report it under "Guideline gaps". Do not change guidelines while you review or fix code.

## Prerequisites

- Git repository with a base branch (typically `master` or `origin/master`)
- Optional: [GitHub CLI](https://cli.github.com/) (`gh`) installed and authenticated for PR comments

## Workflow

### 1. Determine scope

- **Current branch**: `git diff origin/master...HEAD`. **Named branch**: `git diff origin/master...<branch>`.
- **Delta review**: If an earlier review output or PR comment contains `Reviewed commit: <sha>`, review `git diff <sha>..HEAD` as the new code. Read the rest of the branch only to understand context and to check old findings (step 2).
- Include uncommitted changes (`git diff HEAD`) when they exist, and say so.

### 2. Collect context

**PR feedback** (if the branch has a PR):

```bash
gh pr view --json number,body,title,comments,reviews,url
gh api repos/{owner}/{repo}/pulls/{number}/comments
```

Include the PR number and URL, general comments, and inline review comments.

**Review decisions.** Look for a `## Review decisions` section in the PR description or PR comments, and for decisions the user gave in the chat. Each entry is an accepted item that you must not report again. Example: "GroupChat change stays in this PR."

**Previous findings.** Collect the findings of earlier reviews (PR comments, chat). For each one, state: `fixed`, `open`, or `declined (decision)`. Open findings stay in the list with their original severity.

If no PR exists or `gh` is unavailable, continue without PR data.

### 3. Determine intended goal and review for correctness

**3a. Intended goal**

- From the PR title and body, or from a linked issue (`Closes #123`: run `gh issue view <number>`).
- Fallback: infer the goal from the code and commits. State that the goal was inferred.

**3b. Correctness review**

1. **Logic**: Is the logic sound? Are edge cases handled?
2. **Goal alignment**: Does the code reach the goal? Look for gaps (missing validation, wrong branch, wrong handling).
3. **Behavior checks** (required, see below).
4. **Tests**: Does a test cover each risky behavior? A test that avoids the risky case does not count.

### Behavior checks

Do these for every new interaction with a dependency or another module:

- **Read the callee.** Open the source (`deps/<name>/lib`, or `lib/`) of every function whose semantics matter: `Globals`, `Debouncer`, `Registry`, `GenServer` calls, ETS, timers. Do not assume.
- **Repeat the event.** For each notification, cache, dedupe, debounce, or "only on change" logic, ask: does the second identical event still work? Does a second process or session with the same key still work?
- **Check keys.** Are global keys, ETS keys, and debounce keys unique per process, drive, and peer where they need to be?
- **Check the lifecycle.** Who creates, owns, and cleans up each process, table, timer, and subscription?
- **Check user-visible text.** Could the new state show a wrong label for a common case (for example the own device, an empty list, a single member)?

If you cannot verify a suspected bug by reading, run a small test or a script. Report unverified suspicions as `(unverified)`.

### 4. Review against guidelines

Read `AGENTS.md` and check the changed code against its rules:

- **Elixir**, **State and ETS** (tables created once at boot, see `docs/ets-tables.md`; cleanup in `terminate/2`), **Globals compartment**
- **Phoenix** and **Phoenix HTML** (`assign_async`, `.failed`, no SQL or blocking work in `mount`, `handle_params`, `handle_event`), **Gettext**
- **Architecture** (SQL in models, logic out of views, no wrappers), **Security**
- **UI/UX and frontend styling** (Tailwind in HEEx, `DdriveWeb.Frontend.*`, see `docs/frontend.md`)
- **Tests** (`test/BEST_PRACTICE.md`: no sleeps to advance time, cleanup through the owner's function)
- **Compliance**: `mix format --check-formatted`, lint passing

Do not copy `AGENTS.md` into the review. Reference section names.

### 5. Assign severity

| Severity | Meaning | Score effect |
|----------|---------|--------------|
| **Blocker** | Wrong behavior, crash, data loss, security problem, or a broken test or build. | −4 each |
| **Major** | A likely bug in a real case; a risky behavior without a test; a violation of a "never" or "must" rule that has real impact (for example SQL in `handle_params`). | −2.5 each |
| **Minor** | A guideline violation with no behavior impact; duplicated code. | −0.5 each, total at most −2 |
| **Nit** | Style or conciseness preference with no guideline behind it. | 0 |

Rules:

- Conciseness is a **Nit**, unless the code is duplicated (then **Minor**).
- List at most 5 Nits. Put them under "Optional".
- Do not mix severities to inflate the list. One root cause is one finding.

### 6. Score

`Score = 10 − deductions` from the table, rounded to the nearest 0.5, minimum 1. Show the calculation.

- **Merge-ready** means no open Blocker and no open Major. This always gives a score of 8 or more.
- The score depends on the open findings only. The number of fixed findings, the size of the diff, and the number of earlier rounds do not change it.

### 7. Output structure

```markdown
### Intended goal
[One sentence. Say if inferred.]

Reviewed commit: <sha>   [and "plus uncommitted changes" if true]

### Previous findings
- [finding] — fixed | open | declined (decision)

### Findings
- **[Blocker|Major|Minor] [Category]** [Issue]: [File:line]. [Why it is a problem. How you verified it.]

### Optional (Nits)
- ...

### GitHub PR comments
- [Author] on `path:line`: [Comment]

### Guideline gaps
- [Gap in AGENTS.md or docs, if any]

---

## Score: X/10
[Calculation, for example: 10 − 2.5 (1 Major) − 1 (2 Minor) = 6.5 → 6.5. Merge-ready: yes/no.]

---

## Prompts to fix findings
- **Finding [n]**: "In [file], [fix]. Per AGENTS.md [section]."
```

### 8. Propose posting to GitHub PR

If a PR exists and the review is merge-ready, ask: "Would you like me to post this review as a comment on the PR?" Post with `gh pr comment --body-file -` only after the user confirms.

If the review is not merge-ready, do not propose posting. Suggest a fix round.

## Fix rounds

When the user asks you to fix review findings:

1. **Fix every finding** (Blocker, Major, Minor, and Nits) unless the user limits the scope. Do not drop items silently.
2. **Do not widen the change.** Do not add rules, docs, or refactors that no finding asks for.
3. **Add a test** for every Blocker and Major bug. The test must fail without the fix.
4. **Run** `mix format`, `mix lint:quick`, and the tests of the touched modules.
5. **End with a closure table.** Every finding gets one row:

   | # | Finding | Result | Where |
   |---|---------|--------|-------|
   | 1 | ... | fixed / declined / deferred | commit or `file:line`, or the reason |

   A `declined` or `deferred` row needs a reason. Add declined rows to the `## Review decisions` section of the PR description (or ask the user to confirm), so that the next review does not report them again.

## Stopping rule

- Run at most **two** fix-and-review rounds for one set of changes.
- After a review with no open Blocker and no open Major, stop. Nits in "Optional" do not require another round.
- If a third round still has Blockers or Majors, stop and tell the user what is blocking, instead of continuing to polish.

## Example prompts

**Bug (Major):**
```
In lib/folder/zone_state.ex, put/3 calls Globals.set on a key that holds the peer address. Globals.put skips the broadcast when the value is unchanged, so a second change from the same peer sends no update. Use Globals.push and add a test where one peer changes twice.
```

**Guideline (Minor):**
```
In lib/ddrive_web/live/settings_live.ex around line 45, replace the case statement with a with expression per AGENTS.md Elixir guidelines.
```

## Additional resources

- Guidelines: `AGENTS.md` (project root)
- ETS tables: `docs/ets-tables.md`
- Test rules: `test/BEST_PRACTICE.md`
