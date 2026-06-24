---
name: elixir-live-rpc-debug
description: Debug and investigate concrete issues on a running Elixir/Erlang node using live RPC (run rpc, remsh rpc, scripts/rpc, or bin/app rpc). Forms hypotheses from user symptoms, runs read-only checks, interprets output. Use when debugging production/staging/dev node behavior, inspecting process state, or investigating user-reported live system issues.
---

# Live RPC debugging

Use the repository’s **existing** RPC entrypoint to investigate a **user-specified** issue on a **running** node (local or remote). Do not start a fresh VM for investigation—`rpc` evaluates on the live system.

Companion skill for **creating** scripts: [elixir-run-rpc](../elixir-run-rpc/SKILL.md).

## Investigation workflow

```
1. Clarify symptom     → what, when, which env (local/staging/prod host)
2. Resolve RPC command → see table below
3. Confirm node up     → connectivity probe
4. Hypothesize         → 2–4 concrete checks (read-only first)
5. Run RPC             → one expression per command; capture output
6. Interpret           → compare to code; narrow or confirm
7. Escalate if needed  → remsh/remote for interactive follow-up
```

Always **run commands yourself** (Shell tool). Quote expressions for the shell.

## Log files (diode_node production)

On fleet relay hosts (`us1`, `eu2`, …) the release lives under `/opt/diode_node` but **logs are written under `/opt/diode`** (service `WorkingDirectory` / `HOME`).

| Log | Path | Use for |
|-----|------|---------|
| Runtime | `/opt/diode/traffic_node.log` | `Logger` output: `WSConn`, `Failed to send`, `Evicting stale`, `EdgeV2`, disconnects |
| Per-chain RPC | `/opt/diode/logs/*.log` | `NodeProxy` request/response lines (`:ok` / `:error` from upstream JSON-RPC) |

Moonbeam RPC audit: `/opt/diode/logs/Elixir.Chains.Moonbeam.log`

**Do not use** `/root/error.log` (stale; not connected to the running node).

```bash
ssh us1 'grep -E "Failed to send|Evicting stale|WSConn.*Moonbeam" /opt/diode/traffic_node.log | tail -30'
ssh us1 'tail -20 /opt/diode/logs/Elixir.Chains.Moonbeam.log'
```

Repo reference: `docs/live-debugging.md`.

## Resolve RPC command (per repo)

| Entrypoint | When |
|------------|------|
| `./run rpc 'expr'` | Unified `run` with rpc subcommand |
| `./remsh rpc 'expr'` | Split scripts (`diode_node`) |
| `./scripts/rpc 'expr'` | Remote SSH wrapper |
| `scripts/console_remote_rpc.sh 'expr'` | Remote release (env: `*_RPC_SSH_HOST`, `*_RPC_BIN`) |
| `bin/<app> rpc 'expr'` | Mix release (local install or SSH) |

Discovery:

```bash
ls -la run remsh scripts/rpc scripts/*remote*rpc* 2>/dev/null
grep -r 'rpc-eval\|--rpc-eval\| rpc ' run remsh scripts/ 2>/dev/null | head -20
grep -E 'bin/.* rpc' deployment/ Makefile 2>/dev/null | head -10
epmd -names 2>/dev/null    # local: is target node registered?
```

If no RPC script exists, use **elixir-run-rpc** to add one before debugging.

**Local vs remote**

| Target | Command |
|--------|---------|
| Local dev | `./run rpc` / `./remsh rpc` |
| Local release | `_build/prod/rel/<app>/bin/<app> rpc` or `/opt/<app>/bin/<app> rpc` |
| Remote | `./scripts/rpc` or project remote wrapper; override host via env vars in script header |

## Connectivity probe (run first)

```bash
# Adjust to repo entrypoint
./remsh rpc 'IO.inspect(node())'
./run rpc 'IO.inspect(node())'
./scripts/rpc 'IO.inspect(node())'
/opt/diode_node/bin/diode_node rpc 'IO.inspect(node())'
```

Expect the **application node name** (e.g. `:diode_light@host`), not the hidden RPC client. Failure modes:

