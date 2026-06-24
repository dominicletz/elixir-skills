---
name: elixir-run-rpc
description: Creates or extends bash `run` scripts with `run rpc <expression>` and `scripts/rpc` for remote Elixir/Erlang RPC on running nodes. Detects iex/mix dev vs release (`bin/app rpc`) patterns. Use when adding run/rpc/remsh scripts, remote RPC over SSH, or unifying split run+remsh scripts.
---

# Elixir run + RPC scripts

Create a **single local `run`** script (start app + `rpc` + optional `remsh`) and a **`scripts/rpc`** for **remote** one-shot eval on a pre-configured host/node.

## Known variants (reference)

| Pattern | Example | Local RPC mechanism |
|---------|---------|---------------------|
| Split `run` + `remsh` | `diode_node/run`, `diode_node/remsh` | `elixir --rpc-eval <shortname>` |
| Unified `run` | `diode-drive/run` | `elixir --rpc-eval <fullname>` + cookie |
| Remote dev node | `cursor_automation/scripts/rpc` | SSH → remote `elixir --rpc-eval` |
| Remote release | `console/scripts/console_remote_rpc.sh` | SSH → `bin/<release> rpc` |
| Release only | `bin/diode_node rpc 'expr'` | Mix release `--rpc-eval` |

## Workflow

### 1. Detect project layout

Inspect (do not guess):

```bash
# Elixir app?
test -f mix.exs && echo mix

# Release defined?
grep -l 'releases:' mix.exs 2>/dev/null

# Existing scripts
ls -la run remsh scripts/rpc 2>/dev/null
ls _build/*/rel/*/bin/* 2>/dev/null | head -3

# Node naming hints
grep -E 'sname|RELEASE_NODE|ELIXIR_ERL_OPTIONS|COOKIE' run remsh scripts/entrypoint 2>/dev/null
```

| Signal | Likely mode |
|--------|-------------|
| `run` + separate `remsh`, `mix run --no-halt`, short `-sname foo` | **iex/mix dev** |
| `releases:` in mix.exs, deploy docs mention `bin/…` | **release** (local + remote) |
| `~/dDrive/releases/COOKIE` or cookie in `run` | **release cookie** on dev too |
| Only `_build/.../rel/.../bin/app` used in prod | **release** for `scripts/rpc` |

If ambiguous, use **AskQuestion** (or ask in chat):

- **iex/mix dev** — local `mix run` / `iex -S mix`, short node name (`diode_light`)
- **elixir release** — `bin/<app> rpc`, `bin/<app> remote`, cookie from `releases/COOKIE`

### 2. Gather constants (from repo or user)

| Constant | Where to find |
|----------|----------------|
| `REMSH_NODE` / short name | `ELIXIR_ERL_OPTIONS` (`-sname`), existing `remsh` |
| Full node name | `run` remsh line (`ddrive_xxx@127.0.0.1`) |
| `MIX_ENV`, `ERL_EPMD_ADDRESS` | existing `run` |
| Release name + remote path | `mix.exs` `releases:`, deploy fabfile, `CONSOLE_RPC_BIN` style env |
| SSH host | deploy config, existing `scripts/rpc` |
| Cookie | `COOKIE` env, `releases/COOKIE`, `run` `--cookie` |

### 3. Implement local `run`

**Goals:**

- Default command: start app (preserve existing flags/`ulimit`/env).
- `run rpc <expression>` — eval on **running** node (not a new VM).
- Optional `run remsh` — interactive shell (merge from separate `remsh` if present).

**iex/mix dev — RPC subcommand:**

```sh
rpc)
  shift
  [ -z "$1" ] && { echo "Usage: $0 rpc <expression>" >&2; exit 1; }
  expr="$*"
  if [ -n "$COOKIE" ]; then
    exec elixir --hidden --sname "run_rpc_$$" --cookie "$COOKIE" \
      --rpc-eval "$REMSH_NODE" "$expr"
  else
    exec elixir --hidden --sname "run_rpc_$$" \
      --rpc-eval "$REMSH_NODE" "$expr"
  fi
  ;;
```

Set `REMSH_NODE` to the **same** short name the app uses (`diode_light`, etc.). Match `export ERL_EPMD_ADDRESS=127.0.0.1` if the app sets it.

**iex/mix dev — remsh subcommand:**

```sh
remsh)
  exec iex --sname "remsh_$$" --remsh "$REMSH_NODE"
  ;;
```

**Unified full node (diode-drive style):**

```sh
rpc)
  shift
  [ -z "$1" ] && { echo "Usage: $0 rpc <expression>" >&2; exit 1; }
  exec elixir --cookie "$COOKIE" --name "rpc_$$@127.0.0.1" \
    --rpc-eval "$APP_NODE" "$*"
  ;;
```

