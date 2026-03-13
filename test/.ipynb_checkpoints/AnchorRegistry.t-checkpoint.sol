// SPDX-License-Identifier: BUSL-1.1
// Change Date: March 12, 2028
// Change License: Apache-2.0
// Licensor: Ian Moore (icmoore)

pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/AnchorRegistry.sol";

contract AnchorRegistryTest is Test {

    AnchorRegistry public registry;

    address public owner       = address(0x1);
    address public operator    = address(0x2);
    address public opBackup    = address(0x3);
    address public recovery    = address(0x4);
    address public stranger    = address(0x5);
    address public newOwner    = address(0x6);
    address public newRecovery = address(0x7);

    // shared base fixture
    AnchorRegistry.AnchorBase base = AnchorRegistry.AnchorBase({
        artifactType: AnchorRegistry.ArtifactType.CODE,
        manifestHash: "sha256:abc123",
        parentHash:   "",
        descriptor:   "ICMOORE-2026-TEST"
    });

    function setUp() public {
        vm.prank(owner);
        registry = new AnchorRegistry(recovery);

        vm.prank(owner);
        registry.addOperator(operator);

        vm.prank(owner);
        registry.addOperator(opBackup);
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    function _base(string memory manifestHash) internal view returns (AnchorRegistry.AnchorBase memory) {
        return AnchorRegistry.AnchorBase({
            artifactType: AnchorRegistry.ArtifactType.CODE,
            manifestHash: manifestHash,
            parentHash:   "",
            descriptor:   "TEST"
        });
    }

    function _baseWithParent(string memory manifestHash, string memory parentHash)
        internal pure returns (AnchorRegistry.AnchorBase memory)
    {
        return AnchorRegistry.AnchorBase({
            artifactType: AnchorRegistry.ArtifactType.CODE,
            manifestHash: manifestHash,
            parentHash:   parentHash,
            descriptor:   "TEST-CHILD"
        });
    }

    function _registerCode(string memory arId, string memory manifestHash) internal {
        AnchorRegistry.AnchorBase memory b = _base(manifestHash);
        vm.prank(operator);
        registry.registerCode(arId, b, "git:abc", "Apache-2.0", "https://github.com/test");
    }

    // =========================================================================
    // 1. ALL REGISTER FUNCTIONS (11 artifact types)
    // =========================================================================

    function test_RegisterCode() public {
        vm.prank(operator);
        vm.expectEmit(true, true, false, true);
        emit AnchorRegistry.Anchored("AR-2026-CODE01", operator, AnchorRegistry.ArtifactType.CODE, "TEST", "sha256:abc123", "");
        registry.registerCode("AR-2026-CODE01", base, "gitabc123", "Apache-2.0", "https://github.com/test");

        assertTrue(registry.registered("AR-2026-CODE01"));
    }

    function test_RegisterResearch() public {
        AnchorRegistry.AnchorBase memory b = AnchorRegistry.AnchorBase({
            artifactType: AnchorRegistry.ArtifactType.RESEARCH,
            manifestHash: "sha256:research01",
            parentHash:   "",
            descriptor:   "PAPER-2026"
        });
        vm.prank(operator);
        registry.registerResearch("AR-2026-RES01", b, "10.1000/xyz123", "https://arxiv.org/abs/test");
        assertTrue(registry.registered("AR-2026-RES01"));
    }

    function test_RegisterData() public {
        AnchorRegistry.AnchorBase memory b = AnchorRegistry.AnchorBase({
            artifactType: AnchorRegistry.ArtifactType.DATA,
            manifestHash: "sha256:data01",
            parentHash:   "",
            descriptor:   "DATASET-2026"
        });
        vm.prank(operator);
        registry.registerData("AR-2026-DATA01", b, "v1.0.0", "https://huggingface.co/datasets/test");
        assertTrue(registry.registered("AR-2026-DATA01"));
    }

    function test_RegisterModel() public {
        AnchorRegistry.AnchorBase memory b = AnchorRegistry.AnchorBase({
            artifactType: AnchorRegistry.ArtifactType.MODEL,
            manifestHash: "sha256:model01",
            parentHash:   "",
            descriptor:   "MODEL-2026"
        });
        vm.prank(operator);
        registry.registerModel("AR-2026-MDL01", b, "v1.0.0", "https://huggingface.co/test");
        assertTrue(registry.registered("AR-2026-MDL01"));
    }

    function test_RegisterAgent() public {
        AnchorRegistry.AnchorBase memory b = AnchorRegistry.AnchorBase({
            artifactType: AnchorRegistry.ArtifactType.AGENT,
            manifestHash: "sha256:agent01",
            parentHash:   "",
            descriptor:   "AGENT-2026"
        });
        vm.prank(operator);
        registry.registerAgent("AR-2026-AGT01", b, "v0.1.0", "https://github.com/test-agent");
        assertTrue(registry.registered("AR-2026-AGT01"));
    }

    function test_RegisterMedia() public {
        AnchorRegistry.AnchorBase memory b = AnchorRegistry.AnchorBase({
            artifactType: AnchorRegistry.ArtifactType.MEDIA,
            manifestHash: "sha256:media01",
            parentHash:   "",
            descriptor:   "MEDIA-2026"
        });
        vm.prank(operator);
        registry.registerMedia("AR-2026-MED01", b, "image/png", "https://ipfs.io/ipfs/test");
        assertTrue(registry.registered("AR-2026-MED01"));
    }

    function test_RegisterText() public {
        AnchorRegistry.AnchorBase memory b = AnchorRegistry.AnchorBase({
            artifactType: AnchorRegistry.ArtifactType.TEXT,
            manifestHash: "sha256:text01",
            parentHash:   "",
            descriptor:   "ARTICLE-2026"
        });
        vm.prank(operator);
        registry.registerText("AR-2026-TXT01", b, "https://medium.com/@test");
        assertTrue(registry.registered("AR-2026-TXT01"));
    }

    function test_RegisterPost() public {
        AnchorRegistry.AnchorBase memory b = AnchorRegistry.AnchorBase({
            artifactType: AnchorRegistry.ArtifactType.POST,
            manifestHash: "sha256:post01",
            parentHash:   "",
            descriptor:   "POST-2026"
        });
        vm.prank(operator);
        registry.registerPost("AR-2026-PST01", b, "X/Twitter", "https://x.com/anchorregistry/status/1");
        assertTrue(registry.registered("AR-2026-PST01"));
    }

    function test_RegisterLegal() public {
        AnchorRegistry.AnchorBase memory b = AnchorRegistry.AnchorBase({
            artifactType: AnchorRegistry.ArtifactType.LEGAL,
            manifestHash: "sha256:legal01",
            parentHash:   "",
            descriptor:   "TRADEMARK-2026"
        });
        vm.prank(operator);
        registry.registerLegal("AR-2026-LGL01", b, "trademark", "https://cipo.ic.gc.ca/test");
        assertTrue(registry.registered("AR-2026-LGL01"));
    }

    function test_RegisterProof() public {
        AnchorRegistry.AnchorBase memory b = AnchorRegistry.AnchorBase({
            artifactType: AnchorRegistry.ArtifactType.PROOF,
            manifestHash: "sha256:proof01",
            parentHash:   "",
            descriptor:   "ZK-PROOF-2026"
        });
        vm.prank(operator);
        registry.registerProof("AR-2026-PRF01", b, "groth16");
        assertTrue(registry.registered("AR-2026-PRF01"));
    }

    function test_RegisterOther() public {
        AnchorRegistry.AnchorBase memory b = AnchorRegistry.AnchorBase({
            artifactType: AnchorRegistry.ArtifactType.OTHER,
            manifestHash: "sha256:other01",
            parentHash:   "",
            descriptor:   "OTHER-2026"
        });
        vm.prank(operator);
        registry.registerOther("AR-2026-OTH01", b, "course", "Thinkific", "https://thinkific.com/test", "DeFi 101");
        assertTrue(registry.registered("AR-2026-OTH01"));
    }

    function test_BackupOperatorCanRegister() public {
        vm.prank(opBackup);
        registry.registerCode("AR-2026-BACK01", base, "gitbackup", "MIT", "https://github.com/backup");
        assertTrue(registry.registered("AR-2026-BACK01"));
    }

    // =========================================================================
    // 2. ACCESS CONTROL
    // =========================================================================

    function test_OwnerSetOnDeploy() public view {
        assertEq(registry.owner(), owner);
    }

    function test_RecoveryAddressSetOnDeploy() public view {
        assertEq(registry.recoveryAddress(), recovery);
    }

    function test_OperatorAddedByOwner() public view {
        assertTrue(registry.operators(operator));
    }

    function test_StrangerCannotRegister() public {
        vm.prank(stranger);
        vm.expectRevert(AnchorRegistry.NotOperator.selector);
        registry.registerCode("AR-2026-FAIL01", base, "git:fail", "MIT", "https://github.com/fail");
    }

    function test_OwnerCannotRegister() public {
        vm.prank(owner);
        vm.expectRevert(AnchorRegistry.NotOperator.selector);
        registry.registerCode("AR-2026-FAIL02", base, "git:fail", "MIT", "https://github.com/fail");
    }

    function test_StrangerCannotAddOperator() public {
        vm.prank(stranger);
        vm.expectRevert(AnchorRegistry.NotOwner.selector);
        registry.addOperator(stranger);
    }

    function test_OwnerCanRemoveOperator() public {
        vm.prank(owner);
        registry.removeOperator(operator);
        assertFalse(registry.operators(operator));
    }

    function test_RemovedOperatorCannotRegister() public {
        vm.prank(owner);
        registry.removeOperator(operator);

        vm.prank(operator);
        vm.expectRevert(AnchorRegistry.NotOperator.selector);
        registry.registerCode("AR-2026-FAIL03", base, "git:fail", "MIT", "https://github.com/fail");
    }

    function test_OwnerCanTransferOwnership() public {
        vm.prank(owner);
        registry.transferOwnership(newOwner);
        assertEq(registry.owner(), newOwner);
    }

    function test_StrangerCannotTransferOwnership() public {
        vm.prank(stranger);
        vm.expectRevert(AnchorRegistry.NotOwner.selector);
        registry.transferOwnership(stranger);
    }

    function test_AddOperatorZeroAddressReverts() public {
        vm.prank(owner);
        vm.expectRevert(AnchorRegistry.ZeroAddress.selector);
        registry.addOperator(address(0));
    }

    function test_TransferOwnershipZeroAddressReverts() public {
        vm.prank(owner);
        vm.expectRevert(AnchorRegistry.ZeroAddress.selector);
        registry.transferOwnership(address(0));
    }

    function test_DeployZeroRecoveryReverts() public {
        vm.prank(owner);
        vm.expectRevert(AnchorRegistry.ZeroAddress.selector);
        new AnchorRegistry(address(0));
    }

    // =========================================================================
    // 3. EDGE CASES
    // =========================================================================

    function test_EmptyArIdReverts() public {
        vm.prank(operator);
        vm.expectRevert(AnchorRegistry.EmptyArId.selector);
        registry.registerCode("", base, "git:abc", "MIT", "https://github.com/test");
    }

    function test_EmptyManifestHashReverts() public {
        AnchorRegistry.AnchorBase memory b = AnchorRegistry.AnchorBase({
            artifactType: AnchorRegistry.ArtifactType.CODE,
            manifestHash: "",
            parentHash:   "",
            descriptor:   "TEST"
        });
        vm.prank(operator);
        vm.expectRevert(AnchorRegistry.EmptyManifestHash.selector);
        registry.registerCode("AR-2026-FAIL04", b, "git:abc", "MIT", "https://github.com/test");
    }

    function test_DuplicateArIdReverts() public {
        _registerCode("AR-2026-DUP01", "sha256:first");

        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(AnchorRegistry.AlreadyRegistered.selector, "AR-2026-DUP01"));
        registry.registerCode("AR-2026-DUP01", base, "git:abc", "MIT", "https://github.com/test");
    }

    function test_InvalidParentHashReverts() public {
        AnchorRegistry.AnchorBase memory b = AnchorRegistry.AnchorBase({
            artifactType: AnchorRegistry.ArtifactType.CODE,
            manifestHash: "sha256:child01",
            parentHash:   "AR-2026-DOESNOTEXIST",
            descriptor:   "CHILD"
        });
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(AnchorRegistry.InvalidParent.selector, "AR-2026-DOESNOTEXIST"));
        registry.registerCode("AR-2026-CHILD01", b, "git:child", "MIT", "https://github.com/child");
    }

    function test_ValidParentHashSucceeds() public {
        _registerCode("AR-2026-ROOT01", "sha256:root");

        AnchorRegistry.AnchorBase memory child = _baseWithParent("sha256:child", "AR-2026-ROOT01");
        vm.prank(operator);
        registry.registerCode("AR-2026-CHILD02", child, "git:child", "MIT", "https://github.com/child");

        assertTrue(registry.registered("AR-2026-CHILD02"));
    }

    function test_DeepLineageTree() public {
        _registerCode("AR-2026-L0", "sha256:level0");

        AnchorRegistry.AnchorBase memory l1 = _baseWithParent("sha256:level1", "AR-2026-L0");
        vm.prank(operator);
        registry.registerCode("AR-2026-L1", l1, "git:l1", "MIT", "https://github.com/l1");

        AnchorRegistry.AnchorBase memory l2 = _baseWithParent("sha256:level2", "AR-2026-L1");
        vm.prank(operator);
        registry.registerCode("AR-2026-L2", l2, "git:l2", "MIT", "https://github.com/l2");

        AnchorRegistry.AnchorBase memory l3 = _baseWithParent("sha256:level3", "AR-2026-L2");
        vm.prank(operator);
        registry.registerCode("AR-2026-L3", l3, "git:l3", "MIT", "https://github.com/l3");

        assertTrue(registry.registered("AR-2026-L3"));
    }

    function test_AnchoredEventEmitted() public {
        vm.prank(operator);
        vm.expectEmit(true, true, false, true);
        emit AnchorRegistry.Anchored(
            "AR-2026-EVT01",
            operator,
            AnchorRegistry.ArtifactType.CODE,
            "ICMOORE-2026-TEST",
            "sha256:abc123",
            ""
        );
        registry.registerCode("AR-2026-EVT01", base, "gitabc", "MIT", "https://github.com/evt");
    }

    function test_MultipleArtifactsSameOperator() public {
        for (uint256 i = 0; i < 5; i++) {
            string memory arId = string(abi.encodePacked("AR-2026-MULTI0", vm.toString(i)));
            string memory hash = string(abi.encodePacked("sha256:multi", vm.toString(i)));
            _registerCode(arId, hash);
        }
        for (uint256 i = 0; i < 5; i++) {
            string memory arId = string(abi.encodePacked("AR-2026-MULTI0", vm.toString(i)));
            assertTrue(registry.registered(arId));
        }
    }

    // =========================================================================
    // 4. RECOVERY FLOW & GRIEFING DEFENCE
    // =========================================================================

    function test_RecoveryInitiatedByRecoveryAddress() public {
        vm.prank(recovery);
        vm.expectEmit(true, true, false, false);
        emit AnchorRegistry.RecoveryInitiated(recovery, newOwner);
        registry.initiateRecovery(newOwner);

        assertEq(registry.pendingOwner(), newOwner);
        assertGt(registry.recoveryInitiatedAt(), 0);
    }

    function test_StrangerCannotInitiateRecovery() public {
        vm.prank(stranger);
        vm.expectRevert(AnchorRegistry.NotRecoveryAddress.selector);
        registry.initiateRecovery(newOwner);
    }

    function test_RecoveryExecutedAfterDelay() public {
        vm.prank(recovery);
        registry.initiateRecovery(newOwner);

        vm.warp(block.timestamp + 7 days + 1);

        vm.prank(recovery);
        vm.expectEmit(true, true, false, false);
        emit AnchorRegistry.RecoveryExecuted(newOwner);
        registry.executeRecovery();

        assertEq(registry.owner(), newOwner);
        assertEq(registry.pendingOwner(), address(0));
        assertEq(registry.recoveryInitiatedAt(), 0);
    }

    function test_RecoveryCannotExecuteBeforeDelay() public {
        vm.prank(recovery);
        registry.initiateRecovery(newOwner);

        vm.warp(block.timestamp + 6 days);

        vm.prank(recovery);
        vm.expectRevert(AnchorRegistry.RecoveryDelayNotMet.selector);
        registry.executeRecovery();
    }

    function test_RecoveryCannotExecuteWithoutInitiation() public {
        vm.prank(recovery);
        vm.expectRevert(AnchorRegistry.RecoveryNotInitiated.selector);
        registry.executeRecovery();
    }

    function test_OwnerCanCancelRecovery() public {
        vm.prank(recovery);
        registry.initiateRecovery(newOwner);

        vm.prank(owner);
        vm.expectEmit(false, false, false, false);
        emit AnchorRegistry.RecoveryCancelled();
        registry.cancelRecovery();

        assertEq(registry.pendingOwner(), address(0));
        assertEq(registry.recoveryInitiatedAt(), 0);
    }

    function test_StrangerCannotCancelRecovery() public {
        vm.prank(recovery);
        registry.initiateRecovery(newOwner);

        vm.prank(stranger);
        vm.expectRevert(AnchorRegistry.NotOwner.selector);
        registry.cancelRecovery();
    }

    function test_CancelActivates7DayLockout() public {
        vm.prank(recovery);
        registry.initiateRecovery(newOwner);

        vm.prank(owner);
        registry.cancelRecovery();

        assertGt(registry.recoveryLockoutUntil(), block.timestamp);

        vm.prank(recovery);
        vm.expectRevert(AnchorRegistry.RecoveryLockedOut.selector);
        registry.initiateRecovery(newOwner);
    }

    function test_RecoveryAllowedAfterLockoutExpires() public {
        vm.prank(recovery);
        registry.initiateRecovery(newOwner);

        vm.prank(owner);
        registry.cancelRecovery();

        vm.warp(block.timestamp + 7 days + 1);

        vm.prank(recovery);
        registry.initiateRecovery(newOwner);
        assertEq(registry.pendingOwner(), newOwner);
    }

    function test_GriefingDefence_MultipleCancel() public {
        // attacker griefs repeatedly - each cancel costs gas and resets lockout
        for (uint256 i = 0; i < 3; i++) {
            // wait for lockout to expire before each attempt
            vm.warp(block.timestamp + 7 days + 1);

            vm.prank(recovery);
            registry.initiateRecovery(newOwner);

            vm.prank(owner);
            registry.cancelRecovery();

            // immediately after cancel, recovery is locked out
            vm.prank(recovery);
            vm.expectRevert(AnchorRegistry.RecoveryLockedOut.selector);
            registry.initiateRecovery(newOwner);
        }
        // owner still owns the contract after all griefing attempts
        assertEq(registry.owner(), owner);
    }

    function test_RecoveryAddressCanRotateItself() public {
        vm.prank(recovery);
        vm.expectEmit(true, false, false, false);
        emit AnchorRegistry.RecoveryAddressUpdated(newRecovery);
        registry.setRecoveryAddress(newRecovery);

        assertEq(registry.recoveryAddress(), newRecovery);
    }

    function test_OwnerCannotRotateRecoveryAddress() public {
        vm.prank(owner);
        vm.expectRevert(AnchorRegistry.NotRecoveryAddress.selector);
        registry.setRecoveryAddress(newRecovery);
    }

    function test_RecoveryZeroPendingOwnerReverts() public {
        vm.prank(recovery);
        vm.expectRevert(AnchorRegistry.ZeroAddress.selector);
        registry.initiateRecovery(address(0));
    }

    function test_SetRecoveryAddressZeroReverts() public {
        vm.prank(recovery);
        vm.expectRevert(AnchorRegistry.ZeroAddress.selector);
        registry.setRecoveryAddress(address(0));
    }

    function test_NewOwnerAfterRecoveryCanAddOperator() public {
        vm.prank(recovery);
        registry.initiateRecovery(newOwner);
        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(recovery);
        registry.executeRecovery();

        address newOp = address(0x99);
        vm.prank(newOwner);
        registry.addOperator(newOp);
        assertTrue(registry.operators(newOp));
    }

    function test_FullRecoveryScenario_OwnerCompromised() public {
        // owner compromised: attacker tries to add themselves as operator
        address attacker = address(0xDEAD);
        vm.prank(owner);
        registry.addOperator(attacker);
        assertTrue(registry.operators(attacker));

        // recovery initiates ownership transfer to newOwner
        vm.prank(recovery);
        registry.initiateRecovery(newOwner);

        // attacker cannot stop recovery (only owner can cancel, owner is compromised)
        // but attacker can try to register garbage - we can remove them after
        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(recovery);
        registry.executeRecovery();
        assertEq(registry.owner(), newOwner);

        // new owner cleans up
        vm.prank(newOwner);
        registry.removeOperator(attacker);
        assertFalse(registry.operators(attacker));

        vm.prank(newOwner);
        registry.addOperator(operator);
        assertTrue(registry.operators(operator));
    }
}
