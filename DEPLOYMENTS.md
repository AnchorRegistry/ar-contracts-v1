# AnchorRegistry — Deployments

Live contract deployments, verification status, and test results.

---

## Base Mainnet — V1.5

**Status: Live**

| Field | Value |
|-------|-------|
| **Network** | Base Mainnet (chain 8453) |
| **Contract** | [`0x3eC509393425BCAa48224FB90C710e100ADA1D2A`](https://basescan.org/address/0x3ec509393425bcaa48224fb90c710e100ada1d2a) |
| **Verified** | Yes |

### Addresses

| Role | Address |
|------|---------|
| **Owner** | `0xb5111bd5fdd104A75B449d064604be5c1e044246` (cold) |
| **Recovery** | `0x9cA6daC5aD0d6B391E3A5c9Fb9bb94dc6875a771` (cold, separate) |
| **Operator (primary)** | `0xC7a7AFde1177fbF0Bb265Ea5a616d1b8D7eD8c44` |
| **Operator (backup)** | `0xb1547388D9E545396C08f38998D8F620cfDb0a89` |

---

## Base Sepolia — V1.5

**Status: Live**

| Field | Value |
|-------|-------|
| **Network** | Base Sepolia (chain 84532) |
| **Contract** | [`0xB0435faA6DeEDC1CB6a809008516fe4F4B094F76`](https://sepolia.basescan.org/address/0xb0435faa6deedc1cb6a809008516fe4f4b094f76) |
| **Verified** | Yes |

### Addresses

| Role | Address |
|------|---------|
| **Owner** | `0xb5111bd5fdd104A75B449d064604be5c1e044246` (cold) |
| **Recovery** | `0x9cA6daC5aD0d6B391E3A5c9Fb9bb94dc6875a771` (cold, separate) |
| **Operator (primary)** | `0xC7a7AFde1177fbF0Bb265Ea5a616d1b8D7eD8c44` |
| **Operator (backup)** | `0xb1547388D9E545396C08f38998D8F620cfDb0a89` |

---

## Contract Architecture

Two source files, one deployed contract:

| File | Purpose |
|------|---------|
| `src/AnchorTypes.sol` | Type definitions — enum, structs, errors. Zero bytecode. |
| `src/AnchorRegistry.sol` | Contract logic — access control, storage, 4 register entry points. |

Four register entry points cover all 24 artifact types:

| Function | Types | Gate |
|----------|-------|------|
| `registerContent(arId, base, extra, tokenCommitment)` | 0–13, 22, 23 | `onlyOperator` |
| `registerGated(arId, base, extra, tokenCommitment)` | 14–16 | `onlyLegal/Entity/ProofOperator` |
| `registerTargeted(arId, base, targetArId, extra, tokenCommitment)` | 18–21 | `onlyOperator` |
| `registerSeal(arId, newTreeRoot, reason, tokenCommitment)` | 17 (SEAL) | `onlyOperator` |

---

## Test Results

**Unit tests** — 212 passed, 0 failed (local Foundry suite):

```
forge test --no-match-contract AnchorRegistryForkTest
```

Covers all 24 artifact types, access control, recovery mechanism, parent-child lineage, dispute lifecycle, billing patterns, SEAL semantics, token commitment scheme, and edge cases.

**Fork tests** — 23 passed, 0 failed (against live Base Sepolia deployment):

```
source .env
forge test --match-contract AnchorRegistryForkTest --fork-url $BASE_SEPOLIA_RPC_URL -vv
```

Covers deployment state verification, content registration across types, parent-child lineage, retraction, full review/void/affirmed lifecycle, access control enforcement, data retrieval and decoding, duplicate AR-ID rejection, and capacity minimum enforcement.

---

## Historical

Deprecated deployments preserved for reference. Anchors registered against these contracts remain readable on-chain but are no longer the registration target.

### Base Sepolia — predecessor (deprecated)

| Field | Value |
|-------|-------|
| **Network** | Base Sepolia (chain 84532) |
| **Contract** | [`0x1a4a7238D65ce7eD0A2fd65b891290Be5Af622a8`](https://sepolia.basescan.org/address/0x1a4a7238d65ce7ed0a2fd65b891290be5af622a8) |
| **Status** | Deprecated — superseded by current Base Sepolia V1.5 deployment |

**Why retired.** Two design issues drove the move to V1.5:

- **AFFIRMED branch did not clear dispute flags.** `registerTargeted()` AFFIRMED path did not clear `reviewed[targetArId]` or `voided[targetArId]`. As a result, an AFFIRMED anchor following REVIEW or VOID could not seal the target's tree because the dispute flags stayed `true` permanently.
- **Cross-contract registration was bridged via `importAnchor()`.** A new `onlyOperator` function bridged AR-IDs from prior contract deployments by setting minimum state (registered + treeRoot + optional isSealed) so children registered on the new contract could reference parents anchored on prior contracts. This bridging proved insufficient to fully solve the cross-contract registration problem in production, and the architecture was revised in V1.5.

### Ethereum Sepolia — early deployment (deprecated)

| Field | Value |
|-------|-------|
| **Network** | Ethereum Sepolia (chain 11155111) |
| **Contract** | [`0x488ab4Aa772Fca36e45e1CB7223f859d2d1CFF36`](https://sepolia.etherscan.io/address/0x488ab4aa772fca36e45e1cb7223f859d2d1cff36) |
| **Status** | Deprecated — predates the move to Base Sepolia as the canonical testnet |

---

*AnchorRegistry™ · anchorregistry.com · anchorregistry.ai · @anchorregistry*