| Error | Likely fix |
|-------|------------|
| `:noconnection` | Node down, wrong name/cookie, or hostname/loopback mismatch (see elixir-run-rpc) |
| `false` for `Code.ensure_loaded?(MyApp)` | Wrong node or app not started |
| SSH failure | Host/key; check `*_RPC_SSH_HOST` |

## Expression rules

- Wrap in **single quotes** for bash; use `IO.inspect/1`, `IO.puts/1`, or functions that print—bare values often produce no output.
- Prefer **read-only** queries first (`Process.whereis`, `:sys.get_state`, ETS/tab info, public API getters).
- Ask before **mutating** RPC (`flush_*`, `stop`, `reload`, `System.stop`, hot code load).
- Multi-word expression: pass as one quoted string; `./run rpc` uses `"$*"`.
- For modules in the codebase, grep `lib/` for relevant functions before guessing.

## Hypothesis → RPC patterns

| Symptom area | Example expression |
|--------------|-------------------|
| Is app loaded? | `IO.inspect(Code.ensure_loaded?(Diode))` |
| Version / uptime | `IO.inspect({:c.uptime(), Diode.Version.description()})` |
| Named process alive? | `IO.inspect(Process.whereis(MyApp.Worker))` |
| GenServer state | `IO.inspect(:sys.get_state(Process.whereis(MyApp.Worker)))` |
| Supervisor children | `IO.inspect(Supervisor.which_children(MyApp.Supervisor))` |
| Memory | `IO.inspect(:erlang.memory())` |
| Connections / ports | `IO.inspect(:erlang.system_info(:process_count))` |
| Registered names | `IO.inspect(Process.registered() \|> Enum.filter(&to_string(&1) =~ "edge"))` |
| App-specific status | `IO.inspect(Diode.Cmd.status())` or project CLI helpers |
| ETS / cache | `IO.inspect(:ets.info(:my_table))` |
| RemoteChain / RPC cache | grep `lib/` for module; e.g. `DetsPlus.info(:remoterpc_cache)` |

Build expressions from **actual module names** in the repo (`grep`, `mix xref`, or read `lib/`).

## Safety

- **Read-only default** for production/staging unless user explicitly requests a fix action.
- Log exact command run and output in your reply.
- Destructive ops (cache flush, reload, stop) → confirm with user; note fabfile/deploy scripts may already encode approved ops.

## When to use remsh instead

- Multi-step exploration, piping, or fixing typos interactively.
- Same target as rpc: `./run remsh`, `./remsh`, `bin/<app> remote`.

## Report findings

Summarize for the user:

1. **Symptom** (their words)
2. **Commands run** (copy-pasteable)
3. **Observed facts** from output
4. **Conclusion** (confirmed / ruled out / inconclusive)
5. **Next step** (code change, another RPC, remsh, logs — see **Log files** above for paths)

## Usage examples

See [examples.md](examples.md) for full investigation scenarios.

**Quick reference (diode_node-style):**

```bash
./remsh rpc 'IO.inspect(node())'
./remsh rpc 'IO.inspect(Diode.env())'
./remsh rpc 'IO.inspect(Process.whereis(RemoteChain.RpcCache))'
./remsh rpc 'IO.inspect(Diode.Cmd.status())'
```

**diode-drive-style:**

```bash
./run rpc 'IO.inspect(node())'
./run rpc 'IO.inspect(Application.started_applications() |> length)'
```

**Remote release (console-style):**

```bash
./scripts/console_remote_rpc.sh 'IO.inspect(Process.whereis(Console.TxQueue))'
CONSOLE_RPC_SSH_HOST=staging ./scripts/console_remote_rpc.sh 'IO.inspect(:erlang.memory())'
```

**Remote prod (fabfile patterns):**

```bash
/opt/diode_node/bin/diode_node rpc 'IO.inspect({:c.uptime(), String.trim(Diode.Version.description())})'
/opt/diode_node/bin/diode_node rpc 'IO.inspect(DetsPlus.info(:remoterpc_cache))'
/opt/diode_node/bin/diode_node pid
```

**cursor_automation-style remote dev:**

```bash
./scripts/rpc 'IO.inspect(Process.list() |> length)'
```
