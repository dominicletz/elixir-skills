# Live RPC investigation examples

Each scenario: symptom → probe → targeted RPC → interpretation. Adapt module names to the repo under investigation.

---

## Example 1: “Is my local node running the right build?”

**Symptom:** Dev says behavior doesn’t match latest code; unsure if `diode_light` is up.

**Commands:**

```bash
epmd -names
./remsh rpc 'IO.inspect(node())'
./remsh rpc 'IO.inspect({:c.uptime(), Diode.Version.description()})'
./remsh rpc 'IO.inspect(Diode.env())'
```

**Interpret:** `node()` must be `:diode_light@<host>`. Compare `description()` to expected git tag. `env` should match `MIX_ENV` intent.

---

## Example 2: “Cache looks stale on production”

**Symptom:** Remote chain RPC returns old data; suspect cache on prenet node.

**Commands (remote release):**

```bash
# via SSH host from deploy docs, or fabric-style:
ssh root@eu1.prenet.diode.io /opt/diode_node/bin/diode_node rpc 'IO.inspect(DetsPlus.info(:remoterpc_cache))'
```

Or if repo has `scripts/rpc`:

```bash
DIODE_RPC_SSH_HOST=root@eu1.prenet.diode.io ./scripts/rpc 'IO.inspect(DetsPlus.info(:remoterpc_cache))'
```

**Follow-up (only if user approves flush):**

```bash
/opt/diode_node/bin/diode_node rpc 'IO.inspect(Diode.Cmd.flush_cache())'
```

**Interpret:** Dets size/file path vs expectation; re-query after flush if approved.

---

## Example 3: “GenServer not responding”

**Symptom:** Feature tied to `RemoteChain.RpcCache` hangs.

**Commands:**

```bash
./remsh rpc 'IO.inspect(Process.whereis(RemoteChain.RpcCache))'
./remsh rpc 'IO.inspect(Process.info(Process.whereis(RemoteChain.RpcCache), [:message_queue_len, :status]))'
./remsh rpc 'IO.inspect(:sys.get_state(Process.whereis(RemoteChain.RpcCache)))'
```

**Interpret:** `nil` → process not started. High `message_queue_len` → backlog. `:sys.get_state` shows last known state (may error if dead).

---

## Example 4: “How many clients are connected?”

**Symptom:** Operator reports low device count on a relay.

**Commands:**

```bash
./remsh rpc 'IO.inspect(Diode.Cmd.status())'
# or granular:
./remsh rpc 'IO.inspect(Network.Server.get_connections(Network.EdgeV2) |> Enum.count())'
```

**Interpret:** Compare `Connected Devices` / count to expected fleet size.

---

## Example 5: “Investigate on staging console”

**Symptom:** Tx queue stuck on staging console release.

**Commands:**

```bash
CONSOLE_RPC_SSH_HOST=staging ./scripts/console_remote_rpc.sh 'IO.inspect(node())'
CONSOLE_RPC_SSH_HOST=staging ./scripts/console_remote_rpc.sh 'IO.inspect(Process.whereis(Console.TxQueue))'
CONSOLE_RPC_SSH_HOST=staging ./scripts/console_remote_rpc.sh 'IO.inspect(:sys.get_state(Process.whereis(Console.TxQueue)))'
```

**Interpret:** Confirm staging node name; queue state vs code in `lib/console/`.

---

## Example 6: “Kademlia lookup returns wrong value”

**Symptom:** Specific key lookup wrong on prod (from fabfile `search`).

**Command:**

```bash
/opt/diode_node/bin/diode_node rpc 'KademliaLight.find_value("0xbbd1c4fe1cfd431477883535d00dad1c2c160c51" |> DiodeClient.Base16.decode) |> IO.inspect()'
```

**Interpret:** Compare returned value to on-chain or peer node; if `nil`, routing/table issue.

---

## Example 7: “RPC works locally but scripts/rpc fails”

**Symptom:** `./scripts/rpc` → `:noconnection`.

**Checks:**

```bash
./remsh rpc 'IO.inspect(node())'          # local OK?
ssh myhost 'epmd -names'                   # remote epmd
ssh myhost "hostname; getent hosts \$(hostname)"
```

**Interpret:** Often `stripe@public_ip` vs loopback—fix `/etc/hosts` on server (`127.0.0.1 $(hostname)`). See elixir-run-rpc.

---

## Example 9: “Moonbeam NodeProxy / WSConn stuck” (diode_node fleet)

**Symptom:** Edge devices drop; Moonbeam RPC fails; suspect WS pool not rotating.

**Logs (not `/root/error.log`):**

```bash
ssh us1 'grep -E "Failed to send|Evicting stale|WSConn.*Moonbeam" /opt/diode/traffic_node.log | tail -30'
ssh us1 'tail -20 /opt/diode/logs/Elixir.Chains.Moonbeam.log'
```

**RPC:**

```bash
ssh us1 '/opt/diode_node/bin/diode_node rpc '"'"'
pid = :global.whereis_name({RemoteChain.NodeProxy, Chains.Moonbeam})
state = :sys.get_state(pid)
for {url, cpid} <- state.connections do
  IO.inspect({url, RemoteChain.WSConn.ready?(cpid), RemoteChain.WSConn.handshake_stale?(cpid)})
end
'"'"''
```

**Interpret:** Transport issues → `traffic_node.log`. Lines ending `:error` in `Elixir.Chains.Moonbeam.log` are often upstream `eth_call` failures, not disconnects. See `docs/live-debugging.md` in diode_node.

---

## Example 8: Interactive deep dive after RPC

**Symptom:** RPC showed high mailbox; need to explore live.

```bash
./run remsh
# or: ./remsh
# then in IEx on remote node:
#   Process.info(pid, :messages)
#   :sys.get_log(pid)
```

Use when one-liners are insufficient; same VM as `rpc`.

---

## Agent checklist (copy per investigation)

```
- [ ] User symptom restated; env (local/host) confirmed
- [ ] RPC entrypoint identified in this repo
- [ ] Connectivity probe succeeded
- [ ] Read-only RPC run; output captured
- [ ] Code cross-checked (grep/read lib)
- [ ] Findings reported with commands + conclusion
- [ ] Logs from correct paths (diode_node: `traffic_node.log`, `logs/*.log`)
- [ ] Mutating RPC only with explicit user OK
```
