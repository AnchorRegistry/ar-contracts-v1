#!/usr/bin/env python3
"""
smoke_test.py — Local Anvil smoke test for AnchorRegistry.

Usage:
    1. Start Anvil in one terminal:   anvil
    2. Deploy the contract:           forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
    3. Run this script:               python3 script/smoke_test.py

Assumes the standard Anvil test accounts and the deterministic contract address
(0x5FbDB2315678afecb367f032d93F642f64180aa3) produced by a fresh Anvil + Deploy.
"""

import subprocess, struct, sys, os, json

# ── Config ────────────────────────────────────────────────────────────────────

RPC        = "http://127.0.0.1:8545"
REG        = None  # set dynamically after deploy

# Anvil default accounts — always funded on a fresh Anvil
ANVIL_KEY  = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"  # account #0 — deployer/owner
OP_KEY     = "0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a"  # account #2 — operator primary
OP_ADDR    = "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"
OP_BK_KEY  = "0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6"  # account #3 — operator backup
OP_BK_ADDR = "0x90F79bf6EB2c4f870365E785982E1f101E93b906"

BROADCAST  = "broadcast/Deploy.s.sol/31337/run-latest.json"

# ── Helpers ───────────────────────────────────────────────────────────────────

def cast(*args):
    result = subprocess.run(["cast", *args], capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"cast error: {result.stderr.strip()}")
    return result.stdout.strip()

def deploy():
    """Deploy using the Anvil default key — ignores any .env DEPLOYER_PRIVATE_KEY."""
    env = {k: v for k, v in os.environ.items()
           if k not in ("DEPLOYER_PRIVATE_KEY", "OPERATOR_ADDRESS", "OPERATOR_BACKUP")}
    env["DEPLOYER_PRIVATE_KEY"] = ANVIL_KEY
    env["OPERATOR_ADDRESS"]     = OP_ADDR
    env["OPERATOR_BACKUP"]      = OP_BK_ADDR
    result = subprocess.run(
        ["forge", "script", "script/Deploy.s.sol",
         "--rpc-url", RPC, "--broadcast"],
        capture_output=True, text=True, env=env
    )
    if result.returncode != 0:
        print(result.stdout[-2000:])
        raise RuntimeError(f"Deploy failed:\n{result.stderr.strip()}")
    ok("forge script Deploy.s.sol broadcast succeeded")

def get_deployed_address():
    """Read the contract address from the forge broadcast file."""
    with open(BROADCAST) as f:
        data = json.load(f)
    for tx in data.get("transactions", []):
        if tx.get("transactionType") == "CREATE":
            return tx["contractAddress"]
    raise RuntimeError(f"No CREATE transaction found in {BROADCAST}")

def abi_encode(sig, *values):
    return cast("abi-encode", sig, *values)

def send(ar_id, base_tuple, encoded_data, token_commitment="0x0000000000000000000000000000000000000000000000000000000000000001"):
    cast(
        "send", REG,
        "registerContent(string,(uint8,string,string,string,string,string,string),bytes,bytes32)",
        ar_id, base_tuple, encoded_data, token_commitment,
        "--private-key", OP_KEY, "--rpc-url", RPC,
    )

def send_targeted(ar_id, base_tuple, target_ar_id, encoded_data, token_commitment="0x0000000000000000000000000000000000000000000000000000000000000000"):
    cast(
        "send", REG,
        "registerTargeted(string,(uint8,string,string,string,string,string,string),string,bytes,bytes32)",
        ar_id, base_tuple, target_ar_id, encoded_data, token_commitment,
        "--private-key", OP_KEY, "--rpc-url", RPC,
    )

def token_commitment(ar_id):
    return cast("call", REG, "tokenCommitments(string)(bytes32)", ar_id, "--rpc-url", RPC)

def registered(ar_id):
    return cast("call", REG, "registered(string)(bool)", ar_id, "--rpc-url", RPC) == "true"

