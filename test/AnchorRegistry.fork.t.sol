// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/AnchorRegistry.sol";

/// @title  AnchorRegistryForkTest
/// @notice Fork tests against the live Sepolia deployment at
///         0x488ab4Aa772Fca36e45e1CB7223f859d2d1CFF36.
///         Run with:  forge test --match-contract AnchorRegistryForkTest --fork-url $SEPOLIA_RPC_URL -vv

contract AnchorRegistryForkTest is Test {

    AnchorRegistry public registry = AnchorRegistry(0x488ab4Aa772Fca36e45e1CB7223f859d2d1CFF36);

    address public deployerOwner   = 0x03Cf992A6805e013030956553D06a22DE4bbC5A6;
    address public recoveryAddr    = 0x3A85B6f755aE31026e6B3B619Bec3ac94Af2970e;
    address public operatorPrimary = 0xC7a7AFde1177fbF0Bb265Ea5a616d1b8D7eD8c44;
    address public operatorBackup  = 0xC919F3096cb16Ae2840B50B1b2a211D63f613ef6;

    // =====================================================================
    // 1. DEPLOYMENT STATE VERIFICATION
    // =====================================================================

    function test_Fork_Owner() public view {
        assertEq(registry.owner(), deployerOwner);
    }

    function test_Fork_RecoveryAddress() public view {
        assertEq(registry.recoveryAddress(), recoveryAddr);
    }

    function test_Fork_OperatorPrimary_Active() public view {
        assertTrue(registry.operators(operatorPrimary));
    }

    function test_Fork_OperatorBackup_Active() public view {
        assertTrue(registry.operators(operatorBackup));
    }

    function test_Fork_Stranger_NotOperator() public view {
        assertFalse(registry.operators(address(0xDEAD)));
    }

    function test_Fork_AR_TREE_ID() public view {
        assertEq(registry.AR_TREE_ID(), "ar-operator-v1");
    }

    function test_Fork_RecoveryDelay_7Days() public view {
        assertEq(registry.RECOVERY_DELAY(), 7 days);
    }

    function test_Fork_GatedOperators_Suppressed() public view {
        assertFalse(registry.legalOperators(operatorPrimary));
        assertFalse(registry.entityOperators(operatorPrimary));
        assertFalse(registry.proofOperators(operatorPrimary));
    }

    // =====================================================================
    // 2. REGISTER CONTENT — CODE (type 0)
    // =====================================================================

    function test_Fork_RegisterCode() public {
        AnchorBase memory base = AnchorBase({
            artifactType: ArtifactType.CODE,
            manifestHash: "sha256:fork-code-001",
            parentHash:   "",
            descriptor:   "FORK-TEST-CODE-001",
            title:        "Fork Test Code",
            author:       "fork-tester",
            treeId:       "tree-fork-001"
        });
        bytes memory extra = abi.encode("abc123commit", "MIT", "Solidity", "v1.0.0", "https://github.com/test");

        vm.prank(operatorPrimary);
        registry.registerContent("AR-FORK-CODE-001", base, extra);

        assertTrue(registry.registered("AR-FORK-CODE-001"));
        assertEq(uint256(registry.anchorTypes("AR-FORK-CODE-001")), uint256(ArtifactType.CODE));
    }

    // =====================================================================
    // 3. REGISTER CONTENT — RESEARCH (type 1)
    // =====================================================================

    function test_Fork_RegisterResearch() public {
        AnchorBase memory base = AnchorBase({
            artifactType: ArtifactType.RESEARCH,
            manifestHash: "sha256:fork-research-001",
            parentHash:   "",
            descriptor:   "FORK-TEST-RESEARCH-001",
            title:        "Fork Test Paper",
            author:       "fork-tester",
            treeId:       "tree-fork-002"
        });
        bytes memory extra = abi.encode("10.1234/fork", "MIT", "Dr. Fork", "https://arxiv.org/test");

        vm.prank(operatorPrimary);
        registry.registerContent("AR-FORK-RESEARCH-001", base, extra);

        assertTrue(registry.registered("AR-FORK-RESEARCH-001"));
        assertEq(uint256(registry.anchorTypes("AR-FORK-RESEARCH-001")), uint256(ArtifactType.RESEARCH));
    }

    // =====================================================================
    // 4. REGISTER CONTENT — MODEL (type 3)
    // =====================================================================

    function test_Fork_RegisterModel() public {
        AnchorBase memory base = AnchorBase({
            artifactType: ArtifactType.MODEL,
            manifestHash: "sha256:fork-model-001",
            parentHash:   "",
            descriptor:   "FORK-TEST-MODEL-001",
            title:        "Fork Test Model",
            author:       "fork-tester",
            treeId:       "tree-fork-003"
        });
        bytes memory extra = abi.encode("v1.0", "Transformer", "7B", "CommonCrawl", "https://huggingface.co/test");

        vm.prank(operatorPrimary);
        registry.registerContent("AR-FORK-MODEL-001", base, extra);

        assertTrue(registry.registered("AR-FORK-MODEL-001"));
        assertEq(uint256(registry.anchorTypes("AR-FORK-MODEL-001")), uint256(ArtifactType.MODEL));
    }

    // =====================================================================
    // 5. REGISTER CONTENT — EVENT (type 11)
    // =====================================================================

    function test_Fork_RegisterEvent() public {
        AnchorBase memory base = AnchorBase({
            artifactType: ArtifactType.EVENT,
            manifestHash: "sha256:fork-event-001",
            parentHash:   "",
            descriptor:   "FORK-TEST-EVENT-001",
            title:        "Fork Test Conference",
            author:       "fork-tester",
            treeId:       "tree-fork-004"
        });
        bytes memory extra = abi.encode("HUMAN", "CONFERENCE", "2026-03-23", "Online", "AnchorRegistry", "https://example.com");

        vm.prank(operatorPrimary);
        registry.registerContent("AR-FORK-EVENT-001", base, extra);

        assertTrue(registry.registered("AR-FORK-EVENT-001"));
        assertEq(uint256(registry.anchorTypes("AR-FORK-EVENT-001")), uint256(ArtifactType.EVENT));
    }

    // =====================================================================
    // 6. REGISTER CONTENT — RECEIPT (type 12)
    // =====================================================================

    function test_Fork_RegisterReceipt() public {
        AnchorBase memory base = AnchorBase({
            artifactType: ArtifactType.RECEIPT,
            manifestHash: "sha256:fork-receipt-001",
            parentHash:   "",
            descriptor:   "FORK-TEST-RECEIPT-001",
            title:        "Fork Test Purchase",
            author:       "fork-tester",
            treeId:       "tree-fork-005"
        });
        bytes memory extra = abi.encode("PURCHASE", "TestMerchant", "99.99", "USD", "ORD-001", "stripe", "https://receipt.test");

        vm.prank(operatorPrimary);
        registry.registerContent("AR-FORK-RECEIPT-001", base, extra);

        assertTrue(registry.registered("AR-FORK-RECEIPT-001"));
        assertEq(uint256(registry.anchorTypes("AR-FORK-RECEIPT-001")), uint256(ArtifactType.RECEIPT));
    }

    // =====================================================================
    // 7. REGISTER CONTENT — ACCOUNT (type 20)
    // =====================================================================

    function test_Fork_RegisterAccount() public {
        AnchorBase memory base = AnchorBase({
            artifactType: ArtifactType.ACCOUNT,
            manifestHash: "sha256:fork-account-001",
            parentHash:   "",
            descriptor:   "FORK-TEST-ACCOUNT-001",
            title:        "Fork Test Account",
            author:       "fork-tester",
            treeId:       "tree-fork-006"
        });
        bytes memory extra = abi.encode(uint256(100));

        vm.prank(operatorPrimary);
        registry.registerContent("AR-FORK-ACCOUNT-001", base, extra);

        assertTrue(registry.registered("AR-FORK-ACCOUNT-001"));
        assertEq(uint256(registry.anchorTypes("AR-FORK-ACCOUNT-001")), uint256(ArtifactType.ACCOUNT));
    }

    // =====================================================================
    // 8. PARENT-CHILD LINEAGE
    // =====================================================================

    function test_Fork_ParentChild_Lineage() public {
        // Register parent
        AnchorBase memory parentBase = AnchorBase({
            artifactType: ArtifactType.CODE,
            manifestHash: "sha256:fork-parent-001",
            parentHash:   "",
            descriptor:   "FORK-PARENT-001",
            title:        "Parent Code",
            author:       "fork-tester",
            treeId:       "tree-fork-lineage"
        });
        vm.prank(operatorPrimary);
        registry.registerContent("AR-FORK-PARENT-001", parentBase, abi.encode("commit1", "MIT", "Rust", "v1.0", "https://github.com/parent"));

        // Register child pointing to parent
        AnchorBase memory childBase = AnchorBase({
            artifactType: ArtifactType.DATA,
            manifestHash: "sha256:fork-child-001",
            parentHash:   "AR-FORK-PARENT-001",
            descriptor:   "FORK-CHILD-001",
            title:        "Child Dataset",
            author:       "fork-tester",
            treeId:       "tree-fork-lineage"
        });
        vm.prank(operatorPrimary);
        registry.registerContent("AR-FORK-CHILD-001", childBase, abi.encode("v1.0", "CSV", "1000", "https://schema.test", "https://data.test"));

        assertTrue(registry.registered("AR-FORK-PARENT-001"));
        assertTrue(registry.registered("AR-FORK-CHILD-001"));
    }

    // =====================================================================
    // 9. TARGETED — RETRACTION
    // =====================================================================

    function test_Fork_Retraction() public {
        // Register target first
        AnchorBase memory targetBase = AnchorBase({
            artifactType: ArtifactType.CODE,
            manifestHash: "sha256:fork-retract-target",
            parentHash:   "",
            descriptor:   "FORK-RETRACT-TARGET",
            title:        "Code to Retract",
            author:       "fork-tester",
            treeId:       "tree-fork-retract"
        });
        vm.prank(operatorPrimary);
        registry.registerContent("AR-FORK-RETRACT-TARGET", targetBase, abi.encode("c1", "MIT", "Go", "v1.0", "https://test"));

        // Retract it
        AnchorBase memory retractBase = AnchorBase({
            artifactType: ArtifactType.RETRACTION,
            manifestHash: "sha256:fork-retraction-001",
            parentHash:   "",
            descriptor:   "FORK-RETRACTION-001",
            title:        "Retraction of target",
            author:       "fork-tester",
            treeId:       "ar-operator-v1"
        });
        vm.prank(operatorPrimary);
        registry.registerTargeted("AR-FORK-RETRACTION-001", retractBase, "AR-FORK-RETRACT-TARGET", abi.encode("Author requested removal", ""));

        assertTrue(registry.registered("AR-FORK-RETRACTION-001"));
        assertEq(uint256(registry.anchorTypes("AR-FORK-RETRACTION-001")), uint256(ArtifactType.RETRACTION));
    }

    // =====================================================================
    // 10. TARGETED — REVIEW + VOID + AFFIRMED
    // =====================================================================

    function test_Fork_ReviewVoidAffirmed_Lifecycle() public {
        // Register target
        AnchorBase memory targetBase = AnchorBase({
            artifactType: ArtifactType.CODE,
            manifestHash: "sha256:fork-review-target",
            parentHash:   "",
            descriptor:   "FORK-REVIEW-TARGET",
            title:        "Suspicious Code",
            author:       "fork-tester",
            treeId:       "tree-fork-review"
        });
        vm.prank(operatorPrimary);
        registry.registerContent("AR-FORK-REVIEW-TARGET", targetBase, abi.encode("c2", "MIT", "Python", "v0.1", "https://test"));

        // REVIEW
        AnchorBase memory reviewBase = AnchorBase({
            artifactType: ArtifactType.REVIEW,
            manifestHash: "sha256:fork-review-001",
            parentHash:   "",
            descriptor:   "FORK-REVIEW-001",
            title:        "Review of suspicious code",
            author:       "ar-operator",
            treeId:       "ar-operator-v1"
        });
        vm.prank(operatorPrimary);
        registry.registerTargeted("AR-FORK-REVIEW-001", reviewBase, "AR-FORK-REVIEW-TARGET", abi.encode("FALSE_AUTHORSHIP", "https://evidence.test"));

        // VOID
        AnchorBase memory voidBase = AnchorBase({
            artifactType: ArtifactType.VOID,
            manifestHash: "sha256:fork-void-001",
            parentHash:   "",
            descriptor:   "FORK-VOID-001",
            title:        "Void finding",
            author:       "ar-operator",
            treeId:       "ar-operator-v1"
        });
        vm.prank(operatorPrimary);
        registry.registerTargeted("AR-FORK-VOID-001", voidBase, "AR-FORK-REVIEW-TARGET", abi.encode("AR-FORK-REVIEW-001", "https://finding.test", "Confirmed false authorship"));

        // AFFIRMED
        AnchorBase memory affirmedBase = AnchorBase({
            artifactType: ArtifactType.AFFIRMED,
            manifestHash: "sha256:fork-affirmed-001",
            parentHash:   "",
            descriptor:   "FORK-AFFIRMED-001",
            title:        "Affirmed void",
            author:       "ar-operator",
            treeId:       "ar-operator-v1"
        });
        vm.prank(operatorPrimary);
        registry.registerTargeted("AR-FORK-AFFIRMED-001", affirmedBase, "AR-FORK-VOID-001", abi.encode("INVESTIGATION", "https://affirmed.test"));

        assertTrue(registry.registered("AR-FORK-REVIEW-001"));
        assertTrue(registry.registered("AR-FORK-VOID-001"));
        assertTrue(registry.registered("AR-FORK-AFFIRMED-001"));
    }

    // =====================================================================
    // 11. ACCESS CONTROL — STRANGER BLOCKED
    // =====================================================================

    function test_Fork_Stranger_Blocked() public {
        AnchorBase memory base = AnchorBase({
            artifactType: ArtifactType.CODE,
            manifestHash: "sha256:fork-stranger",
            parentHash:   "",
            descriptor:   "FORK-STRANGER",
            title:        "Unauthorized",
            author:       "stranger",
            treeId:       "tree-fork-stranger"
        });

        vm.prank(address(0xDEAD));
        vm.expectRevert(abi.encodeWithSelector(AnchorRegistry.NotOperator.selector));
        registry.registerContent("AR-FORK-STRANGER-001", base, abi.encode("c", "MIT", "JS", "v1", "https://test"));
    }

    // =====================================================================
    // 12. DUPLICATE AR-ID BLOCKED
    // =====================================================================

    function test_Fork_DuplicateArId_Blocked() public {
        AnchorBase memory base = AnchorBase({
            artifactType: ArtifactType.CODE,
            manifestHash: "sha256:fork-dup-001",
            parentHash:   "",
            descriptor:   "FORK-DUP-001",
            title:        "First registration",
            author:       "fork-tester",
            treeId:       "tree-fork-dup"
        });

        vm.prank(operatorPrimary);
        registry.registerContent("AR-FORK-DUP-001", base, abi.encode("c", "MIT", "TS", "v1", "https://test"));

        // Same arId should revert
        AnchorBase memory base2 = AnchorBase({
            artifactType: ArtifactType.CODE,
            manifestHash: "sha256:fork-dup-002",
            parentHash:   "",
            descriptor:   "FORK-DUP-002",
            title:        "Duplicate attempt",
            author:       "fork-tester",
            treeId:       "tree-fork-dup"
        });

        vm.prank(operatorPrimary);
        vm.expectRevert(abi.encodeWithSelector(AnchorRegistry.AlreadyRegistered.selector, "AR-FORK-DUP-001"));
        registry.registerContent("AR-FORK-DUP-001", base2, abi.encode("c2", "MIT", "TS", "v2", "https://test2"));
    }

    // =====================================================================
    // 13. INVALID PARENT BLOCKED
    // =====================================================================

    function test_Fork_InvalidParent_Blocked() public {
        AnchorBase memory base = AnchorBase({
            artifactType: ArtifactType.CODE,
            manifestHash: "sha256:fork-badparent",
            parentHash:   "AR-DOES-NOT-EXIST",
            descriptor:   "FORK-BADPARENT",
            title:        "Bad parent ref",
            author:       "fork-tester",
            treeId:       "tree-fork-badparent"
        });

        vm.prank(operatorPrimary);
        vm.expectRevert(abi.encodeWithSelector(AnchorRegistry.InvalidParent.selector, "AR-DOES-NOT-EXIST"));
        registry.registerContent("AR-FORK-BADPARENT-001", base, abi.encode("c", "MIT", "C", "v1", "https://test"));
    }

    // =====================================================================
    // 14. GATED TYPES — STRANGER BLOCKED
    // =====================================================================

    function test_Fork_Gated_Legal_Blocked() public {
        AnchorBase memory base = AnchorBase({
            artifactType: ArtifactType.LEGAL,
            manifestHash: "sha256:fork-legal",
            parentHash:   "",
            descriptor:   "FORK-LEGAL",
            title:        "Legal doc",
            author:       "fork-tester",
            treeId:       "tree-fork-legal"
        });

        vm.prank(operatorPrimary);
        vm.expectRevert(abi.encodeWithSelector(AnchorRegistry.NotLegalOperator.selector));
        registry.registerGated("AR-FORK-LEGAL-001", base, abi.encode("PATENT", "US", "Party A", "2026-03-23", "https://test"));
    }

    // =====================================================================
    // 15. BACKUP OPERATOR CAN REGISTER
    // =====================================================================

    function test_Fork_BackupOperator_CanRegister() public {
        AnchorBase memory base = AnchorBase({
            artifactType: ArtifactType.CODE,
            manifestHash: "sha256:fork-backup-001",
            parentHash:   "",
            descriptor:   "FORK-BACKUP-001",
            title:        "Backup Op Test",
            author:       "backup-op",
            treeId:       "tree-fork-backup"
        });

        vm.prank(operatorBackup);
        registry.registerContent("AR-FORK-BACKUP-001", base, abi.encode("c", "Apache-2.0", "Rust", "v1", "https://test"));

        assertTrue(registry.registered("AR-FORK-BACKUP-001"));
    }

    // =====================================================================
    // 16. ANCHOR DATA RETRIEVAL
    // =====================================================================

    function test_Fork_GetAnchorData() public {
        AnchorBase memory base = AnchorBase({
            artifactType: ArtifactType.NOTE,
            manifestHash: "sha256:fork-note-001",
            parentHash:   "",
            descriptor:   "FORK-NOTE-001",
            title:        "Test Note",
            author:       "fork-tester",
            treeId:       "tree-fork-note"
        });
        bytes memory extra = abi.encode("MEMO", "2026-03-23", "Ian Moore", "https://notes.test");

        vm.prank(operatorPrimary);
        registry.registerContent("AR-FORK-NOTE-001", base, extra);

        bytes memory stored = registry.getAnchorData("AR-FORK-NOTE-001");
        (string memory noteType, string memory date, string memory participants, string memory url) =
            abi.decode(stored, (string, string, string, string));

        assertEq(noteType, "MEMO");
        assertEq(date, "2026-03-23");
        assertEq(participants, "Ian Moore");
        assertEq(url, "https://notes.test");
    }

    // =====================================================================
    // 17. ACCOUNT CAPACITY MINIMUM ENFORCED
    // =====================================================================

    function test_Fork_Account_BelowMinimum_Reverts() public {
        AnchorBase memory base = AnchorBase({
            artifactType: ArtifactType.ACCOUNT,
            manifestHash: "sha256:fork-account-low",
            parentHash:   "",
            descriptor:   "FORK-ACCOUNT-LOW",
            title:        "Low Capacity",
            author:       "fork-tester",
            treeId:       "tree-fork-account-low"
        });

        vm.prank(operatorPrimary);
        vm.expectRevert(abi.encodeWithSelector(AnchorRegistry.InsufficientCapacity.selector));
        registry.registerContent("AR-FORK-ACCOUNT-LOW", base, abi.encode(uint256(5)));
    }
}