**Release — delegate to bin script:**

```sh
rpc)
  shift
  [ -z "$1" ] && { echo "Usage: $0 rpc <expression>" >&2; exit 1; }
  exec "$(dirname "$0")/_build/prod/rel/${RELEASE_NAME}/bin/${RELEASE_NAME}" rpc "$*"
  # Or fixed install path: /opt/myapp/bin/myapp rpc "$*"
  ;;
```

When merging a standalone `remsh` into `run`, keep behavior identical; delete or thin `remsh` to a one-line `exec ./run remsh` wrapper if other docs reference it.

### 4. Implement `scripts/rpc` (remote)

Pick **one** remote backend (match how the server runs):

| Backend | Remote command |
|---------|----------------|
| Dev VM on server | `elixir --hidden --sname rpc_$$ --rpc-eval <node> '<expr>'` |
| Installed release | `/opt/<app>/bin/<app> rpc '<expr>'` |

**SSH safety:** OpenSSH joins remote argv without re-quoting. Use `printf '%q'` so parentheses and quotes survive.

**Release remote** (console pattern):

```bash
REMOTE_HOST="${MYAPP_RPC_SSH_HOST:-myhost}"
REMOTE_BIN="${MYAPP_RPC_BIN:-/opt/myapp/bin/myapp}"
expression="$*"
remote_argv=$(printf '%q ' "$REMOTE_BIN" rpc "$expression")
remote_argv=${remote_argv%" "}
exec ssh "${REMOTE_HOST}" "${remote_argv}"
```

**Dev elixir remote** (cursor_automation pattern):

```bash
SSH_HOST="${MYAPP_RPC_SSH_HOST:-myhost}"
expr_q=$(printf '%q' "$*")
inner=$(printf '%q' "elixir --hidden --sname rpc_\$\$ --rpc-eval mynode $expr_q")
exec ssh "$SSH_HOST" bash -lc "$inner"
```

Document env overrides in the script header (`MYAPP_RPC_SSH_HOST`, `MYAPP_RPC_BIN`).

**Loopback / `:noconnection`:** If RPC fails with `:noconnection` but the node is up, the VM may register on a public IP while EPMD listens on loopback. Note in script comments: add `127.0.0.1 $(hostname)` to `/etc/hosts` on the server (see `cursor_automation/scripts/rpc`).

### 5. Validate

1. App must be running (local or remote).
2. Local: `./run rpc 'IO.inspect(node())'` → remote node name.
3. Local: `./run rpc 'IO.inspect(SomeAppModule)'` → proves app code is loaded.
4. Remote: `./scripts/rpc 'IO.inspect(node())'`.
5. Bare expressions (`1+2`) do **not** print with `--rpc-eval`; use `IO.inspect/1` or `IO.puts/1`.

### 6. Usage examples (for skill user docs / script headers)

**Local dev (short node `diode_light`):**

```bash
./run                          # start app
./run remsh                    # interactive remote shell
./run rpc 'IO.inspect(node())'
./run rpc 'IO.inspect(Diode.env())'
./run rpc 'IO.inspect(DetsPlus.info(:remoterpc_cache))'
```

**Unified run (diode-drive style):**

```bash
./run
./run remsh
./run rpc 'IO.inspect(Application.started_applications() |> length)'
```

**Remote release:**

```bash
./scripts/rpc 'IO.inspect(Process.whereis(MyApp.Worker))'
CONSOLE_RPC_SSH_HOST=staging ./scripts/rpc 'System.memory() |> IO.inspect()'
```

**Remote dev elixir on server:**

```bash
./scripts/rpc 'IO.inspect(:rpc.call(node(), :erlang, :system_info, [:wordsize]))'
```

**Installed release (no wrapper):**

```bash
/opt/diode_node/bin/diode_node rpc 'IO.inspect(Diode.Cmd.flush_cache())'
bin/myapp remote    # interactive, same target as rpc
```

## Checklist

Copy when implementing:

```
- [ ] Detected iex/mix vs release; confirmed with user if unclear
- [ ] REMSH_NODE / APP_NODE matches running VM
- [ ] COOKIE wired if non-default
- [ ] ERL_EPMD_ADDRESS consistent with app
- [ ] run: start + rpc (+ remsh); expr via "$*"
- [ ] scripts/rpc: SSH host + remote command + printf %q
- [ ] Usage block in script header
- [ ] Validated IO.inspect(node()) locally and/or remotely
```

## Additional templates

Full copy-paste shells: [templates.md](templates.md)
