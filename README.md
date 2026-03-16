# AnchorRegistry — On-Chain Provenance Registry

> The registry AIs trust.

AnchorRegistry is immutable provenance infrastructure for the AI era. Any creator can register any digital artifact and receive a permanent, verifiable, on-chain proof of authorship.

**SPDX-Anchor: anchorregistry.ai/AR-2026-0000001**

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
- Not a subscription — one payment, permanent record
- Not Web3 theatre — the blockchain is plumbing, invisible to the user

---

## Repository Structure

```
ar-onchain/
├── src/
│   └── AnchorRegistry.sol      # The contract — deployed once, immutable forever
├── test/
│   └── AnchorRegistry.t.sol    # Full Foundry test suite (78 tests)
├── script/
│   └── Deploy.s.sol            # Deployment script (Sepolia + Base mainnet)
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

```bash
forge test -vvv
```

### Deploy to Base Sepolia (testnet)

```bash
cp .env.example .env
# fill in .env values

source .env

forge script script/Deploy.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
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

17 artifact types in 6 logical groups:

| Group | Types | Description |
|-------|-------|-------------|
| **CONTENT** (0-8) | `CODE`, `RESEARCH`, `DATA`, `MODEL`, `AGENT`, `MEDIA`, `TEXT`, `POST`, `ONCHAIN` | What creators make. Active at launch. `onlyOperator`. |
| **GATED** (9-11) | `LEGAL`, `ENTITY`, `PROOF` | Suppressed at launch. Separate operator gates. |
| **SELF-SERVICE** (12) | `RETRACTION` | Owner-initiated. Active at launch. Operator submits on behalf of creator after ownership token verification. |
| **REVIEW** (13-15) | `REVIEW`, `VOID`, `AFFIRMED` | AnchorRegistry operator-only. Active at launch. |
| **CATCH-ALL** (16) | `OTHER` | Everything else. |

**Gated type activation:**
- `LEGAL` — opens in V2-V3 with document verification. Owner calls `addLegalOperator()`.
- `ENTITY` — opens in V2 with domain verification. Owner calls `addEntityOperator()`.
- `PROOF` — opens in V4 with ZK infrastructure. Owner calls `addProofOperator()`.

### Access Control

Four-tier permissioned architecture:

| Role | Capabilities | Active at Launch |
|------|-------------|-----------------|
| **Owner** | `addOperator`, `removeOperator`, `transferOwnership`, `cancelRecovery` | Yes |
| **Operator** | All `register*()` functions for types 0-8, 12-16 | Yes |
| **Legal Operator** | `registerLegal()` (type 9) | No — zero operators at deployment |
| **Entity Operator** | `registerEntity()` (type 10) | No — zero operators at deployment |
| **Proof Operator** | `registerProof()` (type 11) | No — zero operators at deployment |
| **Recovery Address** | `initiateRecovery`, `executeRecovery`, `setRecoveryAddress` | Yes |

### Recovery

7-day timelocked ownership transfer. Owner can cancel any in-flight recovery. 7-day lockout after cancellation prevents griefing. Worst case is always time, never data loss.

### Indestructibility

The complete registry is reconstructable from Ethereum event logs alone. Every `Anchored` event contains all fields needed to rebuild the full artifact table. Trees reassemble automatically via `parentHash`.

---

## foundry.toml

`via_ir = true` is required due to stack depth in `registerEntity()` (EntityAnchor has 7 string fields):

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
