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

## Base Sepolia Testnet

Two deployments live on Base Sepolia. V1B is the current target for new
ar-api registrations; V1A holds historical demo anchors and remains
readable via the Contract Continuity Protocol (lazy `importAnchor()` from
ar-api, multi-deployment lookup via `which_contract()` in ar-python).

### V1B — current

**Status: Live (Phase 6)**

| Field | Value |
|-------|-------|
| **Network** | Base Sepolia (chain 84532) |
| **Contract** | [`0x1a4a7238D65ce7eD0A2fd65b891290Be5Af622a8`](https://sepolia.basescan.org/address/0x1a4a7238d65ce7ed0a2fd65b891290be5af622a8) |
| **Verified** | Yes |
| **Bytecode** | ~12.3 KB (≈ 50% of EIP-170 limit) |
| **Deploy block** | 40,470,850 |
| **Deployed** | April 20, 2026 |
| **Source commit** | [`117d22b`](https://github.com/AnchorRegistry/ar-contracts-v1/commit/117d22b) (V1.5 Phase 6) |

#### Phase 6 changes vs V1A

- **AFFIRMED branch fix** — `registerTargeted()` AFFIRMED path now clears
  `reviewed[targetArId]` and `voided[targetArId]`. Before the fix, an
  AFFIRMED anchor following REVIEW or VOID could not seal the target's
  tree because the dispute flags stayed `true` forever.
- **`importAnchor(arId, treeRootArId, sealed_)`** — new `onlyOperator`
  function that bridges AR-IDs from prior contract deployments. Sets
  minimum state (registered + treeRoot + optional isSealed) so children
  registered on V1B can reference parents anchored on V1A. Source-of-
  truth data (`anchorData`, `tokenCommitments`, `Anchored` events) stays
  on the originating contract.

#### Addresses

| Role | Address |
|------|---------|
| **Owner** | `0xb5111bd5fdd104A75B449d064604be5c1e044246` (cold) |
| **Recovery** | `0x9cA6daC5aD0d6B391E3A5c9Fb9bb94dc6875a771` (cold, separate) |
| **Operator (primary)** | `0xC7a7AFde1177fbF0Bb265Ea5a616d1b8D7eD8c44` |
| **Operator (backup)** | `0xb1547388D9E545396C08f38998D8F620cfDb0a89` |

Deploy script (`script/Deploy.s.sol`) was updated in the same commit to
hand ownership from the hot signer key to `DEPLOYER_ADDRESS` as the final
broadcast step, so the operator never permanently holds owner rights.

#### Test Results

**Unit tests** — 221 passed, 0 failed:

```
forge test --no-match-contract Fork
```

213 pre-existing tests + 8 new Phase 6 tests under section `19. Phase 6`:
- `test_affirmed_clears_review_then_seal`
- `test_affirmed_clears_void_then_seal`
- `test_importAnchor_basic`
- `test_importAnchor_sealed`
- `test_importAnchor_revert_duplicate`
- `test_importAnchor_then_child`
- `test_importAnchor_sealed_blocks_child`
- `test_importAnchor_revert_notOperator`

### V1A — prior (still readable)

**Status: Live (historical)**

| Field | Value |
|-------|-------|
| **Network** | Base Sepolia (chain 84532) |
| **Contract** | [`0xb0435faa6deedc1cb6a809008516fe4f4b094f76`](https://sepolia.basescan.org/address/0xb0435faa6deedc1cb6a809008516fe4f4b094f76) |
| **Deploy block** | 40,223,296 |

Holds the original Phase 0–5 testnet anchors (e.g. `AR-2026-dPXazj6`).
Reachable from ar-python via:

```python
from anchorregistry import which_contract
which_contract("AR-2026-dPXazj6")
# → '0xb0435faa6deedc1cb6a809008516fe4f4b094f76'
```

---

## Base Mainnet

**Status: Pending**

---

*AnchorRegistry™ · anchorregistry.com · anchorregistry.ai · @anchorregistry*
