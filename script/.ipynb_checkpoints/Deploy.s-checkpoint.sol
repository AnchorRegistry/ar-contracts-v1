// SPDX-License-Identifier: BUSL-1.1
// Change Date: March 12, 2028
// Change License: Apache-2.0
// Licensor: Ian Moore (icmoore)

pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/AnchorRegistry.sol";

/// @notice Deploy AnchorRegistry to any network.
/// @dev Usage:
///
///   Sepolia (dry run):
///   forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL -vvvv
///
///   Sepolia (broadcast):
///   forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvvv
///
///   Base mainnet (broadcast + verify):
///   forge script script/Deploy.s.sol --rpc-url $BASE_RPC_URL --broadcast --verify -vvvv
///
///   Required env vars:
///     DEPLOYER_PRIVATE_KEY   - owner wallet private key (hardware wallet recommended for mainnet)
///     RECOVERY_ADDRESS       - cold storage address (never the same as deployer)
///     OPERATOR_ADDRESS       - hot wallet address for FastAPI backend
///     OPERATOR_BACKUP        - backup operator wallet address
///     SEPOLIA_RPC_URL        - Infura/Alchemy Sepolia endpoint
///     BASE_RPC_URL           - Infura/Alchemy Base mainnet endpoint
///     ETHERSCAN_API_KEY      - for Sepolia verification
///     BASESCAN_API_KEY       - for Base verification

contract Deploy is Script {

    function run() external {
        uint256 deployerKey     = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address recoveryAddress = vm.envAddress("RECOVERY_ADDRESS");
        address operatorAddress = vm.envAddress("OPERATOR_ADDRESS");
        address operatorBackup  = vm.envAddress("OPERATOR_BACKUP");

        address deployer = vm.addr(deployerKey);

        console.log("=== AnchorRegistry Deployment ===");
        console.log("Network:          ", block.chainid == 84532 ? "Base Sepolia" : block.chainid == 8453 ? "Base Mainnet" : block.chainid == 11155111 ? "Sepolia" : "Unknown");
        console.log("Chain ID:         ", block.chainid);
        console.log("Deployer (owner): ", deployer);
        console.log("Recovery address: ", recoveryAddress);
        console.log("Operator primary: ", operatorAddress);
        console.log("Operator backup:  ", operatorBackup);
        console.log("");

        // safety checks before broadcast
        require(recoveryAddress != address(0),   "Deploy: recovery address is zero");
        require(operatorAddress != address(0),   "Deploy: operator address is zero");
        require(operatorBackup  != address(0),   "Deploy: backup operator is zero");
        require(recoveryAddress != deployer,      "Deploy: recovery must differ from owner");
        require(operatorAddress != recoveryAddress, "Deploy: operator must differ from recovery");
        require(operatorBackup  != operatorAddress, "Deploy: backup must differ from primary operator");

        vm.startBroadcast(deployerKey);

        AnchorRegistry registry = new AnchorRegistry(recoveryAddress);

        registry.addOperator(operatorAddress);
        registry.addOperator(operatorBackup);

        vm.stopBroadcast();

        console.log("=== Deployment Complete ===");
        console.log("Contract address: ", address(registry));
        console.log("Owner:            ", registry.owner());
        console.log("Recovery address: ", registry.recoveryAddress());
        console.log("Operator primary: ", operatorAddress, "->", registry.operators(operatorAddress) ? "ACTIVE" : "FAILED");
        console.log("Operator backup:  ", operatorBackup,  "->", registry.operators(operatorBackup)  ? "ACTIVE" : "FAILED");
        console.log("");
        console.log("=== Post-Deployment Checklist ===");
        console.log("1. Record contract address permanently");
        console.log("2. Record deploy block number from transaction");
        console.log("3. Verify on Etherscan/Basescan");
        console.log("4. Set ANCHOR_REGISTRY_ADDRESS in FastAPI .env");
        console.log("5. Set Etherscan alert on contract address");
        console.log("6. Fund operator wallet with ETH for gas");
        console.log("7. Run one end-to-end registration test");
    }
}
