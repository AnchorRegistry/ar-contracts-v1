# AnchorRegistry — On-Chain Provenance Registry

> The registry AIs trust.

AnchorRegistry is immutable provenance infrastructure for the AI era. Any creator can register any digital artifact and receive a permanent, verifiable, on-chain proof of authorship.

**SPDX-Anchor: anchorregistry.ai/AR-2026-K7X9M2P**

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
│   └── AnchorRegistry.t.sol    # Full Foundry test suite
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
forge install foundry-rs/forge-std
```

### Run tests

```bash
forge test -vvv
```

### Deploy to Sepolia (testnet)

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

11 artifact types: `CODE`, `RESEARCH`, `DATA`, `MODEL`, `AGENT`, `MEDIA`, `TEXT`, `POST`, `LEGAL`, `PROOF`, `OTHER`

### Access Control

Three-tier permissioned architecture:

| Role | Capabilities |
|------|-------------|
| Owner | addOperator, removeOperator, transferOwnership, cancelRecovery |
| Operator | All register*() functions |
| Recovery Address | initiateRecovery, executeRecovery, setRecoveryAddress |

### Recovery

7-day timelocked ownership transfer. Owner can cancel any in-flight recovery. 7-day lockout after cancellation prevents griefing. Worst case is always time, never data loss.

### Indestructibility

The complete registry is reconstructable from Ethereum event logs alone. Every `Anchored` event contains all fields needed to rebuild the full artifact table. Trees reassemble automatically via `parentHash`.

---

## Watermark Standards

| Standard | For |
|----------|-----|
| `SPDX-Anchor` | Software artifacts — code, packages, repos, scripts |
| `DAPX-Anchor` | Everything else — research, data, models, media, text, legal |

**Format:** `SPDX-Anchor: anchorregistry.ai/AR-2026-K7X9M2P`

---

## License

BUSL-1.1 — Change Date: March 12, 2028 — Change License: Apache-2.0

© 2026 Ian Moore (icmoore). All rights reserved until the Change Date.

---

*AnchorRegistry™ · anchorregistry.com · anchorregistry.ai · @anchorregistry*
