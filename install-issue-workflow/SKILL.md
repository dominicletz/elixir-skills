---
name: install-issue-workflow
description: Installs the GitHub cursor issue workflow (workflow.exs and README) into `.cursor/issue-workflow/`, installs the `branch-code-review` project skill into `.cursor/skills/`, runs `workflow.exs --create-labels` once for GitHub labels, then prompts about workflow tweaks. Use when bootstrapping issue/PR automation, setting up cursor labels, copying the issue workflow into a repo, or installing branch review plus label workflow.
---

# Install Issue Workflow

One-shot setup: copy bundled files from this skill into the **active project** (workspace root), create GitHub workflow labels, then ask the user about customization.

## Skill asset root

Bundled copies live beside this file:

- `assets/issue-workflow/workflow.exs`
- `assets/issue-workflow/README.md`
- `assets/skills/branch-code-review/SKILL.md`

Resolve the absolute path of this skill’s directory (the parent of `SKILL.md`), then join with the paths above. On a typical Linux/macOS install: `~/.cursor/skills/install-issue-workflow/`.

## Steps

1. **Project root**  
   Use the user’s current workspace / git repository root as `PROJECT_ROOT` (where `.cursor/` should be created).

2. **Install issue workflow**  
   - `mkdir -p "$PROJECT_ROOT/.cursor/issue-workflow"`  
   - Copy **both** files from `assets/issue-workflow/` to `$PROJECT_ROOT/.cursor/issue-workflow/` (overwrite if present).  
   - Ensure `workflow.exs` is executable: `chmod +x "$PROJECT_ROOT/.cursor/issue-workflow/workflow.exs"`.

3. **Install branch-code-review skill**  
   - `mkdir -p "$PROJECT_ROOT/.cursor/skills/branch-code-review"`  
   - Copy `assets/skills/branch-code-review/SKILL.md` to `$PROJECT_ROOT/.cursor/skills/branch-code-review/SKILL.md` (overwrite if present).

4. **Create GitHub labels**  
   From `PROJECT_ROOT`, run **once**:

   ```bash
   elixir .cursor/issue-workflow/workflow.exs --create-labels
   ```

   **Prerequisites:** `elixir` on PATH, `gh` installed and authenticated for the repo, and cwd in a git checkout whose `gh repo view` matches the target GitHub repo. If the command fails, report stderr and stop; do not loop blindly.

5. **Ask the user**  
   After a successful install and `--create-labels` run (or after reporting a clear failure), ask whether they want **any workflow modifications** (e.g. label names, comment bodies in `workflow.exs`, README wording, cron/Actions wiring). Do not assume changes—wait for their answer.

## Notes

- Overwriting matches “install/update from bundle.” If the user asks to preserve local edits, copy to a backup path first or ask before overwriting.
- The workflow script references `@cursor /branch-code-review`; the installed project skill supplies that command in-repo.
