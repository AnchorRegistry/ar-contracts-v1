// SPDX-License-Identifier: BUSL-1.1
// Change Date:    March 12, 2028
// Change License: Apache-2.0
// Licensor:       Ian Moore (icmoore)

pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/AnchorRegistry.sol";

/// @title  AnchorRegistryTest
/// @notice Foundry test suite for AnchorRegistry.sol (final — 16 artifact types).
///
///         Sections:
///         1.  Content types (0-7)
///         2.  Gated types (8-10) — LEGAL, ENTITY, PROOF
///         3.  RETRACTION (type 11)
///         4.  REVIEW, VOID, AFFIRMED (types 12-14)
///         5.  OTHER (type 15)
///         6.  Access control
///         7.  Edge cases & validation
///         8.  Tree integrity
///         9.  Events
///         10. Recovery & griefing defence

contract AnchorRegistryTest is Test {

    AnchorRegistry public registry;

    address public owner       = address(0x1);
    address public operator    = address(0x2);
    address public opBackup    = address(0x3);
    address public recovery    = address(0x4);
    address public stranger    = address(0x5);
    address public newOwner    = address(0x6);
    address public newRecovery = address(0x7);
    address public legalOp     = address(0x8);
    address public entityOp    = address(0x9);
    address public proofOp     = address(0xA);

    AnchorRegistry.AnchorBase base = AnchorRegistry.AnchorBase({
        artifactType: AnchorRegistry.ArtifactType.CODE,
        manifestHash: "sha256:abc123",
        parentHash:   "",
        descriptor:   "ICMOORE-2026-TEST"
    });

    function setUp() public {
        vm.prank(owner);
        registry = new AnchorRegistry(recovery);
        vm.prank(owner); registry.addOperator(operator);
        vm.prank(owner); registry.addOperator(opBackup);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    function _base(
        AnchorRegistry.ArtifactType t,
        string memory h,
        string memory d
    ) internal pure returns (AnchorRegistry.AnchorBase memory) {
        return AnchorRegistry.AnchorBase({ artifactType: t, manifestHash: h, parentHash: "", descriptor: d });
    }

    function _child(string memory h, string memory parent)
        internal pure returns (AnchorRegistry.AnchorBase memory)
    {
        return AnchorRegistry.AnchorBase({
            artifactType: AnchorRegistry.ArtifactType.CODE,
            manifestHash: h, parentHash: parent, descriptor: "CHILD"
        });
    }

    function _code(string memory arId, string memory h) internal {
        vm.prank(operator);
        registry.registerCode(arId, _base(AnchorRegistry.ArtifactType.CODE, h, "TEST"),
            "git:abc", "MIT", "https://test");
    }

    function _review(string memory reviewArId, string memory targetArId) internal {
        _code(targetArId, string(abi.encodePacked("sha256:", targetArId)));
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.REVIEW,
            string(abi.encodePacked("sha256:review-", reviewArId)),
            string(abi.encodePacked("REVIEW-", reviewArId))
        );
        b.parentHash = targetArId;
        vm.prank(operator);
        registry.registerReview(reviewArId, b, targetArId, "FALSE_AUTHORSHIP", "https://test");
    }

    // =========================================================================
    // 1. CONTENT TYPES (0-7)
    // =========================================================================

    function test_RegisterCode() public {
        vm.prank(operator);
        registry.registerCode("AR-CODE01", base, "git:abc", "MIT", "https://test");
        assertTrue(registry.registered("AR-CODE01"));
    }

    function test_RegisterResearch() public {
        vm.prank(operator);
        registry.registerResearch("AR-RES01",
            _base(AnchorRegistry.ArtifactType.RESEARCH, "sha256:res01", "PAPER"),
            "10.1000/test", "https://arxiv.org/test");
        assertTrue(registry.registered("AR-RES01"));
    }

    function test_RegisterData() public {
        vm.prank(operator);
        registry.registerData("AR-DATA01",
            _base(AnchorRegistry.ArtifactType.DATA, "sha256:data01", "DATASET"),
            "v1.0.0", "https://huggingface.co/test");
        assertTrue(registry.registered("AR-DATA01"));
    }

    function test_RegisterModel() public {
        vm.prank(operator);
        registry.registerModel("AR-MDL01",
            _base(AnchorRegistry.ArtifactType.MODEL, "sha256:mdl01", "MODEL"),
            "v1.0.0", "https://huggingface.co/test");
        assertTrue(registry.registered("AR-MDL01"));
    }

    function test_RegisterAgent() public {
        vm.prank(operator);
        registry.registerAgent("AR-AGT01",
            _base(AnchorRegistry.ArtifactType.AGENT, "sha256:agt01", "AGENT"),
            "v0.1.0", "https://github.com/test");
        assertTrue(registry.registered("AR-AGT01"));
    }

    function test_RegisterMedia() public {
        vm.prank(operator);
        registry.registerMedia("AR-MED01",
            _base(AnchorRegistry.ArtifactType.MEDIA, "sha256:med01", "MEDIA"),
            "image/png", "https://ipfs.io/test");
        assertTrue(registry.registered("AR-MED01"));
    }

    function test_RegisterText() public {
        vm.prank(operator);
        registry.registerText("AR-TXT01",
            _base(AnchorRegistry.ArtifactType.TEXT, "sha256:txt01", "ARTICLE"),
            "https://medium.com/test");
        assertTrue(registry.registered("AR-TXT01"));
    }

    function test_RegisterPost() public {
        vm.prank(operator);
        registry.registerPost("AR-PST01",
            _base(AnchorRegistry.ArtifactType.POST, "sha256:pst01", "TWEET"),
            "X/Twitter", "https://x.com/test");
        assertTrue(registry.registered("AR-PST01"));
    }

    function test_BackupOperatorCanRegister() public {
        vm.prank(opBackup);
        registry.registerCode("AR-BACK01", base, "git:backup", "MIT", "https://test");
        assertTrue(registry.registered("AR-BACK01"));
    }

    // =========================================================================
    // 2. GATED TYPES (8-10) — suppressed at launch
    // =========================================================================

    // ── LEGAL (8) ─────────────────────────────────────────────────────────────

    function test_Legal_SuppressedAtLaunch() public {
        assertFalse(registry.legalOperators(operator));
        assertFalse(registry.legalOperators(legalOp));
    }

    function test_Legal_ByLegalOperator_Succeeds() public {
        vm.prank(owner); registry.addLegalOperator(legalOp);
        vm.prank(legalOp);
        registry.registerLegal("AR-LGL01",
            _base(AnchorRegistry.ArtifactType.LEGAL, "sha256:lgl01", "TRADEMARK"),
            "TRADEMARK", "https://cipo.ic.gc.ca/test");
        assertTrue(registry.registered("AR-LGL01"));
    }

    function test_Legal_ByStandardOperator_Reverts() public {
        vm.prank(operator);
        vm.expectRevert(AnchorRegistry.NotLegalOperator.selector);
        registry.registerLegal("AR-LGL02",
            _base(AnchorRegistry.ArtifactType.LEGAL, "sha256:lgl02", "TRADEMARK"),
            "TRADEMARK", "https://test");
    }

    function test_Legal_RemovedOperator_Reverts() public {
        vm.prank(owner); registry.addLegalOperator(legalOp);
        vm.prank(owner); registry.removeLegalOperator(legalOp);
        vm.prank(legalOp);
        vm.expectRevert(AnchorRegistry.NotLegalOperator.selector);
        registry.registerLegal("AR-LGL03",
            _base(AnchorRegistry.ArtifactType.LEGAL, "sha256:lgl03", "TRADEMARK"),
            "TRADEMARK", "https://test");
    }

    // ── ENTITY (9) ────────────────────────────────────────────────────────────

    function test_Entity_SuppressedAtLaunch() public {
        assertFalse(registry.entityOperators(operator));
        assertFalse(registry.entityOperators(entityOp));
    }

    function test_Entity_ByEntityOperator_Succeeds() public {
        vm.prank(owner); registry.addEntityOperator(entityOp);
        vm.prank(entityOp);
        registry.registerEntity("AR-ENT01",
            _base(AnchorRegistry.ArtifactType.ENTITY, "sha256:ent01", "ICMOORE-ENTITY"),
            "PERSON", "icmoore.com", "DNS_TXT",
            "anchorregistry-verify=abc123",
            "https://anchorregistry.ai/canonical/AR-ENT01",
            "sha256:canonicaldoc01");
        assertTrue(registry.registered("AR-ENT01"));
    }

    function test_Entity_ByStandardOperator_Reverts() public {
        vm.prank(operator);
        vm.expectRevert(AnchorRegistry.NotEntityOperator.selector);
        registry.registerEntity("AR-ENT02",
            _base(AnchorRegistry.ArtifactType.ENTITY, "sha256:ent02", "ENTITY"),
            "PERSON", "icmoore.com", "DNS_TXT", "proof", "", "");
    }

    function test_Entity_RemovedOperator_Reverts() public {
        vm.prank(owner); registry.addEntityOperator(entityOp);
        vm.prank(owner); registry.removeEntityOperator(entityOp);
        vm.prank(entityOp);
        vm.expectRevert(AnchorRegistry.NotEntityOperator.selector);
        registry.registerEntity("AR-ENT03",
            _base(AnchorRegistry.ArtifactType.ENTITY, "sha256:ent03", "ENTITY"),
            "PERSON", "icmoore.com", "DNS_TXT", "proof", "", "");
    }

    // ── PROOF (10) ────────────────────────────────────────────────────────────

    function test_Proof_SuppressedAtLaunch() public {
        assertFalse(registry.proofOperators(operator));
        assertFalse(registry.proofOperators(proofOp));
    }

    function test_Proof_ByProofOperator_Succeeds() public {
        vm.prank(owner); registry.addProofOperator(proofOp);
        vm.prank(proofOp);
        registry.registerProof("AR-PRF01",
            _base(AnchorRegistry.ArtifactType.PROOF, "sha256:prf01", "ZKP-2026"),
            "GROTH16", "snarkjs",
            "https://verifier.anchorregistry.ai/AR-PRF01",
            "sha256:proofhash01");
        assertTrue(registry.registered("AR-PRF01"));
    }

    function test_Proof_ByStandardOperator_Reverts() public {
        vm.prank(operator);
        vm.expectRevert(AnchorRegistry.NotProofOperator.selector);
        registry.registerProof("AR-PRF02",
            _base(AnchorRegistry.ArtifactType.PROOF, "sha256:prf02", "ZKP"),
            "GROTH16", "snarkjs", "https://test", "sha256:proof02");
    }

    function test_Proof_RemovedOperator_Reverts() public {
        vm.prank(owner); registry.addProofOperator(proofOp);
        vm.prank(owner); registry.removeProofOperator(proofOp);
        vm.prank(proofOp);
        vm.expectRevert(AnchorRegistry.NotProofOperator.selector);
        registry.registerProof("AR-PRF03",
            _base(AnchorRegistry.ArtifactType.PROOF, "sha256:prf03", "ZKP"),
            "GROTH16", "snarkjs", "https://test", "sha256:proof03");
    }

    function test_GatedOperatorsAreIndependent() public {
        vm.prank(owner); registry.addLegalOperator(legalOp);
        assertFalse(registry.entityOperators(legalOp));
        assertFalse(registry.proofOperators(legalOp));

        vm.prank(owner); registry.addEntityOperator(entityOp);
        assertFalse(registry.legalOperators(entityOp));
        assertFalse(registry.proofOperators(entityOp));

        vm.prank(owner); registry.addProofOperator(proofOp);
        assertFalse(registry.legalOperators(proofOp));
        assertFalse(registry.entityOperators(proofOp));
    }

    // =========================================================================
    // 3. RETRACTION (type 11)
    // =========================================================================

    function test_Retraction_Succeeds() public {
        _code("AR-TARGET01", "sha256:target01");
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.RETRACTION, "sha256:ret01", "RETRACTION-TARGET01"
        );
        b.parentHash = "AR-TARGET01";
        vm.prank(operator);
        registry.registerRetraction("AR-RET01", b, "AR-TARGET01", "Wrong file", "");
        assertTrue(registry.registered("AR-RET01"));
    }

    function test_Retraction_WithReplacement() public {
        _code("AR-V1", "sha256:v1");
        _code("AR-V2", "sha256:v2");
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.RETRACTION, "sha256:ret02", "RETRACTION-V1"
        );
        b.parentHash = "AR-V1";
        vm.prank(operator);
        vm.expectEmit(true, true, false, true);
        emit AnchorRegistry.Retracted("AR-RET02", "AR-V1", "AR-V2");
        registry.registerRetraction("AR-RET02", b, "AR-V1", "Superseded", "AR-V2");

        (,string memory retTargetArId,,string memory retReplacedBy) = registry.retractionAnchors("AR-RET02");
        assertEq(retTargetArId, "AR-V1");
        assertEq(retReplacedBy, "AR-V2");
    }

    function test_Retraction_NonExistentTarget_Reverts() public {
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.RETRACTION, "sha256:ret03", "RETRACTION"
        );
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(AnchorRegistry.InvalidTarget.selector, "AR-MISSING"));
        registry.registerRetraction("AR-RET03", b, "AR-MISSING", "", "");
    }

    function test_Retraction_EmptyTarget_Reverts() public {
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.RETRACTION, "sha256:ret04", "RETRACTION"
        );
        vm.prank(operator);
        vm.expectRevert(AnchorRegistry.EmptyTargetArId.selector);
        registry.registerRetraction("AR-RET04", b, "", "", "");
    }

    function test_NodeSwap_ChildrenPreservedOnChain() public {
        _code("AR-ROOT", "sha256:root");

        vm.prank(operator);
        registry.registerCode("AR-V1", _child("sha256:v1", "AR-ROOT"), "git:v1", "MIT", "https://test");
        vm.prank(operator);
        registry.registerCode("AR-CHILD", _child("sha256:child", "AR-V1"), "git:child", "MIT", "https://test");
        vm.prank(operator);
        registry.registerCode("AR-V2", _child("sha256:v2", "AR-ROOT"), "git:v2", "MIT", "https://test");

        AnchorRegistry.AnchorBase memory retb = _base(
            AnchorRegistry.ArtifactType.RETRACTION, "sha256:ret", "RETRACTION-V1"
        );
        retb.parentHash = "AR-V1";
        vm.prank(operator);
        registry.registerRetraction("AR-RET", retb, "AR-V1", "Superseded by V2", "AR-V2");

        // replacedBy stored — resolution layer handles logical child migration
        (,,,string memory retReplacedBy2) = registry.retractionAnchors("AR-RET");
        assertEq(retReplacedBy2, "AR-V2");

        // child's parentHash is immutable on-chain
        (AnchorRegistry.AnchorBase memory childBase,,, ) = registry.codeAnchors("AR-CHILD");
        assertEq(childBase.parentHash, "AR-V1");
    }

    // =========================================================================
    // 4. REVIEW, VOID, AFFIRMED (types 12-14)
    // =========================================================================

    // ── REVIEW (12) ───────────────────────────────────────────────────────────

    function test_Review_Succeeds() public {
        _code("AR-RTARGET01", "sha256:rtarget01");
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.REVIEW, "sha256:rev01", "REVIEW-RTARGET01"
        );
        b.parentHash = "AR-RTARGET01";
        vm.prank(operator);
        vm.expectEmit(true, true, false, true);
        emit AnchorRegistry.Reviewed("AR-REV01", "AR-RTARGET01", "FALSE_AUTHORSHIP", "https://test");
        registry.registerReview("AR-REV01", b, "AR-RTARGET01", "FALSE_AUTHORSHIP", "https://test");
        assertTrue(registry.registered("AR-REV01"));
    }

    function test_Review_NonExistentTarget_Reverts() public {
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.REVIEW, "sha256:rev02", "REVIEW"
        );
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(AnchorRegistry.InvalidTarget.selector, "AR-MISSING"));
        registry.registerReview("AR-REV02", b, "AR-MISSING", "OTHER", "https://test");
    }

    function test_Review_EmptyTarget_Reverts() public {
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.REVIEW, "sha256:rev03", "REVIEW"
        );
        vm.prank(operator);
        vm.expectRevert(AnchorRegistry.EmptyTargetArId.selector);
        registry.registerReview("AR-REV03", b, "", "OTHER", "https://test");
    }

    function test_Review_ByStranger_Reverts() public {
        _code("AR-RTARGET02", "sha256:rtarget02");
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.REVIEW, "sha256:rev04", "REVIEW"
        );
        vm.prank(stranger);
        vm.expectRevert(AnchorRegistry.NotOperator.selector);
        registry.registerReview("AR-REV04", b, "AR-RTARGET02", "OTHER", "https://test");
    }

    // ── VOID (13) ─────────────────────────────────────────────────────────────

    function test_Void_Succeeds() public {
        _review("AR-REV-V01", "AR-VTARGET01");
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.VOID, "sha256:void01", "VOID-VTARGET01"
        );
        b.parentHash = "AR-REV-V01";
        vm.prank(operator);
        vm.expectEmit(true, true, true, true);
        emit AnchorRegistry.Voided("AR-VOID01", "AR-VTARGET01", "AR-REV-V01", "Fraud confirmed");
        registry.registerVoid("AR-VOID01", b, "AR-VTARGET01", "AR-REV-V01", "https://test", "Fraud confirmed");
        assertTrue(registry.registered("AR-VOID01"));

        (,string memory vTargetArId, string memory vReviewArId,, string memory vEvidence) = registry.voidAnchors("AR-VOID01");
        assertEq(vTargetArId, "AR-VTARGET01");
        assertEq(vReviewArId, "AR-REV-V01");
        assertEq(vEvidence,   "Fraud confirmed");
    }

    function test_Void_NonExistentTarget_Reverts() public {
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.VOID, "sha256:void02", "VOID"
        );
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(AnchorRegistry.InvalidTarget.selector, "AR-MISSING"));
        registry.registerVoid("AR-VOID02", b, "AR-MISSING", "AR-SOMEREVIEW", "https://test", "evidence");
    }

    function test_Void_NonExistentReviewArId_Reverts() public {
        _code("AR-VTARGET02", "sha256:vtarget02");
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.VOID, "sha256:void03", "VOID"
        );
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(AnchorRegistry.InvalidTarget.selector, "AR-NOREVIEW"));
        registry.registerVoid("AR-VOID03", b, "AR-VTARGET02", "AR-NOREVIEW", "https://test", "evidence");
    }

    function test_Void_ByStranger_Reverts() public {
        _review("AR-REV-V02", "AR-VTARGET03");
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.VOID, "sha256:void04", "VOID"
        );
        vm.prank(stranger);
        vm.expectRevert(AnchorRegistry.NotOperator.selector);
        registry.registerVoid("AR-VOID04", b, "AR-VTARGET03", "AR-REV-V02", "https://test", "evidence");
    }

    // ── AFFIRMED (14) ─────────────────────────────────────────────────────────

    function test_Affirmed_OnReview_Investigation() public {
        _review("AR-REV-A01", "AR-ATARGET01");
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.AFFIRMED, "sha256:aff01", "AFFIRMED-REV-A01"
        );
        b.parentHash = "AR-REV-A01";
        vm.prank(operator);
        vm.expectEmit(true, true, false, true);
        emit AnchorRegistry.Affirmed("AR-AFF01", "AR-REV-A01", "INVESTIGATION");
        registry.registerAffirmed("AR-AFF01", b, "AR-REV-A01", "INVESTIGATION", "https://test");
        assertTrue(registry.registered("AR-AFF01"));
    }

    function test_Affirmed_OnVoid_Appeal() public {
        _review("AR-REV-A02", "AR-ATARGET02");

        AnchorRegistry.AnchorBase memory vb = _base(
            AnchorRegistry.ArtifactType.VOID, "sha256:void-a02", "VOID-A02"
        );
        vb.parentHash = "AR-REV-A02";
        vm.prank(operator);
        registry.registerVoid("AR-VOID-A02", vb, "AR-ATARGET02", "AR-REV-A02", "https://test", "evidence");

        AnchorRegistry.AnchorBase memory ab = _base(
            AnchorRegistry.ArtifactType.AFFIRMED, "sha256:aff02", "AFFIRMED-VOID-A02"
        );
        ab.parentHash = "AR-VOID-A02";
        vm.prank(operator);
        vm.expectEmit(true, true, false, true);
        emit AnchorRegistry.Affirmed("AR-AFF02", "AR-VOID-A02", "APPEAL");
        registry.registerAffirmed("AR-AFF02", ab, "AR-VOID-A02", "APPEAL", "https://test");

        (,string memory affTargetArId, string memory affAffirmedBy,) = registry.affirmedAnchors("AR-AFF02");
        assertEq(affTargetArId, "AR-VOID-A02");
        assertEq(affAffirmedBy, "APPEAL");
    }

    function test_Affirmed_NonExistentTarget_Reverts() public {
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.AFFIRMED, "sha256:aff03", "AFFIRMED"
        );
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(AnchorRegistry.InvalidTarget.selector, "AR-MISSING"));
        registry.registerAffirmed("AR-AFF03", b, "AR-MISSING", "INVESTIGATION", "https://test");
    }

    function test_Affirmed_ByStranger_Reverts() public {
        _review("AR-REV-A03", "AR-ATARGET03");
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.AFFIRMED, "sha256:aff04", "AFFIRMED"
        );
        vm.prank(stranger);
        vm.expectRevert(AnchorRegistry.NotOperator.selector);
        registry.registerAffirmed("AR-AFF04", b, "AR-REV-A03", "INVESTIGATION", "https://test");
    }

    function test_FullLifecycle_ReviewVoidAffirmedReopen() public {
        _code("AR-LC01", "sha256:lc01");

        AnchorRegistry.AnchorBase memory rb = _base(
            AnchorRegistry.ArtifactType.REVIEW, "sha256:lc-rev", "REVIEW-LC01"
        );
        rb.parentHash = "AR-LC01";
        vm.prank(operator);
        registry.registerReview("AR-LC-REV", rb, "AR-LC01", "FALSE_AUTHORSHIP", "https://test");

        AnchorRegistry.AnchorBase memory ab = _base(
            AnchorRegistry.ArtifactType.AFFIRMED, "sha256:lc-aff", "AFFIRMED-LC01"
        );
        ab.parentHash = "AR-LC-REV";
        vm.prank(operator);
        registry.registerAffirmed("AR-LC-AFF", ab, "AR-LC-REV", "INVESTIGATION", "https://test");

        AnchorRegistry.AnchorBase memory rb2 = _base(
            AnchorRegistry.ArtifactType.REVIEW, "sha256:lc-rev2", "REVIEW-LC01-REOPEN"
        );
        rb2.parentHash = "AR-LC-AFF";
        vm.prank(operator);
        registry.registerReview("AR-LC-REV2", rb2, "AR-LC01", "MALICIOUS_TREE", "https://test");

        AnchorRegistry.AnchorBase memory vb = _base(
            AnchorRegistry.ArtifactType.VOID, "sha256:lc-void", "VOID-LC01"
        );
        vb.parentHash = "AR-LC-REV2";
        vm.prank(operator);
        registry.registerVoid("AR-LC-VOID", vb, "AR-LC01", "AR-LC-REV2", "https://test", "New evidence");

        assertTrue(registry.registered("AR-LC-REV"));
        assertTrue(registry.registered("AR-LC-AFF"));
        assertTrue(registry.registered("AR-LC-REV2"));
        assertTrue(registry.registered("AR-LC-VOID"));
    }

    // =========================================================================
    // 5. OTHER (type 15)
    // =========================================================================

    function test_RegisterOther() public {
        vm.prank(operator);
        registry.registerOther("AR-OTH01",
            _base(AnchorRegistry.ArtifactType.OTHER, "sha256:oth01", "COURSE"),
            "course", "Thinkific", "https://thinkific.com/test", "DeFi 101");
        assertTrue(registry.registered("AR-OTH01"));
    }

    // =========================================================================
    // 6. ACCESS CONTROL
    // =========================================================================

    function test_OwnerAndRecoverySetOnDeploy() public view {
        assertEq(registry.owner(), owner);
        assertEq(registry.recoveryAddress(), recovery);
    }

    function test_OperatorsAddedInSetup() public view {
        assertTrue(registry.operators(operator));
        assertTrue(registry.operators(opBackup));
    }

    function test_StrangerCannotRegister() public {
        vm.prank(stranger);
        vm.expectRevert(AnchorRegistry.NotOperator.selector);
        registry.registerCode("AR-FAIL01", base, "git:fail", "MIT", "https://test");
    }

    function test_OwnerCannotRegisterContent() public {
        vm.prank(owner);
        vm.expectRevert(AnchorRegistry.NotOperator.selector);
        registry.registerCode("AR-FAIL02", base, "git:fail", "MIT", "https://test");
    }

    function test_OwnerCanAddAndRemoveOperator() public {
        vm.prank(owner); registry.addOperator(stranger);
        assertTrue(registry.operators(stranger));
        vm.prank(owner); registry.removeOperator(stranger);
        assertFalse(registry.operators(stranger));
    }

    function test_RemovedOperatorCannotRegister() public {
        vm.prank(owner); registry.removeOperator(operator);
        vm.prank(operator);
        vm.expectRevert(AnchorRegistry.NotOperator.selector);
        registry.registerCode("AR-FAIL03", base, "git:fail", "MIT", "https://test");
    }

    function test_OwnerCanTransferOwnership() public {
        vm.prank(owner); registry.transferOwnership(newOwner);
        assertEq(registry.owner(), newOwner);
    }

    function test_StrangerCannotTransferOwnership() public {
        vm.prank(stranger);
        vm.expectRevert(AnchorRegistry.NotOwner.selector);
        registry.transferOwnership(stranger);
    }

    function test_ZeroAddressReverts_AllGates() public {
        vm.startPrank(owner);
        vm.expectRevert(AnchorRegistry.ZeroAddress.selector); registry.addOperator(address(0));
        vm.expectRevert(AnchorRegistry.ZeroAddress.selector); registry.addLegalOperator(address(0));
        vm.expectRevert(AnchorRegistry.ZeroAddress.selector); registry.addEntityOperator(address(0));
        vm.expectRevert(AnchorRegistry.ZeroAddress.selector); registry.addProofOperator(address(0));
        vm.expectRevert(AnchorRegistry.ZeroAddress.selector); registry.transferOwnership(address(0));
        vm.stopPrank();
    }

    function test_DeployZeroRecovery_Reverts() public {
        vm.prank(owner);
        vm.expectRevert(AnchorRegistry.ZeroAddress.selector);
        new AnchorRegistry(address(0));
    }

    // =========================================================================
    // 7. EDGE CASES & VALIDATION
    // =========================================================================

    function test_EmptyArId_Reverts() public {
        vm.prank(operator);
        vm.expectRevert(AnchorRegistry.EmptyArId.selector);
        registry.registerCode("", base, "git:abc", "MIT", "https://test");
    }

    function test_EmptyManifestHash_Reverts() public {
        vm.prank(operator);
        vm.expectRevert(AnchorRegistry.EmptyManifestHash.selector);
        registry.registerCode("AR-FAIL04",
            _base(AnchorRegistry.ArtifactType.CODE, "", "TEST"),
            "git:abc", "MIT", "https://test");
    }

    function test_DuplicateArId_Reverts() public {
        _code("AR-DUP01", "sha256:first");
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(AnchorRegistry.AlreadyRegistered.selector, "AR-DUP01"));
        registry.registerCode("AR-DUP01", base, "git:abc", "MIT", "https://test");
    }

    function test_DuplicateArIdAcrossTypes_Reverts() public {
        _code("AR-CROSS01", "sha256:cross01");
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(AnchorRegistry.AlreadyRegistered.selector, "AR-CROSS01"));
        registry.registerText("AR-CROSS01",
            _base(AnchorRegistry.ArtifactType.TEXT, "sha256:cross02", "TEXT"),
            "https://test");
    }

    function test_InvalidParentHash_Reverts() public {
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(AnchorRegistry.InvalidParent.selector, "AR-DOESNOTEXIST"));
        registry.registerCode("AR-CHILD01", _child("sha256:child01", "AR-DOESNOTEXIST"),
            "git:child", "MIT", "https://test");
    }

    // =========================================================================
    // 8. TREE INTEGRITY
    // =========================================================================

    function test_ValidParentHash_Succeeds() public {
        _code("AR-ROOT01", "sha256:root");
        vm.prank(operator);
        registry.registerCode("AR-CHILD02", _child("sha256:child", "AR-ROOT01"),
            "git:child", "MIT", "https://test");
        assertTrue(registry.registered("AR-CHILD02"));
    }

    function test_DeepLineageTree() public {
        _code("AR-L0", "sha256:l0");
        for (uint256 i = 1; i <= 5; i++) {
            string memory parent = string(abi.encodePacked("AR-L", vm.toString(i - 1)));
            string memory id     = string(abi.encodePacked("AR-L", vm.toString(i)));
            string memory h      = string(abi.encodePacked("sha256:l", vm.toString(i)));
            vm.prank(operator);
            registry.registerCode(id, _child(h, parent), "git:l", "MIT", "https://test");
        }
        assertTrue(registry.registered("AR-L5"));
    }

    function test_MultipleChildrenSameParent() public {
        _code("AR-PARENT01", "sha256:parent01");
        for (uint256 i = 0; i < 5; i++) {
            string memory id = string(abi.encodePacked("AR-SIB-", vm.toString(i)));
            string memory h  = string(abi.encodePacked("sha256:sib", vm.toString(i)));
            vm.prank(operator);
            registry.registerCode(id, _child(h, "AR-PARENT01"), "git:sib", "MIT", "https://test");
            assertTrue(registry.registered(id));
        }
    }

    function test_CrossTypeParentChild() public {
        _code("AR-CODE-PARENT", "sha256:codeparent");
        AnchorRegistry.AnchorBase memory b = AnchorRegistry.AnchorBase({
            artifactType: AnchorRegistry.ArtifactType.RESEARCH,
            manifestHash: "sha256:res-child",
            parentHash:   "AR-CODE-PARENT",
            descriptor:   "PAPER-CHILD"
        });
        vm.prank(operator);
        registry.registerResearch("AR-RES-CHILD", b, "10.1000/test", "https://arxiv.org/test");
        assertTrue(registry.registered("AR-RES-CHILD"));
    }

    // =========================================================================
    // 9. EVENTS
    // =========================================================================

    function test_AnchoredEvent_OnRegisterCode() public {
        vm.prank(operator);
        vm.expectEmit(true, true, false, true);
        emit AnchorRegistry.Anchored(
            "AR-EVT01", operator,
            AnchorRegistry.ArtifactType.CODE,
            "ICMOORE-2026-TEST", "sha256:abc123", ""
        );
        registry.registerCode("AR-EVT01", base, "git:abc", "MIT", "https://test");
    }

    function test_RetractedEvent() public {
        _code("AR-EVT-T01", "sha256:evtt01");
        _code("AR-EVT-REP01", "sha256:evtrep01");
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.RETRACTION, "sha256:evtret01", "RETRACTION"
        );
        b.parentHash = "AR-EVT-T01";
        vm.prank(operator);
        vm.expectEmit(true, true, false, true);
        emit AnchorRegistry.Retracted("AR-EVT-RET01", "AR-EVT-T01", "AR-EVT-REP01");
        registry.registerRetraction("AR-EVT-RET01", b, "AR-EVT-T01", "superseded", "AR-EVT-REP01");
    }

    function test_ReviewedEvent() public {
        _code("AR-EVT-DT01", "sha256:evtdt01");
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.REVIEW, "sha256:evtrev01", "REVIEW"
        );
        b.parentHash = "AR-EVT-DT01";
        vm.prank(operator);
        vm.expectEmit(true, true, false, true);
        emit AnchorRegistry.Reviewed("AR-EVT-REV01", "AR-EVT-DT01", "IMPERSONATION", "https://test");
        registry.registerReview("AR-EVT-REV01", b, "AR-EVT-DT01", "IMPERSONATION", "https://test");
    }

    function test_VoidedEvent() public {
        _review("AR-EVT-REV02", "AR-EVT-VT01");
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.VOID, "sha256:evtvoid01", "VOID"
        );
        b.parentHash = "AR-EVT-REV02";
        vm.prank(operator);
        vm.expectEmit(true, true, true, true);
        emit AnchorRegistry.Voided("AR-EVT-VOID01", "AR-EVT-VT01", "AR-EVT-REV02", "evidence");
        registry.registerVoid("AR-EVT-VOID01", b, "AR-EVT-VT01", "AR-EVT-REV02", "https://test", "evidence");
    }

    function test_AffirmedEvent() public {
        _review("AR-EVT-REV03", "AR-EVT-AT01");
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.AFFIRMED, "sha256:evtaff01", "AFFIRMED"
        );
        b.parentHash = "AR-EVT-REV03";
        vm.prank(operator);
        vm.expectEmit(true, true, false, true);
        emit AnchorRegistry.Affirmed("AR-EVT-AFF01", "AR-EVT-REV03", "INVESTIGATION");
        registry.registerAffirmed("AR-EVT-AFF01", b, "AR-EVT-REV03", "INVESTIGATION", "https://test");
    }

    // =========================================================================
    // 10. RECOVERY & GRIEFING DEFENCE
    // =========================================================================

    function test_RecoveryInitiated() public {
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
        vm.prank(recovery); registry.initiateRecovery(newOwner);
        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(recovery); registry.executeRecovery();
        assertEq(registry.owner(), newOwner);
        assertEq(registry.pendingOwner(), address(0));
        assertEq(registry.recoveryInitiatedAt(), 0);
    }

    function test_RecoveryFailsBeforeDelay() public {
        vm.prank(recovery); registry.initiateRecovery(newOwner);
        vm.warp(block.timestamp + 6 days);
        vm.prank(recovery);
        vm.expectRevert(AnchorRegistry.RecoveryDelayNotMet.selector);
        registry.executeRecovery();
    }

    function test_RecoveryFailsWithoutInitiation() public {
        vm.prank(recovery);
        vm.expectRevert(AnchorRegistry.RecoveryNotInitiated.selector);
        registry.executeRecovery();
    }

    function test_OwnerCanCancelRecovery() public {
        vm.prank(recovery); registry.initiateRecovery(newOwner);
        vm.prank(owner); registry.cancelRecovery();
        assertEq(registry.pendingOwner(), address(0));
        assertEq(registry.recoveryInitiatedAt(), 0);
    }

    function test_CancelActivates7DayLockout() public {
        vm.prank(recovery); registry.initiateRecovery(newOwner);
        vm.prank(owner); registry.cancelRecovery();
        assertGt(registry.recoveryLockoutUntil(), block.timestamp);
        vm.prank(recovery);
        vm.expectRevert(AnchorRegistry.RecoveryLockedOut.selector);
        registry.initiateRecovery(newOwner);
    }

    function test_RecoveryAllowedAfterLockoutExpires() public {
        vm.prank(recovery); registry.initiateRecovery(newOwner);
        vm.prank(owner); registry.cancelRecovery();
        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(recovery); registry.initiateRecovery(newOwner);
        assertEq(registry.pendingOwner(), newOwner);
    }

    function test_GriefingDefence_MultipleCancel() public {
        uint256 start = block.timestamp;
        for (uint256 i = 0; i < 3; i++) {
            // jump to a clean window: each cycle is 14 days apart
            vm.warp(start + (i * 14 days) + 1);
            vm.prank(recovery); registry.initiateRecovery(newOwner);

            vm.prank(owner); registry.cancelRecovery();
            // cancelRecovery sets lockoutUntil = block.timestamp + 7 days
            // we are still inside that window — immediate retry must revert
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

    function test_FullRecoveryScenario_OwnerCompromised() public {
        address attacker = address(0xDEAD);
        vm.prank(owner); registry.addOperator(attacker);
        assertTrue(registry.operators(attacker));

        vm.prank(recovery); registry.initiateRecovery(newOwner);
        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(recovery); registry.executeRecovery();
        assertEq(registry.owner(), newOwner);

        vm.prank(newOwner); registry.removeOperator(attacker);
        assertFalse(registry.operators(attacker));

        vm.prank(newOwner); registry.addOperator(operator);
        assertTrue(registry.operators(operator));
    }

    function test_NewOwnerCanActivateAllGates() public {
        vm.prank(recovery); registry.initiateRecovery(newOwner);
        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(recovery); registry.executeRecovery();

        vm.prank(newOwner); registry.addOperator(stranger);
        assertTrue(registry.operators(stranger));
        vm.prank(newOwner); registry.addLegalOperator(legalOp);
        assertTrue(registry.legalOperators(legalOp));
        vm.prank(newOwner); registry.addEntityOperator(entityOp);
        assertTrue(registry.entityOperators(entityOp));
        vm.prank(newOwner); registry.addProofOperator(proofOp);
        assertTrue(registry.proofOperators(proofOp));
    }
}
