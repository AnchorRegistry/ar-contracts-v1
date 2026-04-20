// SPDX-License-Identifier: BUSL-1.1
// Change Date: March 12, 2028
// Change License: Apache-2.0
// Licensor: Ian Moore (icmoore)

pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/AnchorRegistry.sol";

/// @notice Deploy AnchorRegistry to any network.
/// @dev Three supported deployment patterns:
///
///   A) Trezor-signs-deploy (cold key signs, becomes owner):
///        DEPLOYER_ADDRESS   = Trezor address  (both signer and final owner)
///        (DEPLOYER_PRIVATE_KEY unset)
///      Trezor signs via --ledger and becomes owner directly. No transfer.
///
///   B) Hot-signs-deploy, cold-becomes-owner (recommended for testnet + mainnet):
///        DEPLOYER_PRIVATE_KEY = hot operator key (signs the deploy tx)
///        DEPLOYER_ADDRESS     = Trezor 1 (cold wallet — will own the contract)
///      Hot key signs the broadcast, script calls transferOwnership(DEPLOYER_ADDRESS)
///      as the final step. End state: Trezor 1 = owner, hot key = nothing.
///
///   C) Local / CI dev loop:
///        DEPLOYER_PRIVATE_KEY = dev key (signer and owner)
///        (DEPLOYER_ADDRESS unset, or == vm.addr(DEPLOYER_PRIVATE_KEY))
///      Dev key is both signer and owner. No transfer.
///
/// @dev Usage:
///
///   Sepolia dry run (Trezor, pattern A):
///   forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL \
///     --ledger --sender $DEPLOYER_ADDRESS -vvvv
///
///   Sepolia broadcast + verify (hot signer, cold owner — pattern B):
///   set -a; source .env; set +a
///   forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL \
///     --broadcast --verify -vvvv
///
///   Local Anvil (pattern C):
///   forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
///
///   Env vars:
///     DEPLOYER_ADDRESS     - final owner address
///                            Pattern A: Trezor signing via --ledger
///                            Pattern B: cold wallet that receives ownership
///                            Pattern C: omit (or match signer)
///     DEPLOYER_PRIVATE_KEY - hot signer key (patterns B and C only)
///     RECOVERY_ADDRESS     - recovery role (Trezor 2 recommended)
///     OPERATOR_ADDRESS     - hot wallet address for FastAPI backend
///     OPERATOR_BACKUP      - backup operator wallet address
///     ETHERSCAN_API_KEY    - for --verify flag

contract Deploy is Script {

    function run() external {
        // Resolve signer. Private-key path broadcasts with the raw key; the
        // --ledger path broadcasts with DEPLOYER_ADDRESS via hardware wallet.
        address signer;
        bool    usePrivateKey = vm.envOr("DEPLOYER_PRIVATE_KEY", bytes32(0)) != bytes32(0);

        if (usePrivateKey) {
            uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
            signer = vm.addr(deployerKey);
            vm.startBroadcast(deployerKey);
        } else {
            signer = vm.envAddress("DEPLOYER_ADDRESS");
            vm.startBroadcast(signer);
        }

        address recoveryAddress = vm.envAddress("RECOVERY_ADDRESS");
        address operatorAddress = vm.envAddress("OPERATOR_ADDRESS");
        address operatorBackup  = vm.envAddress("OPERATOR_BACKUP");

        // Final owner = DEPLOYER_ADDRESS when set, else signer.
        // When both DEPLOYER_PRIVATE_KEY and DEPLOYER_ADDRESS are set and differ,
        // the script transfers ownership from signer → DEPLOYER_ADDRESS as the
        // last broadcast step (pattern B).
        address finalOwner = vm.envOr("DEPLOYER_ADDRESS", address(0));
        if (finalOwner == address(0)) finalOwner = signer;

        bool willTransfer = (finalOwner != signer);

        console.log("=== AnchorRegistry Deployment ===");
        console.log("Network:          ", block.chainid == 84532 ? "Base Sepolia" : block.chainid == 8453 ? "Base Mainnet" : block.chainid == 11155111 ? "Sepolia" : "Unknown");
        console.log("Chain ID:         ", block.chainid);
        console.log("Signer:           ", signer);
        console.log("Recovery address: ", recoveryAddress);
        console.log("Operator primary: ", operatorAddress);
        console.log("Operator backup:  ", operatorBackup);
        if (willTransfer) {
            console.log("Final owner:      ", finalOwner, "(ownership will be transferred from signer)");
        } else {
            console.log("Final owner:       signer (no transfer)");
        }
        console.log("");

        // Safety checks before broadcast.
        require(recoveryAddress != address(0),      "Deploy: recovery address is zero");
        require(operatorAddress != address(0),      "Deploy: operator address is zero");
        require(operatorBackup  != address(0),      "Deploy: backup operator is zero");
        require(operatorAddress != recoveryAddress, "Deploy: operator must differ from recovery");
        require(operatorBackup  != operatorAddress, "Deploy: backup must differ from primary operator");
        if (willTransfer) {
            // Cold owner must not collide with hot operator roles — otherwise
            // ownership ends up on a hot key, defeating the split.
            require(finalOwner != operatorAddress, "Deploy: DEPLOYER_ADDRESS must differ from OPERATOR_ADDRESS");
            require(finalOwner != operatorBackup,  "Deploy: DEPLOYER_ADDRESS must differ from OPERATOR_BACKUP");
        }

        AnchorRegistry registry = new AnchorRegistry(recoveryAddress);

        registry.addOperator(operatorAddress);
        registry.addOperator(operatorBackup);

        // Ownership handoff — MUST be last onlyOwner call in this broadcast.
        // After this, `signer` can no longer invoke onlyOwner functions.
        if (willTransfer) {
            registry.transferOwnership(finalOwner);
        }

        vm.stopBroadcast();

        console.log("=== Deployment Complete ===");
        console.log("Contract address: ", address(registry));
        console.log("Owner:            ", registry.owner());
        console.log("Recovery address: ", registry.recoveryAddress());
        console.log("Operator primary: ", operatorAddress, "->", registry.operators(operatorAddress) ? "ACTIVE" : "FAILED");
        console.log("Operator backup:  ", operatorBackup,  "->", registry.operators(operatorBackup)  ? "ACTIVE" : "FAILED");
        if (willTransfer) {
            console.log("Ownership:         transferred from signer to DEPLOYER_ADDRESS");
        }
        console.log("");
        console.log("=== Post-Deployment Checklist ===");
        console.log("1. Record contract address permanently");
        console.log("2. Record deploy block number from transaction");
        console.log("3. Verify on Etherscan/Basescan");
        console.log("4. Set ANCHOR_REGISTRY_ADDRESS in FastAPI .env");
        console.log("5. Set Etherscan alert on contract address");
        console.log("6. Fund operator wallet with ETH for gas");
        console.log("7. Run one end-to-end registration test");
        if (willTransfer) {
            console.log("8. Confirm cold-wallet owner can sign owner-only txs");
        }
    }
}
