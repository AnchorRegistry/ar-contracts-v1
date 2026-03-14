// SPDX-License-Identifier: BUSL-1.1
// Change Date:    March 12, 2028
// Change License: Apache-2.0
// Licensor:       Ian Moore (icmoore)

pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/AnchorRegistry.sol";

/// @title  AnchorRegistryTest
/// @notice Full Foundry test suite for AnchorRegistry.sol (final — 15 artifact types).
///
///         Test sections:
///         1.  Content register functions (types 0-7)
///         2.  Gated register functions (types 8-9, suppressed at launch)
///         3.  Self-service register function (type 10 — RETRACTION)
///         4.  Dispute register functions (types 11-13 — DISPUTE, VOID, AFFIRMED)
///         5.  Catch-all register function (type 14 — OTHER)
///         6.  Access control — standard operators
///         7.  Access control — legal operators (gated)
///         8.  Access control — entity operators (gated)
///         9.  Edge cases — validation errors
///         10. Tree integrity — parentHash validation
///         11. Events
///         12. Recovery flow & griefing defence

contract AnchorRegistryTest is Test {

    AnchorRegistry public registry;

    // ── Actors ────────────────────────────────────────────────────────────────
    address public owner         = address(0x1);
    address public operator      = address(0x2);
    address public opBackup      = address(0x3);
    address public recovery      = address(0x4);
    address public stranger      = address(0x5);
    address public newOwner      = address(0x6);
    address public newRecovery   = address(0x7);
    address public legalOp       = address(0x8);
    address public entityOp      = address(0x9);

    // ── Shared base fixture ───────────────────────────────────────────────────
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

        // legalOp and entityOp are NOT added at deployment
        // tests that require them add them explicitly
    }

    // =========================================================================
    // HELPERS
    // =========================================================================

    function _base(
        AnchorRegistry.ArtifactType artifactType,
        string memory manifestHash,
        string memory descriptor
    ) internal pure returns (AnchorRegistry.AnchorBase memory) {
        return AnchorRegistry.AnchorBase({
            artifactType: artifactType,
            manifestHash: manifestHash,
            parentHash:   "",
            descriptor:   descriptor
        });
    }

    function _baseCode(string memory manifestHash)
        internal pure returns (AnchorRegistry.AnchorBase memory)
    {
        return _base(AnchorRegistry.ArtifactType.CODE, manifestHash, "TEST");
    }

    function _baseWithParent(
        string memory manifestHash,
        string memory parentHash
    ) internal pure returns (AnchorRegistry.AnchorBase memory) {
        return AnchorRegistry.AnchorBase({
            artifactType: AnchorRegistry.ArtifactType.CODE,
            manifestHash: manifestHash,
            parentHash:   parentHash,
            descriptor:   "TEST-CHILD"
        });
    }

    function _registerCode(string memory arId, string memory manifestHash) internal {
        vm.prank(operator);
        registry.registerCode(arId, _baseCode(manifestHash), "git:abc", "Apache-2.0", "https://github.com/test");
    }

    function _registerAndGetDispute(
        string memory targetArId,
        string memory disputeArId
    ) internal {
        // Register a target anchor and attach a DISPUTE to it
        _registerCode(targetArId, string(abi.encodePacked("sha256:", targetArId)));

        AnchorRegistry.AnchorBase memory db = _base(
            AnchorRegistry.ArtifactType.DISPUTE,
            string(abi.encodePacked("sha256:dispute-", disputeArId)),
            string(abi.encodePacked("DISPUTE-", disputeArId))
        );
        db.parentHash = targetArId;

        vm.prank(operator);
        registry.registerDispute(
            disputeArId, db, targetArId,
            "FALSE_AUTHORSHIP",
            "https://anchorregistry.com/disputes/test"
        );
    }

    // =========================================================================
    // 1. CONTENT REGISTER FUNCTIONS (types 0-7)
    // =========================================================================

    function test_RegisterCode() public {
        vm.prank(operator);
        vm.expectEmit(true, true, false, true);
        emit AnchorRegistry.Anchored(
            "AR-2026-CODE01", operator,
            AnchorRegistry.ArtifactType.CODE,
            "ICMOORE-2026-TEST", "sha256:abc123", ""
        );
        registry.registerCode("AR-2026-CODE01", base, "gitabc123", "Apache-2.0", "https://github.com/test");
        assertTrue(registry.registered("AR-2026-CODE01"));
    }

    function test_RegisterResearch() public {
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.RESEARCH, "sha256:research01", "PAPER-2026"
        );
        vm.prank(operator);
        registry.registerResearch("AR-2026-RES01", b, "10.1000/xyz123", "https://arxiv.org/abs/test");
        assertTrue(registry.registered("AR-2026-RES01"));
    }

    function test_RegisterData() public {
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.DATA, "sha256:data01", "DATASET-2026"
        );
        vm.prank(operator);
        registry.registerData("AR-2026-DATA01", b, "v1.0.0", "https://huggingface.co/datasets/test");
        assertTrue(registry.registered("AR-2026-DATA01"));
    }

    function test_RegisterModel() public {
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.MODEL, "sha256:model01", "MODEL-2026"
        );
        vm.prank(operator);
        registry.registerModel("AR-2026-MDL01", b, "v1.0.0", "https://huggingface.co/test");
        assertTrue(registry.registered("AR-2026-MDL01"));
    }

    function test_RegisterAgent() public {
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.AGENT, "sha256:agent01", "AGENT-2026"
        );
        vm.prank(operator);
        registry.registerAgent("AR-2026-AGT01", b, "v0.1.0", "https://github.com/test-agent");
        assertTrue(registry.registered("AR-2026-AGT01"));
    }

    function test_RegisterMedia() public {
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.MEDIA, "sha256:media01", "MEDIA-2026"
        );
        vm.prank(operator);
        registry.registerMedia("AR-2026-MED01", b, "image/png", "https://ipfs.io/ipfs/test");
        assertTrue(registry.registered("AR-2026-MED01"));
    }

    function test_RegisterText() public {
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.TEXT, "sha256:text01", "ARTICLE-2026"
        );
        vm.prank(operator);
        registry.registerText("AR-2026-TXT01", b, "https://medium.com/@test");
        assertTrue(registry.registered("AR-2026-TXT01"));
    }

    function test_RegisterPost() public {
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.POST, "sha256:post01", "POST-2026"
        );
        vm.prank(operator);
        registry.registerPost("AR-2026-PST01", b, "X/Twitter", "https://x.com/anchorregistry/status/1");
        assertTrue(registry.registered("AR-2026-PST01"));
    }

    function test_RegisterOther() public {
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.OTHER, "sha256:other01", "OTHER-2026"
        );
        vm.prank(operator);
        registry.registerOther("AR-2026-OTH01", b, "course", "Thinkific", "https://thinkific.com/test", "DeFi 101");
        assertTrue(registry.registered("AR-2026-OTH01"));
    }

    function test_BackupOperatorCanRegisterAllContentTypes() public {
        vm.prank(opBackup);
        registry.registerCode("AR-2026-BACK01", base, "gitbackup", "MIT", "https://github.com/backup");
        assertTrue(registry.registered("AR-2026-BACK01"));
    }

    // =========================================================================
    // 2. GATED REGISTER FUNCTIONS (types 8-9, suppressed at launch)
    // =========================================================================

    // ── LEGAL (type 8) ────────────────────────────────────────────────────────

    function test_RegisterLegal_ByLegalOperator_Succeeds() public {
        vm.prank(owner);
        registry.addLegalOperator(legalOp);

        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.LEGAL, "sha256:legal01", "TRADEMARK-2026"
        );
        vm.prank(legalOp);
        registry.registerLegal("AR-2026-LGL01", b, "TRADEMARK", "https://cipo.ic.gc.ca/test");
        assertTrue(registry.registered("AR-2026-LGL01"));
    }

    function test_RegisterLegal_ByStandardOperator_Reverts() public {
        // Standard operator cannot call registerLegal even though they can call everything else
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.LEGAL, "sha256:legal02", "TRADEMARK-2026"
        );
        vm.prank(operator);
        vm.expectRevert(AnchorRegistry.NotLegalOperator.selector);
        registry.registerLegal("AR-2026-LGL02", b, "TRADEMARK", "https://cipo.ic.gc.ca/test");
    }

    function test_RegisterLegal_ByOwner_Reverts() public {
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.LEGAL, "sha256:legal03", "TRADEMARK-2026"
        );
        vm.prank(owner);
        vm.expectRevert(AnchorRegistry.NotLegalOperator.selector);
        registry.registerLegal("AR-2026-LGL03", b, "TRADEMARK", "https://cipo.ic.gc.ca/test");
    }

    function test_RegisterLegal_ByStranger_Reverts() public {
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.LEGAL, "sha256:legal04", "TRADEMARK-2026"
        );
        vm.prank(stranger);
        vm.expectRevert(AnchorRegistry.NotLegalOperator.selector);
        registry.registerLegal("AR-2026-LGL04", b, "TRADEMARK", "https://cipo.ic.gc.ca/test");
    }

    function test_RegisterLegal_SuppressedAtLaunch_NoOperatorsAdded() public {
        // Confirm no legal operators exist at deployment
        assertFalse(registry.legalOperators(legalOp));
        assertFalse(registry.legalOperators(operator));
        assertFalse(registry.legalOperators(owner));
    }

    function test_RemoveLegalOperator_CanNoLongerRegister() public {
        vm.prank(owner);
        registry.addLegalOperator(legalOp);
        assertTrue(registry.legalOperators(legalOp));

        vm.prank(owner);
        registry.removeLegalOperator(legalOp);
        assertFalse(registry.legalOperators(legalOp));

        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.LEGAL, "sha256:legal05", "TRADEMARK-2026"
        );
        vm.prank(legalOp);
        vm.expectRevert(AnchorRegistry.NotLegalOperator.selector);
        registry.registerLegal("AR-2026-LGL05", b, "TRADEMARK", "https://cipo.ic.gc.ca/test");
    }

    // ── ENTITY (type 9) ───────────────────────────────────────────────────────

    function test_RegisterEntity_ByEntityOperator_Succeeds() public {
        vm.prank(owner);
        registry.addEntityOperator(entityOp);

        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.ENTITY, "sha256:entity01", "ICMOORE-ENTITY-2026"
        );
        vm.prank(entityOp);
        registry.registerEntity(
            "AR-2026-ENT01", b,
            "PERSON", "icmoore.com", "DNS_TXT",
            "anchorregistry-verify=abc123",
            "https://anchorregistry.ai/canonical/AR-2026-ENT01",
            "sha256:canonicaldoc01"
        );
        assertTrue(registry.registered("AR-2026-ENT01"));
    }

    function test_RegisterEntity_ByStandardOperator_Reverts() public {
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.ENTITY, "sha256:entity02", "ICMOORE-ENTITY-2026"
        );
        vm.prank(operator);
        vm.expectRevert(AnchorRegistry.NotEntityOperator.selector);
        registry.registerEntity(
            "AR-2026-ENT02", b,
            "PERSON", "icmoore.com", "DNS_TXT",
            "anchorregistry-verify=abc123",
            "https://anchorregistry.ai/canonical/AR-2026-ENT02",
            "sha256:canonicaldoc02"
        );
    }

    function test_RegisterEntity_ByLegalOperator_Reverts() public {
        vm.prank(owner);
        registry.addLegalOperator(legalOp);

        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.ENTITY, "sha256:entity03", "ICMOORE-ENTITY-2026"
        );
        vm.prank(legalOp);
        vm.expectRevert(AnchorRegistry.NotEntityOperator.selector);
        registry.registerEntity(
            "AR-2026-ENT03", b,
            "PERSON", "icmoore.com", "DNS_TXT",
            "anchorregistry-verify=abc123",
            "", ""
        );
    }

    function test_RegisterEntity_SuppressedAtLaunch_NoOperatorsAdded() public {
        assertFalse(registry.entityOperators(entityOp));
        assertFalse(registry.entityOperators(operator));
        assertFalse(registry.entityOperators(owner));
    }

    function test_RemoveEntityOperator_CanNoLongerRegister() public {
        vm.prank(owner);
        registry.addEntityOperator(entityOp);

        vm.prank(owner);
        registry.removeEntityOperator(entityOp);
        assertFalse(registry.entityOperators(entityOp));

        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.ENTITY, "sha256:entity04", "ENTITY-2026"
        );
        vm.prank(entityOp);
        vm.expectRevert(AnchorRegistry.NotEntityOperator.selector);
        registry.registerEntity("AR-2026-ENT04", b, "PERSON", "icmoore.com", "DNS_TXT", "proof", "", "");
    }

    function test_LegalAndEntityOperatorsAreIndependent() public {
        // Adding a legal operator does not grant entity operator rights
        vm.prank(owner);
        registry.addLegalOperator(legalOp);
        assertFalse(registry.entityOperators(legalOp));

        // Adding an entity operator does not grant legal operator rights
        vm.prank(owner);
        registry.addEntityOperator(entityOp);
        assertFalse(registry.legalOperators(entityOp));
    }

    // =========================================================================
    // 3. SELF-SERVICE REGISTER FUNCTION (type 10 — RETRACTION)
    // =========================================================================

    function test_RegisterRetraction_Succeeds() public {
        _registerCode("AR-2026-TARGET01", "sha256:target01");

        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.RETRACTION,
            "sha256:retraction01",
            "RETRACTION-AR-2026-TARGET01"
        );
        b.parentHash = "AR-2026-TARGET01";

        vm.prank(operator);
        registry.registerRetraction(
            "AR-2026-RET01", b,
            "AR-2026-TARGET01",
            "Registered wrong file hash",
            ""
        );
        assertTrue(registry.registered("AR-2026-RET01"));
    }

    function test_RegisterRetraction_WithReplacement() public {
        _registerCode("AR-2026-V1", "sha256:v1");
        _registerCode("AR-2026-V2", "sha256:v2");

        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.RETRACTION,
            "sha256:retraction02",
            "RETRACTION-AR-2026-V1"
        );
        b.parentHash = "AR-2026-V1";

        vm.prank(operator);
        vm.expectEmit(true, true, false, true);
        emit AnchorRegistry.Retracted("AR-2026-RET02", "AR-2026-V1", "AR-2026-V2");
        registry.registerRetraction(
            "AR-2026-RET02", b,
            "AR-2026-V1",
            "Superseded by v2.0",
            "AR-2026-V2"
        );
        assertTrue(registry.registered("AR-2026-RET02"));

        // Verify replacedBy is stored
        AnchorRegistry.RetractionAnchor memory ret = registry.retractionAnchors("AR-2026-RET02");
        assertEq(ret.replacedBy, "AR-2026-V2");
        assertEq(ret.targetArId, "AR-2026-V1");
    }

    function test_RegisterRetraction_WithEmptyReason_Succeeds() public {
        _registerCode("AR-2026-TARGET02", "sha256:target02");

        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.RETRACTION,
            "sha256:retraction03",
            "RETRACTION-AR-2026-TARGET02"
        );
        b.parentHash = "AR-2026-TARGET02";

        vm.prank(operator);
        registry.registerRetraction("AR-2026-RET03", b, "AR-2026-TARGET02", "", "");
        assertTrue(registry.registered("AR-2026-RET03"));
    }

    function test_RegisterRetraction_NonExistentTarget_Reverts() public {
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.RETRACTION,
            "sha256:retraction04",
            "RETRACTION-MISSING"
        );
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(AnchorRegistry.InvalidTarget.selector, "AR-2026-DOESNOTEXIST"));
        registry.registerRetraction("AR-2026-RET04", b, "AR-2026-DOESNOTEXIST", "", "");
    }

    function test_RegisterRetraction_EmptyTarget_Reverts() public {
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.RETRACTION,
            "sha256:retraction05",
            "RETRACTION-EMPTY"
        );
        vm.prank(operator);
        vm.expectRevert(AnchorRegistry.EmptyTargetArId.selector);
        registry.registerRetraction("AR-2026-RET05", b, "", "", "");
    }

    function test_RegisterRetraction_ByStranger_Reverts() public {
        _registerCode("AR-2026-TARGET03", "sha256:target03");

        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.RETRACTION,
            "sha256:retraction06",
            "RETRACTION-AR-2026-TARGET03"
        );
        vm.prank(stranger);
        vm.expectRevert(AnchorRegistry.NotOperator.selector);
        registry.registerRetraction("AR-2026-RET06", b, "AR-2026-TARGET03", "", "");
    }

    function test_CanRetractARetraction() public {
        // A retraction can itself be retracted (e.g. retraction was filed by mistake)
        _registerCode("AR-2026-ORIG01", "sha256:orig01");

        AnchorRegistry.AnchorBase memory rb = _base(
            AnchorRegistry.ArtifactType.RETRACTION,
            "sha256:ret01",
            "RETRACTION-ORIG01"
        );
        rb.parentHash = "AR-2026-ORIG01";
        vm.prank(operator);
        registry.registerRetraction("AR-2026-RET-ORIG01", rb, "AR-2026-ORIG01", "mistake", "");

        // Now retract the retraction
        AnchorRegistry.AnchorBase memory rrb = _base(
            AnchorRegistry.ArtifactType.RETRACTION,
            "sha256:retret01",
            "RETRACTION-OF-RETRACTION"
        );
        rrb.parentHash = "AR-2026-RET-ORIG01";
        vm.prank(operator);
        registry.registerRetraction("AR-2026-RETRET01", rrb, "AR-2026-RET-ORIG01", "filed in error", "");
        assertTrue(registry.registered("AR-2026-RETRET01"));
    }

    function test_NodeSwap_RetractWithReplacedBy_SubtreePointerPreserved() public {
        // ── The node swap pattern ──────────────────────────────────────────────
        // Creator wants to retract an intermediate node but keep its children.
        // Solution: register a replacement node, retract original with
        // replacedBy pointing to replacement. The resolution layer (off-chain)
        // interprets children as logically belonging to the replacement.
        // The contract's job: record the intent permanently. It does.

        // Register root
        _registerCode("AR-2026-SWAP-ROOT", "sha256:swaproot");

        // Register NODE-V1 as child of ROOT
        AnchorRegistry.AnchorBase memory v1Base = _baseWithParent(
            "sha256:swapv1", "AR-2026-SWAP-ROOT"
        );
        vm.prank(operator);
        registry.registerCode("AR-2026-SWAP-V1", v1Base, "git:v1", "MIT", "https://test");

        // Register CHILD-1 under NODE-V1
        AnchorRegistry.AnchorBase memory child1Base = _baseWithParent(
            "sha256:swapchild1", "AR-2026-SWAP-V1"
        );
        vm.prank(operator);
        registry.registerCode("AR-2026-SWAP-CHILD1", child1Base, "git:child1", "MIT", "https://test");

        // Register CHILD-2 under NODE-V1
        AnchorRegistry.AnchorBase memory child2Base = _baseWithParent(
            "sha256:swapchild2", "AR-2026-SWAP-V1"
        );
        vm.prank(operator);
        registry.registerCode("AR-2026-SWAP-CHILD2", child2Base, "git:child2", "MIT", "https://test");

        // Register GRANDCHILD under CHILD-2
        AnchorRegistry.AnchorBase memory gcBase = _baseWithParent(
            "sha256:swapgc", "AR-2026-SWAP-CHILD2"
        );
        vm.prank(operator);
        registry.registerCode("AR-2026-SWAP-GC", gcBase, "git:gc", "MIT", "https://test");

        // Register NODE-V2 as sibling of V1 (same parent: ROOT)
        AnchorRegistry.AnchorBase memory v2Base = _baseWithParent(
            "sha256:swapv2", "AR-2026-SWAP-ROOT"
        );
        vm.prank(operator);
        registry.registerCode("AR-2026-SWAP-V2", v2Base, "git:v2", "MIT", "https://test");

        // Retract V1 with replacedBy = V2
        AnchorRegistry.AnchorBase memory retBase = _base(
            AnchorRegistry.ArtifactType.RETRACTION,
            "sha256:swapret",
            "RETRACTION-SWAP-V1"
        );
        retBase.parentHash = "AR-2026-SWAP-V1";

        vm.prank(operator);
        vm.expectEmit(true, true, false, true);
        emit AnchorRegistry.Retracted("AR-2026-SWAP-RET", "AR-2026-SWAP-V1", "AR-2026-SWAP-V2");
        registry.registerRetraction(
            "AR-2026-SWAP-RET", retBase,
            "AR-2026-SWAP-V1",
            "Superseded by V2 — children migrate to V2",
            "AR-2026-SWAP-V2"
        );

        // ── On-chain assertions ───────────────────────────────────────────────

        // V1 is retracted
        assertTrue(registry.registered("AR-2026-SWAP-RET"));

        // replacedBy pointer stored correctly
        AnchorRegistry.RetractionAnchor memory ret =
            registry.retractionAnchors("AR-2026-SWAP-RET");
        assertEq(ret.targetArId, "AR-2026-SWAP-V1");
        assertEq(ret.replacedBy, "AR-2026-SWAP-V2");
        assertEq(ret.reason,     "Superseded by V2 — children migrate to V2");

        // V2 exists as the replacement
        assertTrue(registry.registered("AR-2026-SWAP-V2"));

        // Children still exist — parentHash is immutable, they still point to V1
        // The resolution layer (FastAPI) follows replacedBy to logically
        // reattach them to V2. The contract records the intent; it does not
        // need to know about the logical reattachment.
        assertTrue(registry.registered("AR-2026-SWAP-CHILD1"));
        assertTrue(registry.registered("AR-2026-SWAP-CHILD2"));
        assertTrue(registry.registered("AR-2026-SWAP-GC"));

        // Children's parentHash is still V1 on-chain (immutable)
        // This is correct — the resolution layer handles logical migration
        AnchorRegistry.CodeAnchor memory child1 =
            registry.codeAnchors("AR-2026-SWAP-CHILD1");
        assertEq(child1.base.parentHash, "AR-2026-SWAP-V1");
    }

    function test_NodeSwap_RetractWithoutReplacedBy_ChildrenOrphaned() public {
        // When no replacedBy is provided, children remain linked to the
        // retracted node on-chain. The resolution layer marks them ORPHANED.
        // This is a valid creator choice — not an error.

        _registerCode("AR-2026-ORPHAN-ROOT", "sha256:orphanroot");

        AnchorRegistry.AnchorBase memory nodeBase = _baseWithParent(
            "sha256:orphannode", "AR-2026-ORPHAN-ROOT"
        );
        vm.prank(operator);
        registry.registerCode("AR-2026-ORPHAN-NODE", nodeBase, "git:node", "MIT", "https://test");

        AnchorRegistry.AnchorBase memory childBase = _baseWithParent(
            "sha256:orphanchild", "AR-2026-ORPHAN-NODE"
        );
        vm.prank(operator);
        registry.registerCode("AR-2026-ORPHAN-CHILD", childBase, "git:child", "MIT", "https://test");

        // Retract node with NO replacedBy
        AnchorRegistry.AnchorBase memory retBase = _base(
            AnchorRegistry.ArtifactType.RETRACTION,
            "sha256:orphanret",
            "RETRACTION-ORPHAN-NODE"
        );
        retBase.parentHash = "AR-2026-ORPHAN-NODE";

        vm.prank(operator);
        vm.expectEmit(true, true, false, true);
        emit AnchorRegistry.Retracted("AR-2026-ORPHAN-RET", "AR-2026-ORPHAN-NODE", "");
        registry.registerRetraction(
            "AR-2026-ORPHAN-RET", retBase,
            "AR-2026-ORPHAN-NODE",
            "No longer relevant",
            ""   // ← no replacedBy
        );

        // Retraction recorded
        assertTrue(registry.registered("AR-2026-ORPHAN-RET"));

        AnchorRegistry.RetractionAnchor memory ret =
            registry.retractionAnchors("AR-2026-ORPHAN-RET");
        assertEq(ret.replacedBy, "");   // empty — children will be ORPHANED

        // Child still exists on-chain — permanently
        assertTrue(registry.registered("AR-2026-ORPHAN-CHILD"));

        // Child's parentHash still points to retracted node (immutable)
        // Resolution layer marks it ORPHANED — handled off-chain
        AnchorRegistry.CodeAnchor memory child =
            registry.codeAnchors("AR-2026-ORPHAN-CHILD");
        assertEq(child.base.parentHash, "AR-2026-ORPHAN-NODE");
    }

    // =========================================================================
    // 4. DISPUTE REGISTER FUNCTIONS (types 11-13)
    // =========================================================================

    // ── DISPUTE (type 11) ─────────────────────────────────────────────────────

    function test_RegisterDispute_Succeeds() public {
        _registerCode("AR-2026-DTARGET01", "sha256:dtarget01");

        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.DISPUTE,
            "sha256:dispute01",
            "DISPUTE-AR-2026-DTARGET01"
        );
        b.parentHash = "AR-2026-DTARGET01";

        vm.prank(operator);
        vm.expectEmit(true, true, false, true);
        emit AnchorRegistry.Disputed(
            "AR-2026-DIS01", "AR-2026-DTARGET01",
            "FALSE_AUTHORSHIP",
            "https://anchorregistry.com/disputes/AR-2026-DIS01"
        );
        registry.registerDispute(
            "AR-2026-DIS01", b,
            "AR-2026-DTARGET01",
            "FALSE_AUTHORSHIP",
            "https://anchorregistry.com/disputes/AR-2026-DIS01"
        );
        assertTrue(registry.registered("AR-2026-DIS01"));
    }

    function test_RegisterDispute_NonExistentTarget_Reverts() public {
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.DISPUTE,
            "sha256:dispute02",
            "DISPUTE-MISSING"
        );
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(AnchorRegistry.InvalidTarget.selector, "AR-2026-DOESNOTEXIST"));
        registry.registerDispute("AR-2026-DIS02", b, "AR-2026-DOESNOTEXIST", "IMPERSONATION", "https://test");
    }

    function test_RegisterDispute_EmptyTarget_Reverts() public {
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.DISPUTE,
            "sha256:dispute03",
            "DISPUTE-EMPTY"
        );
        vm.prank(operator);
        vm.expectRevert(AnchorRegistry.EmptyTargetArId.selector);
        registry.registerDispute("AR-2026-DIS03", b, "", "OTHER", "https://test");
    }

    function test_RegisterDispute_ByStranger_Reverts() public {
        _registerCode("AR-2026-DTARGET02", "sha256:dtarget02");

        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.DISPUTE,
            "sha256:dispute04",
            "DISPUTE-TARGET02"
        );
        vm.prank(stranger);
        vm.expectRevert(AnchorRegistry.NotOperator.selector);
        registry.registerDispute("AR-2026-DIS04", b, "AR-2026-DTARGET02", "OTHER", "https://test");
    }

    function test_RegisterDispute_AllReasonTypes() public {
        string[5] memory reasons = [
            "MALICIOUS_TREE",
            "IMPERSONATION",
            "FALSE_AUTHORSHIP",
            "DEFAMATORY",
            "OTHER"
        ];
        for (uint256 i = 0; i < reasons.length; i++) {
            string memory targetId = string(abi.encodePacked("AR-2026-DRSN-TARGET-", vm.toString(i)));
            string memory disputeId = string(abi.encodePacked("AR-2026-DRSN-DIS-", vm.toString(i)));
            _registerCode(targetId, string(abi.encodePacked("sha256:drsntarget", vm.toString(i))));

            AnchorRegistry.AnchorBase memory b = _base(
                AnchorRegistry.ArtifactType.DISPUTE,
                string(abi.encodePacked("sha256:drsndisp", vm.toString(i))),
                string(abi.encodePacked("DISPUTE-", vm.toString(i)))
            );
            b.parentHash = targetId;

            vm.prank(operator);
            registry.registerDispute(disputeId, b, targetId, reasons[i], "https://test");
            assertTrue(registry.registered(disputeId));
        }
    }

    // ── VOID (type 12) ────────────────────────────────────────────────────────

    function test_RegisterVoid_Succeeds() public {
        _registerAndGetDispute("AR-2026-VTARGET01", "AR-2026-DIS-V01");

        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.VOID,
            "sha256:void01",
            "VOID-AR-2026-VTARGET01"
        );
        b.parentHash = "AR-2026-DIS-V01";

        vm.prank(operator);
        vm.expectEmit(true, true, true, true);
        emit AnchorRegistry.Voided(
            "AR-2026-VOID01", "AR-2026-VTARGET01",
            "AR-2026-DIS-V01",
            "Impersonating OpenAI"
        );
        registry.registerVoid(
            "AR-2026-VOID01", b,
            "AR-2026-VTARGET01",
            "AR-2026-DIS-V01",
            "https://anchorregistry.com/disputes/AR-2026-VOID01",
            "Impersonating OpenAI"
        );
        assertTrue(registry.registered("AR-2026-VOID01"));
    }

    function test_RegisterVoid_NonExistentTarget_Reverts() public {
        _registerCode("AR-2026-VTARGET02", "sha256:vtarget02");

        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.VOID, "sha256:void02", "VOID-MISSING"
        );
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(AnchorRegistry.InvalidTarget.selector, "AR-DOESNOTEXIST"));
        registry.registerVoid("AR-2026-VOID02", b, "AR-DOESNOTEXIST", "AR-2026-VTARGET02", "https://test", "evidence");
    }

    function test_RegisterVoid_NonExistentDisputeArId_Reverts() public {
        _registerCode("AR-2026-VTARGET03", "sha256:vtarget03");

        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.VOID, "sha256:void03", "VOID-NODISPUTE"
        );
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(AnchorRegistry.InvalidTarget.selector, "AR-NODISPUTE"));
        registry.registerVoid("AR-2026-VOID03", b, "AR-2026-VTARGET03", "AR-NODISPUTE", "https://test", "evidence");
    }

    function test_RegisterVoid_EmptyTarget_Reverts() public {
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.VOID, "sha256:void04", "VOID-EMPTY"
        );
        vm.prank(operator);
        vm.expectRevert(AnchorRegistry.EmptyTargetArId.selector);
        registry.registerVoid("AR-2026-VOID04", b, "", "AR-2026-SOMEDISPUTE", "https://test", "evidence");
    }

    function test_RegisterVoid_ByStranger_Reverts() public {
        _registerAndGetDispute("AR-2026-VTARGET04", "AR-2026-DIS-V04");

        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.VOID, "sha256:void05", "VOID-STRANGER"
        );
        vm.prank(stranger);
        vm.expectRevert(AnchorRegistry.NotOperator.selector);
        registry.registerVoid("AR-2026-VOID05", b, "AR-2026-VTARGET04", "AR-2026-DIS-V04", "https://test", "evidence");
    }

    function test_RegisterVoid_StoredCorrectly() public {
        _registerAndGetDispute("AR-2026-VTARGET05", "AR-2026-DIS-V05");

        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.VOID, "sha256:void06", "VOID-CHECK"
        );
        vm.prank(operator);
        registry.registerVoid(
            "AR-2026-VOID06", b,
            "AR-2026-VTARGET05", "AR-2026-DIS-V05",
            "https://anchorregistry.com/disputes/VOID06",
            "False authorship confirmed"
        );

        AnchorRegistry.VoidAnchor memory v = registry.voidAnchors("AR-2026-VOID06");
        assertEq(v.targetArId,  "AR-2026-VTARGET05");
        assertEq(v.disputeArId, "AR-2026-DIS-V05");
        assertEq(v.evidence,    "False authorship confirmed");
    }

    // ── AFFIRMED (type 13) ────────────────────────────────────────────────────

    function test_RegisterAffirmed_OnDispute_Succeeds() public {
        _registerAndGetDispute("AR-2026-ATARGET01", "AR-2026-DIS-A01");

        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.AFFIRMED,
            "sha256:affirmed01",
            "AFFIRMED-AR-2026-DIS-A01"
        );
        b.parentHash = "AR-2026-DIS-A01";

        vm.prank(operator);
        vm.expectEmit(true, true, false, true);
        emit AnchorRegistry.Affirmed("AR-2026-AFF01", "AR-2026-DIS-A01", "INVESTIGATION");
        registry.registerAffirmed(
            "AR-2026-AFF01", b,
            "AR-2026-DIS-A01",
            "INVESTIGATION",
            "https://anchorregistry.com/disputes/AR-2026-AFF01"
        );
        assertTrue(registry.registered("AR-2026-AFF01"));
    }

    function test_RegisterAffirmed_OnVoid_AppealUpheld_Succeeds() public {
        _registerAndGetDispute("AR-2026-ATARGET02", "AR-2026-DIS-A02");

        // Register VOID first
        AnchorRegistry.AnchorBase memory vb = _base(
            AnchorRegistry.ArtifactType.VOID, "sha256:void-a02", "VOID-A02"
        );
        vb.parentHash = "AR-2026-DIS-A02";
        vm.prank(operator);
        registry.registerVoid(
            "AR-2026-VOID-A02", vb,
            "AR-2026-ATARGET02", "AR-2026-DIS-A02",
            "https://test", "evidence"
        );

        // Appeal upheld — register AFFIRMED on the VOID
        AnchorRegistry.AnchorBase memory ab = _base(
            AnchorRegistry.ArtifactType.AFFIRMED,
            "sha256:affirmed02",
            "AFFIRMED-VOID-A02"
        );
        ab.parentHash = "AR-2026-VOID-A02";

        vm.prank(operator);
        vm.expectEmit(true, true, false, true);
        emit AnchorRegistry.Affirmed("AR-2026-AFF02", "AR-2026-VOID-A02", "APPEAL");
        registry.registerAffirmed(
            "AR-2026-AFF02", ab,
            "AR-2026-VOID-A02",
            "APPEAL",
            "https://anchorregistry.com/disputes/AR-2026-AFF02"
        );
        assertTrue(registry.registered("AR-2026-AFF02"));

        AnchorRegistry.AffirmedAnchor memory aff = registry.affirmedAnchors("AR-2026-AFF02");
        assertEq(aff.targetArId, "AR-2026-VOID-A02");
        assertEq(aff.affirmedBy, "APPEAL");
    }

    function test_RegisterAffirmed_NonExistentTarget_Reverts() public {
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.AFFIRMED, "sha256:affirmed03", "AFFIRMED-MISSING"
        );
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(AnchorRegistry.InvalidTarget.selector, "AR-NODISPUTE"));
        registry.registerAffirmed("AR-2026-AFF03", b, "AR-NODISPUTE", "INVESTIGATION", "https://test");
    }

    function test_RegisterAffirmed_EmptyTarget_Reverts() public {
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.AFFIRMED, "sha256:affirmed04", "AFFIRMED-EMPTY"
        );
        vm.prank(operator);
        vm.expectRevert(AnchorRegistry.EmptyTargetArId.selector);
        registry.registerAffirmed("AR-2026-AFF04", b, "", "INVESTIGATION", "https://test");
    }

    function test_RegisterAffirmed_ByStranger_Reverts() public {
        _registerAndGetDispute("AR-2026-ATARGET03", "AR-2026-DIS-A03");

        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.AFFIRMED, "sha256:affirmed05", "AFFIRMED-STRANGER"
        );
        vm.prank(stranger);
        vm.expectRevert(AnchorRegistry.NotOperator.selector);
        registry.registerAffirmed("AR-2026-AFF05", b, "AR-2026-DIS-A03", "INVESTIGATION", "https://test");
    }

    function test_DisputeLifecycle_ReopenAfterAffirmed() public {
        // Full lifecycle: dispute → affirmed → reopen → void
        _registerCode("AR-2026-LIFECYCLE01", "sha256:lifecycle01");

        // Attach DISPUTE
        AnchorRegistry.AnchorBase memory db = _base(
            AnchorRegistry.ArtifactType.DISPUTE, "sha256:lifecycle-dis01", "DISPUTE-LIFECYCLE01"
        );
        db.parentHash = "AR-2026-LIFECYCLE01";
        vm.prank(operator);
        registry.registerDispute("AR-2026-DIS-LC01", db, "AR-2026-LIFECYCLE01", "FALSE_AUTHORSHIP", "https://test");

        // Affirm it (investigation found legitimate)
        AnchorRegistry.AnchorBase memory ab = _base(
            AnchorRegistry.ArtifactType.AFFIRMED, "sha256:lifecycle-aff01", "AFFIRMED-LC01"
        );
        ab.parentHash = "AR-2026-DIS-LC01";
        vm.prank(operator);
        registry.registerAffirmed("AR-2026-AFF-LC01", ab, "AR-2026-DIS-LC01", "INVESTIGATION", "https://test");

        // New evidence — reopen with new DISPUTE
        AnchorRegistry.AnchorBase memory db2 = _base(
            AnchorRegistry.ArtifactType.DISPUTE, "sha256:lifecycle-dis02", "DISPUTE-LIFECYCLE01-REOPEN"
        );
        db2.parentHash = "AR-2026-AFF-LC01";
        vm.prank(operator);
        registry.registerDispute("AR-2026-DIS-LC02", db2, "AR-2026-LIFECYCLE01", "MALICIOUS_TREE", "https://test");

        // Now void it
        AnchorRegistry.AnchorBase memory vb = _base(
            AnchorRegistry.ArtifactType.VOID, "sha256:lifecycle-void01", "VOID-LIFECYCLE01"
        );
        vb.parentHash = "AR-2026-DIS-LC02";
        vm.prank(operator);
        registry.registerVoid(
            "AR-2026-VOID-LC01", vb,
            "AR-2026-LIFECYCLE01", "AR-2026-DIS-LC02",
            "https://test", "New evidence confirmed fraud"
        );

        // All nodes registered
        assertTrue(registry.registered("AR-2026-DIS-LC01"));
        assertTrue(registry.registered("AR-2026-AFF-LC01"));
        assertTrue(registry.registered("AR-2026-DIS-LC02"));
        assertTrue(registry.registered("AR-2026-VOID-LC01"));
    }

    // =========================================================================
    // 5. CATCH-ALL (type 14 — OTHER) — already tested above
    // =========================================================================
    // test_RegisterOther() in Section 1 covers this.

    // =========================================================================
    // 6. ACCESS CONTROL — STANDARD OPERATORS
    // =========================================================================

    function test_OwnerSetOnDeploy() public view {
        assertEq(registry.owner(), owner);
    }

    function test_RecoveryAddressSetOnDeploy() public view {
        assertEq(registry.recoveryAddress(), recovery);
    }

    function test_OperatorAddedByOwner() public view {
        assertTrue(registry.operators(operator));
        assertTrue(registry.operators(opBackup));
    }

    function test_StrangerCannotRegister() public {
        vm.prank(stranger);
        vm.expectRevert(AnchorRegistry.NotOperator.selector);
        registry.registerCode("AR-2026-FAIL01", base, "git:fail", "MIT", "https://github.com/fail");
    }

    function test_OwnerCannotRegisterContentDirectly() public {
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
    // 7. ACCESS CONTROL — LEGAL OPERATORS (gated)
    // =========================================================================

    function test_OwnerCanAddLegalOperator() public {
        vm.prank(owner);
        registry.addLegalOperator(legalOp);
        assertTrue(registry.legalOperators(legalOp));
    }

    function test_StrangerCannotAddLegalOperator() public {
        vm.prank(stranger);
        vm.expectRevert(AnchorRegistry.NotOwner.selector);
        registry.addLegalOperator(legalOp);
    }

    function test_OwnerCanRemoveLegalOperator() public {
        vm.prank(owner);
        registry.addLegalOperator(legalOp);

        vm.prank(owner);
        registry.removeLegalOperator(legalOp);
        assertFalse(registry.legalOperators(legalOp));
    }

    function test_AddLegalOperatorZeroAddressReverts() public {
        vm.prank(owner);
        vm.expectRevert(AnchorRegistry.ZeroAddress.selector);
        registry.addLegalOperator(address(0));
    }

    function test_LegalOperatorEventsEmitted() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit AnchorRegistry.LegalOperatorAdded(legalOp);
        registry.addLegalOperator(legalOp);

        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit AnchorRegistry.LegalOperatorRemoved(legalOp);
        registry.removeLegalOperator(legalOp);
    }

    // =========================================================================
    // 8. ACCESS CONTROL — ENTITY OPERATORS (gated)
    // =========================================================================

    function test_OwnerCanAddEntityOperator() public {
        vm.prank(owner);
        registry.addEntityOperator(entityOp);
        assertTrue(registry.entityOperators(entityOp));
    }

    function test_StrangerCannotAddEntityOperator() public {
        vm.prank(stranger);
        vm.expectRevert(AnchorRegistry.NotOwner.selector);
        registry.addEntityOperator(entityOp);
    }

    function test_OwnerCanRemoveEntityOperator() public {
        vm.prank(owner);
        registry.addEntityOperator(entityOp);

        vm.prank(owner);
        registry.removeEntityOperator(entityOp);
        assertFalse(registry.entityOperators(entityOp));
    }

    function test_AddEntityOperatorZeroAddressReverts() public {
        vm.prank(owner);
        vm.expectRevert(AnchorRegistry.ZeroAddress.selector);
        registry.addEntityOperator(address(0));
    }

    function test_EntityOperatorEventsEmitted() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit AnchorRegistry.EntityOperatorAdded(entityOp);
        registry.addEntityOperator(entityOp);

        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit AnchorRegistry.EntityOperatorRemoved(entityOp);
        registry.removeEntityOperator(entityOp);
    }

    // =========================================================================
    // 9. EDGE CASES — VALIDATION ERRORS
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

    function test_DuplicateArIdAcrossTypes_Reverts() public {
        // Same AR-ID cannot be used by two different artifact types
        _registerCode("AR-2026-CROSS01", "sha256:cross01");

        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.TEXT, "sha256:cross02", "TEXT-CROSS"
        );
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(AnchorRegistry.AlreadyRegistered.selector, "AR-2026-CROSS01"));
        registry.registerText("AR-2026-CROSS01", b, "https://medium.com/test");
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

    // =========================================================================
    // 10. TREE INTEGRITY — parentHash VALIDATION
    // =========================================================================

    function test_ValidParentHashSucceeds() public {
        _registerCode("AR-2026-ROOT01", "sha256:root");

        AnchorRegistry.AnchorBase memory child = _baseWithParent("sha256:child", "AR-2026-ROOT01");
        vm.prank(operator);
        registry.registerCode("AR-2026-CHILD02", child, "git:child", "MIT", "https://github.com/child");
        assertTrue(registry.registered("AR-2026-CHILD02"));
    }

    function test_DeepLineageTree() public {
        _registerCode("AR-2026-L0", "sha256:level0");

        for (uint256 i = 1; i <= 5; i++) {
            string memory parentId = string(abi.encodePacked("AR-2026-L", vm.toString(i - 1)));
            string memory childId  = string(abi.encodePacked("AR-2026-L", vm.toString(i)));
            string memory hash     = string(abi.encodePacked("sha256:level", vm.toString(i)));

            AnchorRegistry.AnchorBase memory b = _baseWithParent(hash, parentId);
            vm.prank(operator);
            registry.registerCode(childId, b, "git:ln", "MIT", "https://github.com/ln");
        }
        assertTrue(registry.registered("AR-2026-L5"));
    }

    function test_MultipleChildrenSameParent() public {
        _registerCode("AR-2026-PARENT01", "sha256:parent01");

        for (uint256 i = 0; i < 5; i++) {
            string memory childId = string(abi.encodePacked("AR-2026-SIBLING-", vm.toString(i)));
            string memory hash    = string(abi.encodePacked("sha256:sibling", vm.toString(i)));
            AnchorRegistry.AnchorBase memory b = _baseWithParent(hash, "AR-2026-PARENT01");
            vm.prank(operator);
            registry.registerCode(childId, b, "git:sibling", "MIT", "https://github.com/sibling");
            assertTrue(registry.registered(childId));
        }
    }

    function test_CrossTypeParentChild() public {
        // A RESEARCH anchor can be a child of a CODE anchor
        _registerCode("AR-2026-CODE-PARENT", "sha256:codeparent");

        AnchorRegistry.AnchorBase memory b = AnchorRegistry.AnchorBase({
            artifactType: AnchorRegistry.ArtifactType.RESEARCH,
            manifestHash: "sha256:research-child",
            parentHash:   "AR-2026-CODE-PARENT",
            descriptor:   "PAPER-CHILD"
        });
        vm.prank(operator);
        registry.registerResearch("AR-2026-RES-CHILD", b, "10.1000/test", "https://arxiv.org/test");
        assertTrue(registry.registered("AR-2026-RES-CHILD"));
    }

    // =========================================================================
    // 11. EVENTS
    // =========================================================================

    function test_AnchoredEventEmitted_OnRegisterCode() public {
        vm.prank(operator);
        vm.expectEmit(true, true, false, true);
        emit AnchorRegistry.Anchored(
            "AR-2026-EVT01", operator,
            AnchorRegistry.ArtifactType.CODE,
            "ICMOORE-2026-TEST", "sha256:abc123", ""
        );
        registry.registerCode("AR-2026-EVT01", base, "gitabc", "MIT", "https://github.com/evt");
    }

    function test_AnchoredEventEmitted_OnRetraction() public {
        _registerCode("AR-2026-EVT-TARGET", "sha256:evttarget");

        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.RETRACTION, "sha256:evtret", "RETRACTION-EVT"
        );
        b.parentHash = "AR-2026-EVT-TARGET";

        vm.prank(operator);
        vm.expectEmit(true, true, false, true);
        emit AnchorRegistry.Anchored(
            "AR-2026-EVT-RET", operator,
            AnchorRegistry.ArtifactType.RETRACTION,
            "RETRACTION-EVT", "sha256:evtret",
            "AR-2026-EVT-TARGET"
        );
        registry.registerRetraction("AR-2026-EVT-RET", b, "AR-2026-EVT-TARGET", "", "");
    }

    function test_RetractedEventEmitted() public {
        _registerCode("AR-2026-EVT-TARGET2", "sha256:evttarget2");
        _registerCode("AR-2026-EVT-REPLACEMENT", "sha256:evtreplacement");

        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.RETRACTION, "sha256:evtret2", "RETRACTION-EVT2"
        );
        b.parentHash = "AR-2026-EVT-TARGET2";

        vm.prank(operator);
        vm.expectEmit(true, true, false, true);
        emit AnchorRegistry.Retracted("AR-2026-EVT-RET2", "AR-2026-EVT-TARGET2", "AR-2026-EVT-REPLACEMENT");
        registry.registerRetraction("AR-2026-EVT-RET2", b, "AR-2026-EVT-TARGET2", "superseded", "AR-2026-EVT-REPLACEMENT");
    }

    function test_DisputedEventEmitted() public {
        _registerCode("AR-2026-EVT-DTARGET", "sha256:evtdtarget");

        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.DISPUTE, "sha256:evtdis", "DISPUTE-EVT"
        );
        b.parentHash = "AR-2026-EVT-DTARGET";

        vm.prank(operator);
        vm.expectEmit(true, true, false, true);
        emit AnchorRegistry.Disputed("AR-2026-EVT-DIS", "AR-2026-EVT-DTARGET", "IMPERSONATION", "https://test");
        registry.registerDispute("AR-2026-EVT-DIS", b, "AR-2026-EVT-DTARGET", "IMPERSONATION", "https://test");
    }

    function test_VoidedEventEmitted() public {
        _registerAndGetDispute("AR-2026-EVT-VTARGET", "AR-2026-EVT-VDIS");

        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.VOID, "sha256:evtvoid", "VOID-EVT"
        );
        b.parentHash = "AR-2026-EVT-VDIS";

        vm.prank(operator);
        vm.expectEmit(true, true, true, true);
        emit AnchorRegistry.Voided("AR-2026-EVT-VOID", "AR-2026-EVT-VTARGET", "AR-2026-EVT-VDIS", "evidence");
        registry.registerVoid("AR-2026-EVT-VOID", b, "AR-2026-EVT-VTARGET", "AR-2026-EVT-VDIS", "https://test", "evidence");
    }

    function test_AffirmedEventEmitted() public {
        _registerAndGetDispute("AR-2026-EVT-ATARGET", "AR-2026-EVT-ADIS");

        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.AFFIRMED, "sha256:evtaff", "AFFIRMED-EVT"
        );
        b.parentHash = "AR-2026-EVT-ADIS";

        vm.prank(operator);
        vm.expectEmit(true, true, false, true);
        emit AnchorRegistry.Affirmed("AR-2026-EVT-AFF", "AR-2026-EVT-ADIS", "INVESTIGATION");
        registry.registerAffirmed("AR-2026-EVT-AFF", b, "AR-2026-EVT-ADIS", "INVESTIGATION", "https://test");
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
    // 12. RECOVERY FLOW & GRIEFING DEFENCE
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
        for (uint256 i = 0; i < 3; i++) {
            vm.warp(block.timestamp + 7 days + 1);

            vm.prank(recovery);
            registry.initiateRecovery(newOwner);

            vm.prank(owner);
            registry.cancelRecovery();

            vm.prank(recovery);
            vm.expectRevert(AnchorRegistry.RecoveryLockedOut.selector);
            registry.initiateRecovery(newOwner);
        }
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

    function test_NewOwnerAfterRecoveryCanAddAllOperatorTypes() public {
        vm.prank(recovery);
        registry.initiateRecovery(newOwner);
        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(recovery);
        registry.executeRecovery();

        // New owner can add standard operator
        address newOp = address(0x99);
        vm.prank(newOwner);
        registry.addOperator(newOp);
        assertTrue(registry.operators(newOp));

        // New owner can add legal operator
        vm.prank(newOwner);
        registry.addLegalOperator(legalOp);
        assertTrue(registry.legalOperators(legalOp));

        // New owner can add entity operator
        vm.prank(newOwner);
        registry.addEntityOperator(entityOp);
        assertTrue(registry.entityOperators(entityOp));
    }

    function test_FullRecoveryScenario_OwnerCompromised() public {
        address attacker = address(0xDEAD);

        // Owner compromised: attacker adds themselves as operator and legal operator
        vm.prank(owner);
        registry.addOperator(attacker);
        assertTrue(registry.operators(attacker));

        // Recovery initiates ownership transfer
        vm.prank(recovery);
        registry.initiateRecovery(newOwner);

        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(recovery);
        registry.executeRecovery();
        assertEq(registry.owner(), newOwner);

        // New owner cleans up all attacker operator roles
        vm.prank(newOwner);
        registry.removeOperator(attacker);
        assertFalse(registry.operators(attacker));

        // New owner restores legitimate operator
        vm.prank(newOwner);
        registry.addOperator(operator);
        assertTrue(registry.operators(operator));
    }

    function test_RecoveryDoesNotAffectLegalEntityOperators() public {
        // Add legal and entity operators before recovery
        vm.prank(owner);
        registry.addLegalOperator(legalOp);
        vm.prank(owner);
        registry.addEntityOperator(entityOp);

        // Recovery transfers ownership
        vm.prank(recovery);
        registry.initiateRecovery(newOwner);
        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(recovery);
        registry.executeRecovery();

        // Legal and entity operator mappings persist through recovery
        // New owner must explicitly remove them if needed
        assertTrue(registry.legalOperators(legalOp));
        assertTrue(registry.entityOperators(entityOp));

        // New owner can remove them
        vm.prank(newOwner);
        registry.removeLegalOperator(legalOp);
        assertFalse(registry.legalOperators(legalOp));
    }
}
