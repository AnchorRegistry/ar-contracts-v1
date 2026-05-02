# Redeploy Checklist

A new contract deployment changes the deployment topology, but **none of the documentation, tests, or scripts that reference deployments update themselves**. This checklist exists because that drift is silent until it isn't — by which point three deployments have stacked and the docs no longer describe reality.

Use this every time `forge script script/Deploy.s.sol ... --broadcast` succeeds against a new address on any network. Copy the body of this file into the deployment PR description and tick boxes as you go.

---

## Before you start

- [ ] Confirm which network you're deploying to (Base Sepolia / Base Mainnet)
- [ ] Confirm whether this replaces a current deployment (→ deprecation needed) or is a parallel addition
- [ ] Note the new contract address from `forge script` output
- [ ] Note the deploy block number from the broadcast receipt
- [ ] Note the source commit hash (`git rev-parse HEAD`)

## DEPLOYMENTS.md

- [ ] Update the `Base Mainnet — V1.x` or `Base Sepolia — V1.x` section header (bump version label if applicable)
- [ ] Update **Contract** address row + Basescan link (with new address in lowercase in the URL)
- [ ] Update **Owner**, **Recovery**, **Operator (primary)**, **Operator (backup)** addresses if any changed
- [ ] If replacing a prior deployment: move the old block to the **Historical** section with a `Deprecated — superseded by ...` status line and a brief "why retired" note
- [ ] Confirm the **Contract Architecture** section still matches `src/AnchorRegistry.sol` — register entry points, type ranges, total type count
- [ ] Update **Test Results** counts (run unit + fork suites first to get current numbers)

## README.md

- [ ] Update the **Live Deployments** table — addresses + Basescan/Etherscan links
- [ ] Update test counts in the **Repository Structure** tree (`AnchorRegistry.t.sol`, `AnchorRegistry.fork.t.sol`)
- [ ] Update test counts in the **Run tests** section
- [ ] If artifact type count changed: update the **Artifact Types** table (group ranges, enum values, total count) and the **AnchorBase** enum range row

## test/AnchorRegistry.fork.t.sol

- [ ] Update hardcoded contract address constant: `AnchorRegistry public registry = AnchorRegistry(0x...)`
- [ ] Update `currentOwner` constant
- [ ] Update `recoveryAddr` constant
- [ ] Update `operatorPrimary` and `operatorBackup` constants
- [ ] Update header `@notice` comment to reflect the new network and address
- [ ] Update the `Run with:` line in the header comment if the env var name changed
- [ ] Update any section comments containing `(type N)` if the enum was renumbered

## env.example

- [ ] Add any new env vars introduced by the deployment (with placeholder values, never real keys)
- [ ] Rename any env vars that are being deprecated (note the rename in the commit message)
- [ ] Confirm RPC URL placeholder examples still match the actual provider format

## foundry.toml

- [ ] Confirm `[rpc_endpoints]` aliases match env var names in `env.example`
- [ ] Confirm `[etherscan]` block has matching alias entries with correct verification URLs for each network
- [ ] If renaming an alias: update both blocks (rpc_endpoints + etherscan) together — they're keyed by the same name

## Scripts

- [ ] `script/Deploy.s.sol` — update example commands in the `@dev Usage:` comment block if env var names changed
- [ ] `script/Deploy.s.sol` — confirm the `block.chainid == ...` switch covers the new network correctly
- [ ] `script/SmokeTest.s.sol` — update the `Usage` comment block if env var names changed
- [ ] `script/SmokeTest.s.sol` — update any `(type N)` comments if the enum was renumbered

## Test runs (canary)

Run both suites and confirm green before merging:

```bash
forge test --no-match-contract AnchorRegistryForkTest
source .env && forge test --match-contract AnchorRegistryForkTest --fork-url $BASE_SEPOLIA_RPC_URL -vv
```

- [ ] Unit suite passes — record count, update README + DEPLOYMENTS.md if changed
- [ ] Fork suite passes against new deployment — record count, update README + DEPLOYMENTS.md if changed

If the fork suite fails, **stop**. The deployment, the source, and the test are out of sync; chase the cause before merging anything.

## Cross-repo blast radius (out of this repo, but flag in the PR)

- [ ] `ar-api`: `.env` and config — does it reference the prior contract address or env var names?
- [ ] `ar-ui`: any environment-specific contract address constants
- [ ] Fernando's setup: heads-up if the testnet address he benchmarks against has moved
- [ ] Any monitoring or alerting (Etherscan watchlist, Tenderly, etc.) — point it at the new address

## Final commit

Commit message convention:

```
chore(deploy): <network> V1.x at 0x<short-address>

- DEPLOYMENTS.md: new V1.x entry, prior moved to Historical
- README.md: live deployments table, test counts updated
- fork test: repointed at new address, governance constants updated
- env.example / foundry.toml / scripts: aligned with new naming if any

Deploy block: <block>
Source commit: <commit>
Tests: <unit count>/<unit count> unit, <fork count>/<fork count> fork
```

---

*This checklist itself drifts. When you finish a redeploy and notice a step that wasn't covered, add it. When a step becomes obsolete, remove it.*
