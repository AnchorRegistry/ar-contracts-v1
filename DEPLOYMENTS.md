# AnchorRegistry — Deployments

Live contract deployments, verification status, and test results.

---

## Sepolia Testnet

**Status: Live**

| Field | Value |
|-------|-------|
| **Network** | Ethereum Sepolia (chain 11155111) |
| **Contract** | [`0x488ab4Aa772Fca36e45e1CB7223f859d2d1CFF36`](https://sepolia.etherscan.io/address/0x488ab4aa772fca36e45e1cb7223f859d2d1cff36) |
| **Verified** | Yes — [view source on Etherscan](https://sepolia.etherscan.io/address/0x488ab4aa772fca36e45e1cb7223f859d2d1cff36#code) |
| **Bytecode** | 7,576 bytes (31% of EIP-170 limit) |
| **Deploy cost** | ~2.4M gas |
| **Deployed** | March 23, 2026 |

### Addresses

| Role | Address |
|------|---------|
| **Owner** | `0x03Cf992A6805e013030956553D06a22DE4bbC5A6` |
| **Recovery** | `0x3A85B6f755aE31026e6B3B619Bec3ac94Af2970e` |
| **Operator (primary)** | `0xC7a7AFde1177fbF0Bb265Ea5a616d1b8D7eD8c44` |
| **Operator (backup)** | `0xC919F3096cb16Ae2840B50B1b2a211D63f613ef6` |

### Contract Architecture

Two source files, one deployed contract:

| File | Purpose |
|------|---------|
| `src/AnchorTypes.sol` | Type definitions — enum, structs, errors. Zero bytecode. |
| `src/AnchorRegistry.sol` | Contract logic — access control, storage, 3 register entry points. |

Three register entry points replace the original 22 individual functions:

| Function | Types | Gate |
|----------|-------|------|
| `registerContent(arId, base, extra)` | 0–12, 20, 21 | `onlyOperator` |
| `registerGated(arId, base, extra)` | 13–15 | `onlyLegal/Entity/ProofOperator` |
| `registerTargeted(arId, base, targetArId, extra)` | 16–19 | `onlyOperator` |

### Test Results

**Unit tests** — 179 passed, 0 failed (local Foundry suite):

```
forge test -vv
```

Covers all 22 artifact types, access control, recovery mechanism, parent-child lineage, dispute lifecycle, billing patterns, and edge cases.

**Fork tests** — 24 passed, 0 failed (against live Sepolia contract):

```
forge test --match-contract AnchorRegistryForkTest --fork-url $SEPOLIA_RPC_URL -vv
```

Covers deployment state verification, content registration across types, parent-child lineage, retraction, full review/void/affirmed lifecycle, access control enforcement, data retrieval and decoding, duplicate and invalid parent rejection, and capacity minimum enforcement.

---

## Base Mainnet

**Status: Pending**

---

*AnchorRegistry™ · anchorregistry.com · anchorregistry.ai · @anchorregistry*
