# RPC script templates

Copy and replace placeholders: `MYAPP`, `myapp`, `myapp_light`, `myhost`, `/opt/myapp/bin/myapp`.

## Local `run` — iex/mix dev (merge remsh)

```sh
#!/bin/sh
export ERL_EPMD_ADDRESS=127.0.0.1
export MIX_ENV=prod

REMSH_NODE=myapp_light

case "$1" in
  rpc)
    shift
    if [ -z "$1" ]; then
      echo "Usage: $0 rpc <expression>" >&2
      exit 1
    fi
    expr="$*"
    if [ -n "$COOKIE" ]; then
      exec elixir --hidden --sname "run_rpc_$$" --cookie "$COOKIE" \
        --rpc-eval "$REMSH_NODE" "$expr"
    else
      exec elixir --hidden --sname "run_rpc_$$" \
        --rpc-eval "$REMSH_NODE" "$expr"
    fi
    ;;
  remsh)
    exec iex --sname "remsh_$$" --remsh "$REMSH_NODE"
    ;;
  *)
    export ELIXIR_ERL_OPTIONS='+sbwt none -noinput -noshell -sname myapp_light +A 8'
    exec elixir -S mix run --no-halt
    ;;
esac
```

## Local `run` — cookie + full node name

```bash
#!/bin/bash
export ERL_EPMD_ADDRESS=127.0.0.1

if [ -z "${COOKIE}" ] && [ -f ~/myapp/releases/COOKIE ]; then
  export COOKIE=$(cat ~/myapp/releases/COOKIE)
fi
cookie_prefix=${COOKIE:0:8}
APP_NODE="myapp_${cookie_prefix}@127.0.0.1"

case "$1" in
  remsh)
    exec iex --cookie "$COOKIE" --name "remsh_$$@127.0.0.1" --remsh "$APP_NODE"
    ;;
  rpc)
    shift
    [ -z "$1" ] && { echo "Usage: $0 rpc <expression>" >&2; exit 1; }
    exec elixir --cookie "$COOKIE" --name "rpc_$$@127.0.0.1" \
      --rpc-eval "$APP_NODE" "$*"
    ;;
  *)
    exec iex --cookie "$COOKIE" --name "$APP_NODE" -S mix
    ;;
esac
```

## `scripts/rpc` — remote release

```bash
#!/usr/bin/env bash
# Usage: ./scripts/rpc 'IO.inspect(node())'
# Env: MYAPP_RPC_SSH_HOST (default: myhost), MYAPP_RPC_BIN (default: /opt/myapp/bin/myapp)

set -euo pipefail

REMOTE_HOST="${MYAPP_RPC_SSH_HOST:-myhost}"
REMOTE_BIN="${MYAPP_RPC_BIN:-/opt/myapp/bin/myapp}"

if [ "$#" -eq 0 ]; then
  echo "usage: $(basename "$0") <elixir-expression>" >&2
  exit 2
fi

expression="$*"
remote_argv=$(printf '%q ' "$REMOTE_BIN" rpc "$expression")
remote_argv=${remote_argv%" "}

exec ssh "${REMOTE_HOST}" "${remote_argv}"
```

## `scripts/rpc` — remote dev elixir

```bash
#!/usr/bin/env bash
# Usage: ./scripts/rpc 'IO.inspect(node())'
# Env: MYAPP_RPC_SSH_HOST (default: myhost)
# Remote node short name must match the running VM on the server.

set -euo pipefail

SSH_HOST="${MYAPP_RPC_SSH_HOST:-myhost}"
REMOTE_NODE="${MYAPP_RPC_NODE:-myapp}"

if [[ $# -eq 0 ]]; then
  echo "usage: $(basename "$0") <elixir-expression>" >&2
  exit 1
fi

expr_q=$(printf '%q' "$*")
inner=$(printf '%q' "elixir --hidden --sname rpc_\$\$ --rpc-eval ${REMOTE_NODE} ${expr_q}")

exec ssh "$SSH_HOST" bash -lc "$inner"
```

## Thin `remsh` wrapper (after merging into `run`)

```sh
#!/bin/sh
exec "$(dirname "$0")/run" remsh
```
