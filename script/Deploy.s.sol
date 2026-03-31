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
///   Sepolia dry run (Trezor):
///   forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL \
///     --ledger --sender $DEPLOYER_ADDRESS -vvvv
///
///   Sepolia broadcast + verify (Trezor):
///   forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL \
///     --broadcast --verify --ledger --sender $DEPLOYER_ADDRESS -vvvv
///
///   Local Anvil (private key):
///   forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
///
///   Required env vars (Trezor / hardware wallet):
///     DEPLOYER_ADDRESS       - Trezor address (becomes owner)
///     RECOVERY_ADDRESS       - recovery address (may equal DEPLOYER_ADDRESS)
///     OPERATOR_ADDRESS       - hot wallet address for FastAPI backend
///     OPERATOR_BACKUP        - backup operator wallet address
///     SEPOLIA_RPC_URL        - Infura/Alchemy Sepolia endpoint
///     ETHERSCAN_API_KEY      - for Sepolia verification
///
///   Required env vars (local / CI — private key):
///     DEPLOYER_PRIVATE_KEY   - fallback when DEPLOYER_ADDRESS is not set
///     (all others above)

contract Deploy is Script {

    function run() external {
        // Support both hardware wallet (DEPLOYER_ADDRESS + --ledger) and
        // software wallet (DEPLOYER_PRIVATE_KEY) for local / CI use.
        address deployer;
        bool    usePrivateKey = vm.envOr("DEPLOYER_PRIVATE_KEY", bytes32(0)) != bytes32(0);

        if (usePrivateKey) {
            uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
            deployer = vm.addr(deployerKey);
            vm.startBroadcast(deployerKey);
        } else {
            deployer = vm.envAddress("DEPLOYER_ADDRESS");
            vm.startBroadcast(deployer);
        }

        address recoveryAddress = vm.envAddress("RECOVERY_ADDRESS");
        address operatorAddress = vm.envAddress("OPERATOR_ADDRESS");
        address operatorBackup  = vm.envAddress("OPERATOR_BACKUP");

        console.log("=== AnchorRegistry Deployment ===");
        console.log("Network:          ", block.chainid == 84532 ? "Base Sepolia" : block.chainid == 8453 ? "Base Mainnet" : block.chainid == 11155111 ? "Sepolia" : "Unknown");
        console.log("Chain ID:         ", block.chainid);
        console.log("Deployer (owner): ", deployer);
        console.log("Recovery address: ", recoveryAddress);
        console.log("Operator primary: ", operatorAddress);
        console.log("Operator backup:  ", operatorBackup);
        console.log("");

        // safety checks before broadcast
        require(recoveryAddress != address(0),      "Deploy: recovery address is zero");
        require(operatorAddress != address(0),      "Deploy: operator address is zero");
        require(operatorBackup  != address(0),      "Deploy: backup operator is zero");
        require(operatorAddress != recoveryAddress, "Deploy: operator must differ from recovery");
        require(operatorBackup  != operatorAddress, "Deploy: backup must differ from primary operator");

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
