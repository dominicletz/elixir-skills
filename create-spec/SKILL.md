---
name: create-spec
description: Guides users through creating implementation specifications for libraries, features, and API changes. Use when the user wants to write a spec document, define a new feature for an existing product, create a multi-language library spec, or formalize API/behavior changes in the whenwords/SPEC.md style.
---

# Creating Implementation Specifications

This skill guides you through creating specs for **libraries**, **new features on existing products**, or **changes** to APIs and behavior. The pattern comes from [whenwords SPEC.md](https://github.com/dbreunig/whenwords/blob/main/SPEC.md).

## Before You Begin: Discovery

Gather from the user:

1. **Spec type** — New library, new feature on existing product, or change to existing behavior?
2. **Purpose** — What does it do in one sentence?
3. **Context** — For features/changes: what existing modules, APIs, or UX does it touch?
4. **Target languages/platforms** — Single or multi-language? Frontend, backend, or both? **For features/changes:** Derive from the existing project (codebase, `AGENTS.md`, `.cursor/rules`) — do not assume; inspect the project first.
5. **Scope** — Functions/endpoints/API surface, or behavioral rules?
6. **Key constraints** — Pure vs side effects, determinism, backward compatibility?

## File Location

| Spec type | Path |
|-----------|------|
| **Feature** | `docs/specs/feature-<short-name>.md` (e.g. `docs/specs/feature-bns-resolver.md`) |
| **Library** | Project- or repo-specific (e.g. `SPEC.md` at repo root) |
| **Change** | `docs/specs/change-<short-name>.md` or alongside the feature it modifies |
| **Test** | `docs/specs/tests-<short-name>.yaml` (e.g. `docs/specs/tests-bns-resolver.yaml`) |

## Spec Creation Workflow

Guide the user through these phases. Track progress with checklists.

**For features/changes:** Before Phase 3 (Type Conventions) and Phase 4 (Error Handling), read the existing project's `AGENTS.md` and `.cursor/rules` to determine target language, framework, and conventions. Use that context instead of assuming.

### Phase 1: Overview & Design Principles

**Overview** — 2–3 sentences: what it does (library, feature, or change), main use case, and key characteristic (e.g., "pure functions", "integrates with X", "backward compatible").

**For features/changes:** Add an **Integration context** subsection listing existing modules, APIs, or UX components it extends or replaces.

**Design Principles** — Numbered list (3–6 items). Each principle: **bold key phrase** + one-sentence explanation. Adapt to context:

- **Libraries:** Pure functions, no I/O, deterministic
- **Features:** Integration points, backward compatibility, migration path
- **Changes:** Non-breaking first, deprecation windows

Examples:

- **Pure functions only.** No side effects, no system clock. Reference values passed explicitly.
- **Deterministic.** Same inputs → same outputs. No randomness.
- **Strings are UTF-8.** All inputs/outputs UTF-8 encoded.
- **English only (v0.1).** No i18n unless spec defines it.

### Phase 2: Output Structure

**Store feature specs at:** `docs/specs/feature-<short-name>.md`

Define what implementations MUST and MUST NOT produce. **Adapt by spec type:**

| Spec type | Do generate | Do not generate |
|-----------|--------------|-----------------|
| **Library** | Source files, test files, usage.md | Package metadata, CI/CD, publish config |
| **Feature** | New modules/handlers, tests, integration points, migration steps | Standalone package, unrelated refactors |
| **Change** | Updated behavior, tests, deprecation notices | Breaking changes without migration path |

Goal: clear, implementable scope. For libraries: copy-paste implementation. For features/changes: integratable into existing codebase.

### Phase 3: Type Conventions

**Libraries:** Use abstract types so the spec is language-agnostic.

**Features/changes:** Use types from the project's language and framework (from `AGENTS.md`, existing code).

| Spec type | Meaning | Examples |
|-----------|---------|----------|
| `timestamp` | Unix seconds OR ISO 8601 OR language-native datetime | `1704067200`, `"2024-01-01T00:00:00Z"`, `Date` |
| `number` | Integer or float | `3600`, `3600.5` |
| `string` | UTF-8 text | |
| `options` | Language-idiomatic options object | `{compact: true}`, `Options { compact: true }` |
| `error` | Language-idiomatic error | `ValueError`, `Err(...)`, `null` |

Add a **Normalization** subsection if inputs can be supplied in multiple forms (e.g., "If string: parse to X. If native type: convert to X.").

### Phase 4: Error Handling

Two parts:

1. **Per-language table** — How errors surface. **Features/changes:** Use the project's language (from codebase/AGENTS.md).
2. **Per-function table** — What triggers an error for each function.

Rule: "Be liberal in inputs, strict in outputs."

### Phase 5: Domain-Specific Sections

Add sections for rules that span multiple functions:

- **Rounding and boundaries** — Thresholds, half-up vs truncate, edge cases.
- **Pluralization** — Singular vs plural rules.
- **Timezone handling** — Default (e.g., UTC), optional overrides, IANA names.

Use tables or bullet lists. Include **Rationale** where the choice matters for UX.

### Phase 6: API Surface (Functions, Endpoints, Behaviors)

Define the public contract. For libraries: functions. For features: endpoints, handlers, or behaviors. Use this structure for each:

```markdown
### function_name(arg1, arg2?) → return_type

One-sentence description.

**Arguments:**
- `arg1`: Type and role
- `arg2`: Optional. Default and meaning.

**Behavior:**

| Condition | Output |
|-----------|--------|
| case 1 | result 1 |
| case 2 | result 2 |

**Examples:** input → output (2–4)

**Edge cases:** Identical inputs, negatives, overflow, etc.

**Rationale:** Why these thresholds/rules (optional).
```

### Phase 7: Testing

**Test data format** — Prefer `tests.yaml` for language-agnostic input/output:

```yaml
function_name:
  - name: "human-readable test name"
    input: { ... }    # or direct value for simple args
    output: "expected"
    error: true       # only if function should error
```

**Input field mapping** — Document which fields each function expects in `input`.

**Test generation** — Show how to turn a YAML entry into tests for the target stack (Python/TypeScript/Rust/Elixir/etc.).

**Additional tests** — Implementations MAY add tests; spec tests MUST pass unchanged.

**For features/changes** — Include integration tests: how the new behavior interacts with existing modules.

### Phase 8: Generated Documentation

**Libraries:** Require `usage.md` with installation, quick start, function reference, error handling, accepted types. Keep under ~150 lines.

**Features/changes:** Require integration docs: where the feature lives, how to call it, API contracts, migration notes. Skip installation; focus on usage in context.

### Phase 9: Implementation Checklist

Final checklist before release:

- [ ] All functions/endpoints/behaviors specified
- [ ] All tests.yaml tests pass (or equivalent test cases)
- [ ] Error handling defined per item
- [ ] Edge cases documented
- [ ] Integration points clear (for features/changes)
- [ ] usage.md or integration docs provided
- [ ] Version history section

## Spec Template Structure

For the full section order, see [spec-template.md](spec-template.md).

## Anti-Patterns

- **Vague boundaries** — "Around 1 minute" → use exact thresholds (e.g., 45–89 seconds).
- **Language-specific details** — Keep types/errors abstract; map in the tables.
- **Missing rationale** — When thresholds are UX-sensitive, explain the choice.
- **Overspecified** — Don't mandate internal algorithms; specify inputs, outputs, and boundaries.
