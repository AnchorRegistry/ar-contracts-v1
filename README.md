# AnchorRegistry: On-Chain Provenance Registry

> The registry AIs trust.

AnchorRegistry is immutable provenance infrastructure for the AI era. Any creator can register any digital artifact and receive a permanent, verifiable, on-chain proof of authorship.

**SPDX-Anchor: [anchorregistry.ai/AR-2026-qnPOJ1z](https://anchorregistry.ai/AR-2026-qnPOJ1z)**

> Patent pending — USPTO Provisional Application #64/009,841, filed March 18, 2026.

---

## What This Is

- A notary service for the digital age
- The SPDX/DAPX manifest is the fingerprint
- Ethereum (Base L2) is the ink pad that makes it permanent
- The AR-ID is the case number
- `anchorregistry.ai/AR-ID` is the machine-readable verification endpoint

## What This Is NOT

- Not an NFT
- Not a storage product — files never leave the user's browser
- Not a subscription — no recurring fees
- Not Web3 theatre — the blockchain is plumbing, invisible to the user

---

## Research

🎓 The cryptographic commitment scheme and security proofs underlying this implementation
are formally described in:

**Trustless Provenance Trees: A Game-Theoretic Framework for Operator-Gated Blockchain Registries**
Ian C. Moore — *arXiv:2604.03434 [cs.GT, cs.CR], April 2026*

🔗 https://arxiv.org/abs/2604.03434

---

## Live Deployments

| Network | Contract | Verified |
|---------|----------|----------|
| **Base Mainnet** | [`0x3eC509393425BCAa48224FB90C710e100ADA1D2A`](https://basescan.org/address/0x3ec509393425bcaa48224fb90c710e100ada1d2a) | Yes |
| **Base Sepolia** | [`0xB0435faA6DeEDC1CB6a809008516fe4F4B094F76`](https://sepolia.basescan.org/address/0xb0435faa6deedc1cb6a809008516fe4f4b094f76) | Yes |

212 unit tests pass against current source. See [DEPLOYMENTS.md](DEPLOYMENTS.md) for deployment history and operator addresses.

---

## Repository Structure

```
ar-contracts-v1/
├── src/
│   ├── AnchorTypes.sol            # Type definitions — enum, structs, errors
│   └── AnchorRegistry.sol         # The contract — deployed once, immutable forever
├── test/
│   ├── AnchorRegistry.t.sol       # Full Foundry test suite (212 tests)
│   └── AnchorRegistry.fork.t.sol  # Fork tests against live Base Sepolia (23 tests)
├── script/
│   └── Deploy.s.sol               # Deployment script (Base Sepolia + Base Mainnet)
├── DEPLOYMENTS.md                 # Live deployment details and test results
├── foundry.toml
├── .env.example
└── .gitignore
```

---

## Quick Start

### Prerequisites

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### Install dependencies

```bash
forge install foundry-rs/forge-std --no-git
```

### Run tests

The suite is split in two:

- **Unit tests** (`AnchorRegistry.t.sol`, 212 tests) — run locally, no RPC needed.
- **Fork tests** (`AnchorRegistry.fork.t.sol`, 23 tests) — run against the live Base Sepolia deployment, require `--fork-url`.

Run unit tests only (fast, no RPC):

```bash
forge test --no-match-contract AnchorRegistryForkTest
```

Run fork tests against live Base Sepolia:

```bash
source .env
forge test --match-contract AnchorRegistryForkTest --fork-url $BASE_SEPOLIA_RPC_URL -vv
```

A bare `forge test` will run both suites; without `--fork-url` set, the fork tests will revert against an empty in-memory chain. This is environmental, not a contract failure.

### Deploy to Base Sepolia (testnet)

```bash
cp .env.example .env
# fill in .env values

source .env

forge script script/Deploy.s.sol \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  -vvvv
```

### Deploy to Base mainnet

```bash
forge script script/Deploy.s.sol \
  --rpc-url $BASE_RPC_URL \
  --broadcast \
  --verify \
  -vvvv
```

---

## Contract Design

### Artifact Types

24 artifact types in 8 logical groups:

| Group | Types | Enum | Description |
|-------|-------|------|-------------|
| **CONTENT** | `CODE`, `RESEARCH`, `DATA`, `MODEL`, `AGENT`, `MEDIA`, `TEXT`, `POST`, `ONCHAIN`, `REPORT`, `NOTE`, `WEBSITE` | 0–11 | What creators make. Active at launch. `onlyOperator`. |
| **LIFECYCLE** | `EVENT` | 12 | Human events and machine/agent processes. Active at launch. `onlyOperator`. |
| **TRANSACTION** | `RECEIPT` | 13 | Proof of commercial, medical, financial, government, event, or service transactions. Active at launch. `onlyOperator`. |
| **GATED** | `LEGAL`, `ENTITY`, `PROOF` | 14–16 | Suppressed at launch. Separate operator gates. |
| **SELF-SERVICE** | `SEAL`, `RETRACTION` | 17–18 | Client-authority anchors. Active at launch. `SEAL` finalizes a tree as authentic and complete — no new anchors may be appended after sealing (AR governance retains the ability to target anchors within sealed trees via REVIEW/VOID/AFFIRMED). `RETRACTION` is owner-initiated self-prune. Both submitted by operator after token-commitment verification; SEAL has its own entry point `registerSeal()`. |
| **REVIEW** | `REVIEW`, `VOID`, `AFFIRMED` | 19–21 | AnchorRegistry operator-only. Active at launch. |
| **BILLING** | `ACCOUNT` | 22 | Prepaid registration capacity. Active at launch. `onlyOperator`. |
| **CATCH-ALL** | `OTHER` | 23 | Everything else. |

**Gated type activation:**
- `LEGAL` (14) — opens in V2-V3 with document verification. Owner calls `addLegalOperator()`.
- `ENTITY` (15) — opens in V2 with domain verification. Owner calls `addEntityOperator()`.
- `PROOF` (16) — opens in V4 with ZK infrastructure. Owner calls `addProofOperator()`.

### AnchorBase

Every anchor type extends `AnchorBase`:

| Field | Description |
|-------|-------------|
| `artifactType` | Enum value (0–23) |
| `manifestHash` | SHA-256 of full manifest — the on-chain provenance commitment |
| `parentArId` | AR-ID of parent anchor, empty if root |
| `descriptor` | Human-readable slug e.g. `ICMOORE-2026-UNISWAPPY` |
| `title` | Artifact title e.g. `UniswapPy v1.0` |
| `author` | Artifact author e.g. `Ian Moore` |
| `treeId` | Cryptographic tree identity: `sha256(anchorKey + rootArId)` for tree holders. `AR_TREE_ID` constant (`"ar-operator-v1"`) for all REVIEW, VOID, AFFIRMED anchors registered by AnchorRegistry. |

### Access Control

Four-tier permissioned architecture:

| Role | Types | Active at Launch |
|------|-------|-----------------|
| **Owner** | Governance only — `addOperator`, `removeOperator`, `transferOwnership`, `cancelRecovery` | Yes |
| **Operator** | Types 0–13, 17–23 | Yes |
| **Legal Operator** | Type 14 (`LEGAL`) | No — zero operators at deployment |
| **Entity Operator** | Type 15 (`ENTITY`) | No — zero operators at deployment |
| **Proof Operator** | Type 16 (`PROOF`) | No — zero operators at deployment |
| **Recovery Address** | `initiateRecovery`, `executeRecovery`, `setRecoveryAddress` | Yes |

### Recovery

7-day timelocked ownership transfer. Owner can cancel any in-flight recovery. 7-day lockout after cancellation prevents griefing. Worst case is always time, never data loss.

### Indestructibility

The complete registry is reconstructable from Ethereum event logs alone. Every `Anchored` event contains all fields needed to rebuild the full artifact table. Trees reassemble automatically via `parentHash`. The `treeId` field enables one-query tree retrieval without traversal.

---

## foundry.toml

`via_ir = true` is required due to stack depth in the unified register entry points (`registerContent`, `registerGated`, `registerTargeted`, `registerSeal`), which decode ABI-encoded type-specific payloads into local memory:

```toml
[profile.default]
src     = "src"
out     = "out"
libs    = ["lib"]
via_ir  = true
remappings = ["forge-std/=lib/forge-std/src/"]

[profile.default.optimizer]
enabled = true
runs    = 200
```

---

## Watermark Standards

| Standard | For |
|----------|-----|
| `SPDX-Anchor` | Software artifacts — code, packages, repos, scripts |
| `DAPX-Anchor` | Everything else — research, data, models, media, text, legal |

**Format:** `SPDX-Anchor: anchorregistry.ai/AR-2026-0000001`

---

## License

BUSL-1.1 — Change Date: March 12, 2028 — Change License: Apache-2.0

© 2026 Ian Moore (icmoore). All rights reserved until the Change Date.

---

*AnchorRegistry™ · anchorregistry.com · anchorregistry.ai · @anchorregistry*