def get_anchor_data(ar_id):
    hex_data = cast("call", REG, "getAnchorData(string)(bytes)", ar_id, "--rpc-url", RPC)
    return bytes.fromhex(hex_data.removeprefix("0x"))

def decode_strings(data, n):
    offsets = [struct.unpack(">I", data[i*32+28:i*32+32])[0] for i in range(n)]
    result = []
    for off in offsets:
        length = struct.unpack(">I", data[off+28:off+32])[0]
        result.append(data[off+32:off+32+length].decode())
    return result

def base(artifact_type_int, hash_suffix, descriptor, title):
    return (f'({artifact_type_int},"sha256:{hash_suffix}","","{descriptor}","{title}","Ian Moore","")')

def ok(msg):   print(f"  \033[32m✓\033[0m  {msg}")
def fail(msg): print(f"  \033[31m✗\033[0m  {msg}"); sys.exit(1)

# ── Smoke anchors ─────────────────────────────────────────────────────────────
#
# Artifact type enum values (with WEBSITE=11 shifting all subsequent types):
#   CODE=0  MEDIA=5  TEXT=6  REPORT=9  NOTE=10  EVENT=12  RECEIPT=13  OTHER=22
#
# Each entry: (ar_id, type_int, hash_suffix, descriptor, title,
#              encode_sig, encode_values, field_labels, new_fields)

ANCHORS = [
    (
        "AR-SMOKE-CODE", 0, "smoke-code", "SMOKE-CODE", "Smoke Code",
        "f(string,string,string,string,string)",
        ["git:abc", "MIT", "Solidity", "v1.0.0", "https://github.com/test"],
        ["gitHash", "license", "language", "version", "url"],
        [],
    ),
    (
        "AR-SMOKE-MEDIA", 5, "smoke-media", "SMOKE-MEDIA", "Smoke Media",
        "f(string,string,string,string,string,string)",
        ["video/mp4", "YouTube", "MP4", "3:45", "USRC12345", "https://youtube.com/test"],
        ["mediaType", "platform", "format", "duration", "isrc", "url"],
        ["platform"],
    ),
    (
        "AR-SMOKE-TEXT", 6, "smoke-text", "SMOKE-TEXT", "Smoke Text",
        "f(string,string,string,string,string)",
        ["ARTICLE", "978-3-16-148410-0", "O'Reilly", "English", "https://example.com/article"],
        ["textType", "isbn", "publisher", "language", "url"],
        ["textType"],
    ),
    (
        "AR-SMOKE-REPORT", 9, "smoke-report", "SMOKE-REPORT", "Smoke Report",
        "f(string,string,string,string,string,string,string,string)",
        ["CONSULTING", "Acme Corp", "Q1-2026", "final", "Ian Moore", "Hive Advisory",
         "https://example.com/report", "sha256:filehash-report-abc123"],
        ["reportType", "client", "engagement", "version", "authors", "institution", "url", "fileManifestHash"],
        ["fileManifestHash"],
    ),
    (
        "AR-SMOKE-NOTE", 10, "smoke-note", "SMOKE-NOTE", "Smoke Note",
        "f(string,string,string,string,string)",
        ["MEETING", "2026-03-30", "Ian Moore, Jane Smith", "https://example.com/notes",
         "sha256:filehash-note-def456"],
        ["noteType", "date", "participants", "url", "fileManifestHash"],
        ["fileManifestHash"],
    ),
    (
        "AR-SMOKE-RECEIPT", 13, "smoke-receipt", "SMOKE-RECEIPT", "Smoke Receipt",
        "f(string,string,string,string,string,string,string,string)",
        ["PURCHASE", "Wayfair", "1299.99", "CAD", "ORD-2026-001", "shopify",
         "https://wayfair.com/orders/1", "sha256:filehash-receipt-ghi789"],
        ["receiptType", "merchant", "amount", "currency", "orderId", "platform", "url", "fileManifestHash"],
        ["platform", "fileManifestHash"],
    ),
    (
        "AR-SMOKE-OTHER", 22, "smoke-other", "SMOKE-OTHER", "Smoke Other",
        "f(string,string,string,string,string)",
        ["course", "Thinkific", "https://thinkific.com/test", "DeFi 101",
         "sha256:filehash-other-jkl012"],
        ["kind", "platform", "url", "value", "fileManifestHash"],
        ["fileManifestHash"],
    ),
    (
        "AR-SMOKE-WEBSITE", 11, "smoke-website", "SMOKE-WEBSITE", "Smoke Website",
        "f(string,string,string)",
        ["https://anchorregistry.com", "custom", "On-chain provenance registry"],
        ["url", "platform", "description"],
        ["url", "platform", "description"],
    ),
]

