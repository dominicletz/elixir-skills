---
name: elixir-mix-lint
description: Adds Credo, Dialyxir, Dialyzer PLT layout, and mix lint / mix lint:quick aliases to an existing Elixir project. Use when bootstrapping CI lint, typecheck, or reproducing the diode-drive mix lint workflow in another repo.
---

# Add `mix lint` to an Elixir project

Portable workflow based on the **diode-drive** `mix lint` / `mix lint:quick` aliases. Adapt project-specific steps (e.g. `agentmd`) only when the repo already has that machinery.

## Before changing anything

1. Read `mix.exs` — note existing `aliases/0`, `project/0`, and dev/test deps.
2. Run `mix lint:quick` or `mix compile` if aliases already exist, to see current failures.
3. Do **not** duplicate deps or alias keys; merge into existing `deps/0`, `project/0`, and `aliases/0`.

## Dependencies

Add under a `# Linting` (or similar) comment in `deps/0`:

```elixir
{:credo, "~> 1.7", only: [:dev, :test], runtime: false},
{:dialyxir, "~> 1.2", only: [:dev], runtime: false},
```

Then:

```bash
mix deps.get
```

## Dialyzer project config

In `project/0`, add `dialyzer: dialyzer()` next to other keys (e.g. `deps`, `aliases`).

Add a private function (names may match existing style):

```elixir
defp dialyzer() do
  [
    plt_core_path: "priv/plts",
    plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
  ]
end
```

## Mix aliases

Merge into `aliases/0` (do not replace unrelated aliases):

```elixir
lint: [
  "compile --warnings-as-errors",
  "format --check-formatted",
  "credo --only warning",
  "cmd mkdir -p priv/plts",
  "dialyzer"
],
"lint:quick": [
  "compile --warnings-as-errors",
  "format --check-formatted",
  "credo --only warning"
]
```

| Alias | Purpose |
|-------|---------|
| `mix lint:quick` | Compile (warnings as errors), format check, Credo warnings — fast local/PR feedback |
| `mix lint` | Same as quick, plus Dialyzer |

### Optional: `agentmd --check` (project-specific)

If the repo syncs `AGENTS.md` to other agent files (see `Mix.Tasks.Agentmd`), insert **after** compile and **before** format:

```elixir
"do agentmd --check",
```

Use the Mix task name (`agentmd`), not a global CLI binary, so CI stays reproducible.

### Optional: xref cycle gate

Only if the project already defines `cyclecheck` (e.g. Elixir 1.19+ xref cycles). Do not add unless requested.

## Supporting files

### `.credo.exs`

Create at repo root if missing. Start minimal; tighten checks later:

```elixir
%{
  configs: [
    %{
      name: "default",
      checks: [
        {Credo.Check.Design.DuplicatedCode, []},
        {Credo.Check.Warning.UnsafeExec, false}
      ]
    }
  ]
}
```

Run `mix credo gen.config` only if the team wants the full default template instead.

### `.gitignore`

Ignore PLT artifacts (committed PLTs are large and environment-specific):

```
/priv/plts/*
```

### `.dialyzer_ignore.exs` (optional)

Add when Dialyzer reports known false positives. Dialyxir reads this file automatically. Prefer fixing types over growing the ignore list.

Example entry shape:

```elixir
[
  {"lib/my_module.ex", :pattern_match}
]
```

## First-time Dialyzer setup

PLTs are not in git. Once per machine/CI cache miss:

```bash
mkdir -p priv/plts
mix dialyzer --plt
```

Then:

```bash
mix lint:quick   # fast
mix lint         # includes dialyzer
```

## CI pattern

Cache `deps`, `_build`, and `priv/plts`. On cache miss:

```yaml
- run: |
    mix local.hex --force
    mix local.rebar --force
    mix deps.get
    mix deps.compile
    mkdir -p priv/plts
    mix dialyzer --plt
- run: mix lint
```

Use `mix lint:quick` in faster jobs if Dialyzer runs in a dedicated typecheck job (as in diode-drive).

## Optional: dev bootstrap script

For agent/CI environments, document or add a one-liner after deps:

```bash
mkdir -p priv/plts
```

Full PLT build can stay in CI cache or a documented `mix dialyzer --plt` step.

## Verification checklist

After implementation:

- [ ] `mix deps.get` succeeds
- [ ] `mix lint:quick` passes (or failures are addressed / ignored deliberately)
- [ ] `mix lint` passes after `mix dialyzer --plt`
- [ ] `/priv/plts/*` is gitignored
- [ ] CI caches `priv/plts` and builds PLT on cache miss
- [ ] No duplicate `lint` / `lint:quick` keys in `aliases/0`

## Reference (diode-drive)

Canonical definitions live in that repo’s `mix.exs` (`dialyzer/0`, `aliases/0` → `lint`, `lint:quick`), `.credo.exs`, `.github/workflows/ci.yml` (typecheck job), and optional `lib/mix/tasks/agentmd.ex`.
