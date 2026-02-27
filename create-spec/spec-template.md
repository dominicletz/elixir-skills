# [Name] Specification v0.1.0

> **Spec type:** [Library | Feature | Change] — Delete as needed.
> **Path:** Features → `docs/specs/feature-<short-name>.md`

## Overview

[2-3 sentences: what it does, main use case, key characteristic. For features: what product/module it extends.]

**Integration context** (optional, for features/changes): [Existing modules, APIs, UX components this touches]

## Design Principles

1. **[Principle].** [One-sentence explanation]
2. **[Principle].** [One-sentence explanation]
3. ...

---

## Output Structure

**For libraries:** Source file(s), test file(s), usage.md. Do not: package metadata, CI/CD.

**For features/changes:** New modules/handlers, tests, integration points, migration steps. Do not: standalone package, unrelated refactors.

The goal: clear, implementable scope. Copy-paste (libraries) or integratable (features/changes).

---

## Type Conventions

> **Features/changes:** Derive types from the project's language and `AGENTS.md`; use concrete types, not abstract.

| Spec type | Meaning | Examples |
|-----------|---------|----------|
| `type_a` | Description | `example` |
| `type_b` | Description | `example` |

### [Normalization subsection if needed]

When a function receives `type_x`:
1. If format A: treat as ...
2. If format B: parse to ... (error if invalid)

---

## Error Handling

| Language | Error style |
|----------|-------------|
| Python | Raise `ValueError` |
| TypeScript | Throw `Error` or return `null` |
| Rust | Return `Result<T, E>` |
| Go | Return `(value, error)` |

**Error conditions by function:**

| Function | Error when |
|----------|------------|
| `fn_a` | Condition |
| `fn_b` | Condition |

When in doubt: liberal inputs, strict outputs.

---

## [Domain-Specific Section]

[Rounding, pluralization, timezone, etc.]

### Subsection

[Tables, rules, rationale]

---

## API Surface (Functions / Endpoints / Behaviors)

> Use "Functions" for libraries; "Endpoints" or "Behaviors" for features.

### fn_name(arg1, arg2?) → return_type

**Arguments:**
- `arg1`: [Type and description]
- `arg2`: Optional. [Default and description]

**Behavior:**

| Condition | Output |
|-----------|--------|
| case | result |

**Examples:**
- `fn_name(x)` → "result"
- `fn_name(x, opts)` → "result"

**Edge cases:**
- [Case] → [Result]

**Rationale:** [If UX-sensitive]

---

### fn_name2(...)

[Repeat pattern]

---

## Testing

### Test data format

Tests defined in `tests.yaml`:

```yaml
function_name:
  - name: "human-readable test name"
    input: { ... }
    output: "expected"
    error: true   # only if error expected
```

### Input field mapping

**fn_name:** `input: { arg1: <type>, arg2?: <type> }`
**fn_name2:** `input: "<string>"` (direct value)

### Using tests.yaml

1. Parse tests.yaml in target language
2. Generate/write test cases that call function with `input`, assert `output` or error
3. Run tests until all pass

Implementations MAY add tests; spec tests MUST pass unchanged.

---

## Generated Documentation

**Libraries:** `usage.md` — installation, quick start, function reference, error handling, accepted types (~150 lines).

**Features/changes:** Integration docs — where it lives, how to call it, API contracts, migration notes. No installation; focus on in-context usage.

---

## Implementation Checklist

- [ ] All functions/endpoints/behaviors implemented
- [ ] All tests pass
- [ ] Error handling defined per item
- [ ] Edge cases covered
- [ ] Integration points clear (features/changes)
- [ ] usage.md or integration docs provided
- [ ] Code idiomatic for target stack

---

## Version History

- **v0.1.0** - Initial specification