# ── Main ──────────────────────────────────────────────────────────────────────

print(f"\n{'='*60}")
print(f"  AnchorRegistry Smoke Test  —  {REG}")
print(f"{'='*60}")

# Deploy fresh contract using Anvil default key
print("\n── Deploying contract ──")
try:
    deploy()
    REG = get_deployed_address()
    ok(f"Contract deployed at {REG}")
except Exception as e:
    print(f"\n\033[31mDeploy failed: {e}\033[0m")
    print("Make sure Anvil is running:  anvil")
    sys.exit(1)

errors = 0

for (ar_id, atype, hash_sfx, desc, title, enc_sig, enc_vals, labels, new_fields) in ANCHORS:
    print(f"\n── {ar_id} (type {atype}) ──")

    # 1. Register
    try:
        encoded = abi_encode(enc_sig, *enc_vals)
        send(ar_id, base(atype, hash_sfx, desc, title), encoded)
        ok("registerContent() succeeded")
    except Exception as e:
        fail(f"registerContent() failed: {e}")

    # 2. registered() check
    if registered(ar_id):
        ok("registered() == true")
    else:
        fail("registered() returned false")
        errors += 1

    # 3. Decode and display fields
    try:
        data   = get_anchor_data(ar_id)
        vals   = decode_strings(data, len(labels))
        for label, val in zip(labels, vals):
            star = " \033[33m← NEW\033[0m" if label in new_fields else ""
            print(f"       {label:22s} = {repr(val)}{star}")

        # Spot-check: fileManifestHash round-trips correctly
        for label, val in zip(labels, vals):
            if label == "fileManifestHash" and enc_vals[-1].startswith("sha256:"):
                if val != enc_vals[-1]:
                    fail(f"fileManifestHash mismatch: got {repr(val)}")
                    errors += 1
                else:
                    ok("fileManifestHash round-trips correctly")
    except Exception as e:
        fail(f"getAnchorData() decode failed: {e}")
        errors += 1

# ── RETRACTION — tokenCommitment must be stored ───────────────────────────────
print(f"\n── AR-SMOKE-RETRACT (type 17) ──")
RET_COMMITMENT = "0x00000000000000000000000000000000000000000000000000000000deadbeef"
try:
    retract_base = base(17, "smoke-retract", "SMOKE-RETRACT", "Smoke Retraction")
    encoded = abi_encode("f(string,string)", "superseded by new version", "")
    send_targeted("AR-SMOKE-RETRACT", retract_base, "AR-SMOKE-CODE", encoded, RET_COMMITMENT)
    ok("registerTargeted() RETRACTION succeeded")
except Exception as e:
    fail(f"registerTargeted() failed: {e}")
    errors += 1

if registered("AR-SMOKE-RETRACT"):
    ok("registered() == true")
else:
    fail("registered() returned false")
    errors += 1

stored = token_commitment("AR-SMOKE-RETRACT")
if stored.lower() == RET_COMMITMENT.lower():
    ok(f"tokenCommitment stored correctly: {stored}")
else:
    fail(f"tokenCommitment mismatch: got {stored}")
    errors += 1

print(f"\n{'='*60}")
if errors == 0:
    print("  \033[32m✅  All checks passed\033[0m")
else:
    print(f"  \033[31m✗   {errors} check(s) failed\033[0m")
print(f"{'='*60}\n")
sys.exit(0 if errors == 0 else 1)
