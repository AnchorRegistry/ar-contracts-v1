// SPDX-License-Identifier: BUSL-1.1
// Change Date:    March 12, 2028
// Change License: Apache-2.0
// Licensor:       Ian Moore (icmoore)

pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/AnchorRegistry.sol";

/// @title  AnchorRegistryTest
/// @notice Foundry test suite for AnchorRegistry.sol (21 artifact types).
///
///         Sections:
///         1.  Content types (0-8) — CODE through ONCHAIN
///         2.  Content types (9)   — REPORT
///         3.  Content types (10)  — NOTE
///         4.  Lifecycle types (11) — EVENT
///         5.  Transaction types (12) — RECEIPT
///         6.  Gated types (13-15) — LEGAL, ENTITY, PROOF
///         7.  RETRACTION (type 16)
///         8.  REVIEW, VOID, AFFIRMED (types 17-19)
///         9.  OTHER (type 20)
///         10. Access control
///         11. Edge cases & validation
///         12. Tree integrity
///         13. Anchored event & treeId
///         14. Recovery & griefing defence

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
        descriptor:   "ICMOORE-2026-TEST",
        title:        "Test Artifact",
        author:       "Ian Moore",
        treeId:       "tree:test-root"
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
        return AnchorRegistry.AnchorBase({
            artifactType: t,
            manifestHash: h,
            parentHash:   "",
            descriptor:   d,
            title:        "Test Artifact",
            author:       "Test Author",
            treeId:       ""
        });
    }

    function _child(string memory h, string memory parent)
        internal pure returns (AnchorRegistry.AnchorBase memory)
    {
        return AnchorRegistry.AnchorBase({
            artifactType: AnchorRegistry.ArtifactType.CODE,
            manifestHash: h,
            parentHash:   parent,
            descriptor:   "CHILD",
            title:        "Child Artifact",
            author:       "Test Author",
            treeId:       ""
        });
    }

    function _code(string memory arId, string memory h) internal {
        vm.prank(operator);
        registry.registerCode(arId,
            _base(AnchorRegistry.ArtifactType.CODE, h, "TEST"),
            "git:abc", "MIT", "TypeScript", "v1.0.0", "https://test");
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
    // 1. CONTENT TYPES (0-8)
    // =========================================================================

    function test_RegisterCode() public {
        vm.prank(operator);
        registry.registerCode("AR-CODE01", base,
            "git:abc", "MIT", "TypeScript", "v1.0.0", "https://test");
        assertTrue(registry.registered("AR-CODE01"));
    }

    function test_RegisterResearch() public {
        vm.prank(operator);
        registry.registerResearch("AR-RES01",
            _base(AnchorRegistry.ArtifactType.RESEARCH, "sha256:res01", "PAPER"),
            "10.1000/test", "MIT", "Jane Smith, John Doe", "https://arxiv.org/test");
        assertTrue(registry.registered("AR-RES01"));
    }

    function test_RegisterData() public {
        vm.prank(operator);
        registry.registerData("AR-DATA01",
            _base(AnchorRegistry.ArtifactType.DATA, "sha256:data01", "DATASET"),
            "v1.0.0", "CSV", "1000000", "https://schema.org/test", "https://huggingface.co/test");
        assertTrue(registry.registered("AR-DATA01"));
    }

    function test_RegisterModel() public {
        vm.prank(operator);
        registry.registerModel("AR-MDL01",
            _base(AnchorRegistry.ArtifactType.MODEL, "sha256:mdl01", "MODEL"),
            "v1.0.0", "Transformer", "7B", "CommonCrawl", "https://huggingface.co/test");
        assertTrue(registry.registered("AR-MDL01"));
    }

    function test_RegisterAgent() public {
        vm.prank(operator);
        registry.registerAgent("AR-AGT01",
            _base(AnchorRegistry.ArtifactType.AGENT, "sha256:agt01", "AGENT"),
            "v0.1.0", "Python 3.11", "web search, code execution", "https://github.com/test");
        assertTrue(registry.registered("AR-AGT01"));
    }

    function test_RegisterMedia() public {
        vm.prank(operator);
        registry.registerMedia("AR-MED01",
            _base(AnchorRegistry.ArtifactType.MEDIA, "sha256:med01", "MEDIA"),
            "image/png", "PNG", "1920x1080", "USRC17607839", "https://ipfs.io/test");
        assertTrue(registry.registered("AR-MED01"));
    }

    function test_RegisterText() public {
        vm.prank(operator);
        registry.registerText("AR-TXT01",
            _base(AnchorRegistry.ArtifactType.TEXT, "sha256:txt01", "ARTICLE"),
            "978-3-16-148410-0", "O'Reilly Media", "English", "https://medium.com/test");
        assertTrue(registry.registered("AR-TXT01"));
    }

    function test_RegisterPost() public {
        vm.prank(operator);
        registry.registerPost("AR-PST01",
            _base(AnchorRegistry.ArtifactType.POST, "sha256:pst01", "TWEET"),
            "X/Twitter", "1234567890", "2026-03-16", "https://x.com/test");
        assertTrue(registry.registered("AR-PST01"));
    }

    function test_RegisterOnChain_ByAddress() public {
        vm.prank(operator);
        registry.registerOnChain("AR-ONC01",
            _base(AnchorRegistry.ArtifactType.ONCHAIN, "sha256:onc01", "WALLET-CLAIM"),
            "base", "ADDRESS",
            "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266",
            "", "", "22041887",
            "https://basescan.org/address/0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266");
        assertTrue(registry.registered("AR-ONC01"));
    }

    function test_RegisterOnChain_ByTxHash() public {
        vm.prank(operator);
        registry.registerOnChain("AR-ONC02",
            _base(AnchorRegistry.ArtifactType.ONCHAIN, "sha256:onc02", "TX-CLAIM"),
            "ethereum", "TX",
            "",
            "0xabc123def456abc123def456abc123def456abc123def456abc123def456abc123",
            "", "19000000",
            "https://etherscan.io/tx/0xabc123def456");
        assertTrue(registry.registered("AR-ONC02"));
    }

    function test_RegisterOnChain_NFT_BothAddressAndTx() public {
        vm.prank(operator);
        registry.registerOnChain("AR-ONC03",
            _base(AnchorRegistry.ArtifactType.ONCHAIN, "sha256:onc03", "NFT-CLAIM"),
            "ethereum", "NFT",
            "0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d",
            "0xdef789abc123def789abc123def789abc123def789abc123def789abc123def789",
            "1234", "14000000",
            "https://etherscan.io/token/0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d?a=1234");
        assertTrue(registry.registered("AR-ONC03"));
    }

    function test_BackupOperatorCanRegister() public {
        vm.prank(opBackup);
        registry.registerCode("AR-BACK01", base,
            "git:backup", "MIT", "Python", "v2.0.0", "https://test");
        assertTrue(registry.registered("AR-BACK01"));
    }

    // =========================================================================
    // 2. CONTENT TYPES (9) — REPORT
    // =========================================================================

    function test_Report_EnumValue_Is9() public pure {
        assertEq(uint8(AnchorRegistry.ArtifactType.REPORT), 9);
    }

    function test_Report_Consulting_Succeeds() public {
        vm.prank(operator);
        registry.registerReport("AR-RPT01",
            _base(AnchorRegistry.ArtifactType.REPORT, "sha256:rpt01", "HIVE-Q1-2026"),
            "CONSULTING", "Acme Corp", "Q1-STRATEGY-2026", "final",
            "Ian Moore", "Hive Advisory Inc.", "https://portal.hive.com/reports/q1-2026");
        assertTrue(registry.registered("AR-RPT01"));

        (AnchorRegistry.AnchorBase memory b,
         string memory rt, string memory cl, string memory eng,
         string memory ver, string memory auth, string memory inst, string memory url) =
            registry.reportAnchors("AR-RPT01");
        assertEq(uint8(b.artifactType), uint8(AnchorRegistry.ArtifactType.REPORT));
        assertEq(rt,   "CONSULTING");
        assertEq(cl,   "Acme Corp");
        assertEq(eng,  "Q1-STRATEGY-2026");
        assertEq(ver,  "final");
        assertEq(auth, "Ian Moore");
        assertEq(inst, "Hive Advisory Inc.");
        assertEq(url,  "https://portal.hive.com/reports/q1-2026");
    }

    function test_Report_Financial_Succeeds() public {
        vm.prank(operator);
        registry.registerReport("AR-RPT02",
            _base(AnchorRegistry.ArtifactType.REPORT, "sha256:rpt02", "ANNUAL-REPORT-2025"),
            "FINANCIAL", "", "FY2025-ANNUAL", "final",
            "CFO Office", "Acme Corp", "https://acme.com/investors/2025-annual");
        assertTrue(registry.registered("AR-RPT02"));
        (, string memory rt,,,,,,) = registry.reportAnchors("AR-RPT02");
        assertEq(rt, "FINANCIAL");
    }

    function test_Report_Compliance_Succeeds() public {
        vm.prank(operator);
        registry.registerReport("AR-RPT03",
            _base(AnchorRegistry.ArtifactType.REPORT, "sha256:rpt03", "SOC2-TYPE2-2026"),
            "COMPLIANCE", "Acme Corp", "SOC2-2026", "final",
            "Audit Team", "Deloitte", "https://secure.deloitte.com/soc2/acme-2026");
        assertTrue(registry.registered("AR-RPT03"));
        (, string memory rt,,,,,,) = registry.reportAnchors("AR-RPT03");
        assertEq(rt, "COMPLIANCE");
    }

    function test_Report_ESG_Succeeds() public {
        vm.prank(operator);
        registry.registerReport("AR-RPT04",
            _base(AnchorRegistry.ArtifactType.REPORT, "sha256:rpt04", "ESG-REPORT-2025"),
            "ESG", "", "ESG-FY2025", "v1.0",
            "Sustainability Team", "Acme Corp", "https://acme.com/esg/2025");
        assertTrue(registry.registered("AR-RPT04"));
        (, string memory rt,,,,,,) = registry.reportAnchors("AR-RPT04");
        assertEq(rt, "ESG");
    }

    function test_Report_Technical_Succeeds() public {
        vm.prank(operator);
        registry.registerReport("AR-RPT05",
            _base(AnchorRegistry.ArtifactType.REPORT, "sha256:rpt05", "ARCH-REVIEW-2026"),
            "TECHNICAL", "Acme Corp", "ARCH-2026-Q1", "draft",
            "Ian Moore, Jane Smith", "Hive Advisory Inc.", "");
        assertTrue(registry.registered("AR-RPT05"));
        (, string memory rt,, , string memory ver,,, ) = registry.reportAnchors("AR-RPT05");
        assertEq(rt,  "TECHNICAL");
        assertEq(ver, "draft");
    }

    function test_Report_Audit_Succeeds() public {
        vm.prank(operator);
        registry.registerReport("AR-RPT06",
            _base(AnchorRegistry.ArtifactType.REPORT, "sha256:rpt06", "SECURITY-AUDIT-2026"),
            "AUDIT", "AnchorRegistry", "SMART-CONTRACT-AUDIT-V1", "final",
            "Trail of Bits", "Trail of Bits", "https://github.com/trailofbits/publications/anchorregistry");
        assertTrue(registry.registered("AR-RPT06"));
        (, string memory rt,,,,,,) = registry.reportAnchors("AR-RPT06");
        assertEq(rt, "AUDIT");
    }

    function test_Report_Other_Succeeds() public {
        vm.prank(operator);
        registry.registerReport("AR-RPT07",
            _base(AnchorRegistry.ArtifactType.REPORT, "sha256:rpt07", "CUSTOM-REPORT"),
            "OTHER", "Client X", "ENGAGEMENT-001", "v2.1",
            "Author A, Author B", "Firm Y", "https://example.com/report");
        assertTrue(registry.registered("AR-RPT07"));
    }

    function test_Report_MinimalFields_Succeeds() public {
        vm.prank(operator);
        registry.registerReport("AR-RPT08",
            _base(AnchorRegistry.ArtifactType.REPORT, "sha256:rpt08", "REPORT-MINIMAL"),
            "CONSULTING", "", "", "draft", "", "", "");
        assertTrue(registry.registered("AR-RPT08"));
    }

    function test_Report_ByBackupOperator_Succeeds() public {
        vm.prank(opBackup);
        registry.registerReport("AR-RPT09",
            _base(AnchorRegistry.ArtifactType.REPORT, "sha256:rpt09", "REPORT-BACKUP"),
            "FINANCIAL", "Client A", "ENG-002", "final",
            "Jane Smith", "Backup Firm", "");
        assertTrue(registry.registered("AR-RPT09"));
    }

    function test_Report_ByStranger_Reverts() public {
        vm.prank(stranger);
        vm.expectRevert(AnchorRegistry.NotOperator.selector);
        registry.registerReport("AR-RPT10",
            _base(AnchorRegistry.ArtifactType.REPORT, "sha256:rpt10", "REPORT-STRANGER"),
            "CONSULTING", "", "", "draft", "", "", "");
    }

    function test_Report_DuplicateArId_Reverts() public {
        vm.prank(operator);
        registry.registerReport("AR-RPT11",
            _base(AnchorRegistry.ArtifactType.REPORT, "sha256:rpt11", "REPORT"),
            "CONSULTING", "", "ENG-001", "final", "Author", "Firm", "");
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(AnchorRegistry.AlreadyRegistered.selector, "AR-RPT11"));
        registry.registerReport("AR-RPT11",
            _base(AnchorRegistry.ArtifactType.REPORT, "sha256:rpt11b", "REPORT"),
            "CONSULTING", "", "ENG-001", "final", "Author", "Firm", "");
    }

    function test_Report_AnchoredEvent_Emitted() public {
        vm.prank(operator);
        vm.expectEmit(true, true, false, true);
        emit AnchorRegistry.Anchored(
            "AR-RPT12", operator,
            AnchorRegistry.ArtifactType.REPORT,
            "HIVE-Q2-2026", "Test Artifact", "Test Author", "sha256:rpt12", "", ""
        );
        registry.registerReport("AR-RPT12",
            _base(AnchorRegistry.ArtifactType.REPORT, "sha256:rpt12", "HIVE-Q2-2026"),
            "CONSULTING", "Client B", "Q2-2026", "final",
            "Ian Moore", "Hive Advisory Inc.", "https://portal.hive.com/q2-2026");
    }

    function test_Report_AsChildOfResearch_Succeeds() public {
        vm.prank(operator);
        registry.registerResearch("AR-PAPER01",
            _base(AnchorRegistry.ArtifactType.RESEARCH, "sha256:paper01", "BASE-PAPER"),
            "10.1000/base", "MIT", "Ian Moore", "https://arxiv.org/test");

        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.REPORT, "sha256:rpt13", "REPORT-ON-PAPER"
        );
        b.parentHash = "AR-PAPER01";
        vm.prank(operator);
        registry.registerReport("AR-RPT13", b,
            "TECHNICAL", "MIT", "PAPER-ANALYSIS", "v1.0",
            "Jane Smith", "MIT Research", "https://mit.edu/reports/paper-analysis");
        assertTrue(registry.registered("AR-RPT13"));
    }

    function test_Report_EnumShift_AllTypesCorrect() public pure {
        assertEq(uint8(AnchorRegistry.ArtifactType.REPORT),     9);
        assertEq(uint8(AnchorRegistry.ArtifactType.NOTE),       10);
        assertEq(uint8(AnchorRegistry.ArtifactType.EVENT),      11);
        assertEq(uint8(AnchorRegistry.ArtifactType.RECEIPT),    12);
        assertEq(uint8(AnchorRegistry.ArtifactType.LEGAL),      13);
        assertEq(uint8(AnchorRegistry.ArtifactType.ENTITY),     14);
        assertEq(uint8(AnchorRegistry.ArtifactType.PROOF),      15);
        assertEq(uint8(AnchorRegistry.ArtifactType.RETRACTION), 16);
        assertEq(uint8(AnchorRegistry.ArtifactType.REVIEW),     17);
        assertEq(uint8(AnchorRegistry.ArtifactType.VOID),       18);
        assertEq(uint8(AnchorRegistry.ArtifactType.AFFIRMED),   19);
        assertEq(uint8(AnchorRegistry.ArtifactType.OTHER),      20);
    }

    // =========================================================================
    // 3. CONTENT TYPES (10) — NOTE
    // =========================================================================

    function test_Note_EnumValue_Is10() public pure {
        assertEq(uint8(AnchorRegistry.ArtifactType.NOTE), 10);
    }

    function test_Note_Memo_Succeeds() public {
        vm.prank(operator);
        registry.registerNote("AR-NOT01",
            _base(AnchorRegistry.ArtifactType.NOTE, "sha256:not01", "MEMO-2026-03-20"),
            "MEMO", "2026-03-20", "", "");
        assertTrue(registry.registered("AR-NOT01"));

        (AnchorRegistry.AnchorBase memory b,
         string memory nt, string memory d,
         string memory p, string memory url) =
            registry.noteAnchors("AR-NOT01");
        assertEq(uint8(b.artifactType), uint8(AnchorRegistry.ArtifactType.NOTE));
        assertEq(nt,  "MEMO");
        assertEq(d,   "2026-03-20");
        assertEq(p,   "");
        assertEq(url, "");
    }

    function test_Note_Meeting_Succeeds() public {
        vm.prank(operator);
        registry.registerNote("AR-NOT02",
            _base(AnchorRegistry.ArtifactType.NOTE, "sha256:not02", "MEETING-KICKOFF"),
            "MEETING", "2026-03-20", "Ian Moore, Jane Smith, Bob Lee",
            "https://docs.example.com/meeting/kickoff");
        assertTrue(registry.registered("AR-NOT02"));

        (, string memory nt, string memory d, string memory p, string memory url) =
            registry.noteAnchors("AR-NOT02");
        assertEq(nt,  "MEETING");
        assertEq(d,   "2026-03-20");
        assertEq(p,   "Ian Moore, Jane Smith, Bob Lee");
        assertEq(url, "https://docs.example.com/meeting/kickoff");
    }

    function test_Note_Correspondence_Succeeds() public {
        vm.prank(operator);
        registry.registerNote("AR-NOT03",
            _base(AnchorRegistry.ArtifactType.NOTE, "sha256:not03", "EMAIL-THREAD-001"),
            "CORRESPONDENCE", "2026-03-18", "Ian Moore, Acme Corp",
            "https://mail.example.com/thread/001");
        assertTrue(registry.registered("AR-NOT03"));
        (, string memory nt,,,) = registry.noteAnchors("AR-NOT03");
        assertEq(nt, "CORRESPONDENCE");
    }

    function test_Note_Observation_Succeeds() public {
        vm.prank(operator);
        registry.registerNote("AR-NOT04",
            _base(AnchorRegistry.ArtifactType.NOTE, "sha256:not04", "FIELD-OBSERVATION-001"),
            "OBSERVATION", "2026-03-15", "Ian Moore", "");
        assertTrue(registry.registered("AR-NOT04"));
        (, string memory nt,,,) = registry.noteAnchors("AR-NOT04");
        assertEq(nt, "OBSERVATION");
    }

    function test_Note_Field_Succeeds() public {
        vm.prank(operator);
        registry.registerNote("AR-NOT05",
            _base(AnchorRegistry.ArtifactType.NOTE, "sha256:not05", "FIELD-NOTES-SITE-A"),
            "FIELD", "2026-03-10", "Research Team",
            "https://fieldnotes.example.com/site-a");
        assertTrue(registry.registered("AR-NOT05"));
        (, string memory nt,,,) = registry.noteAnchors("AR-NOT05");
        assertEq(nt, "FIELD");
    }

    function test_Note_Other_Succeeds() public {
        vm.prank(operator);
        registry.registerNote("AR-NOT06",
            _base(AnchorRegistry.ArtifactType.NOTE, "sha256:not06", "NOTE-OTHER"),
            "OTHER", "2026-03-20", "", "");
        assertTrue(registry.registered("AR-NOT06"));
    }

    function test_Note_MinimalFields_Succeeds() public {
        vm.prank(operator);
        registry.registerNote("AR-NOT07",
            _base(AnchorRegistry.ArtifactType.NOTE, "sha256:not07", "NOTE-MINIMAL"),
            "MEMO", "2026-03-20", "", "");
        assertTrue(registry.registered("AR-NOT07"));
    }

    function test_Note_ByBackupOperator_Succeeds() public {
        vm.prank(opBackup);
        registry.registerNote("AR-NOT08",
            _base(AnchorRegistry.ArtifactType.NOTE, "sha256:not08", "NOTE-BACKUP"),
            "MEETING", "2026-03-20", "Backup Operator", "");
        assertTrue(registry.registered("AR-NOT08"));
    }

    function test_Note_ByStranger_Reverts() public {
        vm.prank(stranger);
        vm.expectRevert(AnchorRegistry.NotOperator.selector);
        registry.registerNote("AR-NOT09",
            _base(AnchorRegistry.ArtifactType.NOTE, "sha256:not09", "NOTE-STRANGER"),
            "MEMO", "2026-03-20", "", "");
    }

    function test_Note_DuplicateArId_Reverts() public {
        vm.prank(operator);
        registry.registerNote("AR-NOT10",
            _base(AnchorRegistry.ArtifactType.NOTE, "sha256:not10", "NOTE"),
            "MEMO", "2026-03-20", "", "");
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(AnchorRegistry.AlreadyRegistered.selector, "AR-NOT10"));
        registry.registerNote("AR-NOT10",
            _base(AnchorRegistry.ArtifactType.NOTE, "sha256:not10b", "NOTE"),
            "MEMO", "2026-03-20", "", "");
    }

    function test_Note_AnchoredEvent_Emitted() public {
        vm.prank(operator);
        vm.expectEmit(true, true, false, true);
        emit AnchorRegistry.Anchored(
            "AR-NOT11", operator,
            AnchorRegistry.ArtifactType.NOTE,
            "KICKOFF-MEETING-NOTE", "Test Artifact", "Test Author", "sha256:not11", "", ""
        );
        registry.registerNote("AR-NOT11",
            _base(AnchorRegistry.ArtifactType.NOTE, "sha256:not11", "KICKOFF-MEETING-NOTE"),
            "MEETING", "2026-03-20", "Ian Moore, Jane Smith", "");
    }

    function test_Note_AsChildOfReport_Succeeds() public {
        vm.prank(operator);
        registry.registerReport("AR-RPT-PARENT",
            _base(AnchorRegistry.ArtifactType.REPORT, "sha256:rptparent", "BASE-REPORT"),
            "CONSULTING", "Client A", "ENG-001", "final", "Ian Moore", "Hive Advisory", "");

        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.NOTE, "sha256:not12", "NOTE-ON-REPORT"
        );
        b.parentHash = "AR-RPT-PARENT";
        vm.prank(operator);
        registry.registerNote("AR-NOT12", b,
            "MEMO", "2026-03-20", "", "");
        assertTrue(registry.registered("AR-NOT12"));

        (AnchorRegistry.AnchorBase memory stored,,,,) = registry.noteAnchors("AR-NOT12");
        assertEq(stored.parentHash, "AR-RPT-PARENT");
    }

    // =========================================================================
    // 4. LIFECYCLE TYPES (11) — EVENT
    // =========================================================================

    function test_Event_EnumValue_Is11() public pure {
        assertEq(uint8(AnchorRegistry.ArtifactType.EVENT), 11);
    }

    function test_Event_Conference_Succeeds() public {
        vm.prank(operator);
        registry.registerEvent("AR-EVN01",
            _base(AnchorRegistry.ArtifactType.EVENT, "sha256:evn01", "ETHDENVER-2026"),
            "HUMAN", "CONFERENCE", "2026-02-23", "Denver, CO", "ETHDenver",
            "https://ethdenver.com/2026");
        assertTrue(registry.registered("AR-EVN01"));

        (AnchorRegistry.AnchorBase memory b, string memory exec, string memory et,
         string memory ed, string memory loc, string memory orch, string memory url) =
            registry.eventAnchors("AR-EVN01");
        assertEq(uint8(b.artifactType), uint8(AnchorRegistry.ArtifactType.EVENT));
        assertEq(exec, "HUMAN");
        assertEq(et,   "CONFERENCE");
        assertEq(ed,   "2026-02-23");
        assertEq(loc,  "Denver, CO");
        assertEq(orch, "ETHDenver");
        assertEq(url,  "https://ethdenver.com/2026");
    }

    function test_Event_Launch_Succeeds() public {
        vm.prank(operator);
        registry.registerEvent("AR-EVN02",
            _base(AnchorRegistry.ArtifactType.EVENT, "sha256:evn02", "ANCHORREGISTRY-LAUNCH"),
            "HUMAN", "LAUNCH", "2026-03-19", "online", "AnchorRegistry",
            "https://anchorregistry.com");
        assertTrue(registry.registered("AR-EVN02"));
        (,, string memory et,,,,) = registry.eventAnchors("AR-EVN02");
        assertEq(et, "LAUNCH");
    }

    function test_Event_Governance_Succeeds() public {
        vm.prank(operator);
        registry.registerEvent("AR-EVN03",
            _base(AnchorRegistry.ArtifactType.EVENT, "sha256:evn03", "DAO-VOTE-001"),
            "HUMAN", "GOVERNANCE", "2026-03-10", "on-chain", "Uniswap DAO",
            "https://app.uniswap.org/vote/1");
        assertTrue(registry.registered("AR-EVN03"));
        (,, string memory et,,,,) = registry.eventAnchors("AR-EVN03");
        assertEq(et, "GOVERNANCE");
    }

    function test_Event_Performance_Succeeds() public {
        vm.prank(operator);
        registry.registerEvent("AR-EVN04",
            _base(AnchorRegistry.ArtifactType.EVENT, "sha256:evn04", "CONCERT-2026"),
            "HUMAN", "PERFORMANCE", "2026-06-15T20:00:00Z", "Rogers Centre, Toronto", "Live Nation",
            "https://livenation.com/events/test");
        assertTrue(registry.registered("AR-EVN04"));
        (,, string memory et,,,,) = registry.eventAnchors("AR-EVN04");
        assertEq(et, "PERFORMANCE");
    }

    function test_Event_Milestone_Succeeds() public {
        vm.prank(operator);
        registry.registerEvent("AR-EVN05",
            _base(AnchorRegistry.ArtifactType.EVENT, "sha256:evn05", "BASE-1M-TX"),
            "HUMAN", "MILESTONE", "2026-01-01", "on-chain", "Base",
            "https://basescan.org/block/25000000");
        assertTrue(registry.registered("AR-EVN05"));
        (,, string memory et,,,,) = registry.eventAnchors("AR-EVN05");
        assertEq(et, "MILESTONE");
    }

    function test_Event_Competition_Succeeds() public {
        vm.prank(operator);
        registry.registerEvent("AR-EVN06",
            _base(AnchorRegistry.ArtifactType.EVENT, "sha256:evn06", "HACKATHON-2026"),
            "HUMAN", "COMPETITION", "2026-04-01", "online", "ETHGlobal",
            "https://ethglobal.com/events/test");
        assertTrue(registry.registered("AR-EVN06"));
        (,, string memory et,,,,) = registry.eventAnchors("AR-EVN06");
        assertEq(et, "COMPETITION");
    }

    function test_Event_Other_Succeeds() public {
        vm.prank(operator);
        registry.registerEvent("AR-EVN07",
            _base(AnchorRegistry.ArtifactType.EVENT, "sha256:evn07", "EVENT-OTHER"),
            "HUMAN", "OTHER", "2026-05-01", "Vancouver, BC", "Ian Moore",
            "https://test.com");
        assertTrue(registry.registered("AR-EVN07"));
    }

    function test_Event_Machine_Train_Succeeds() public {
        vm.prank(operator);
        registry.registerEvent("AR-EVN-M01",
            _base(AnchorRegistry.ArtifactType.EVENT, "sha256:evnm01", "DEFIMIND-TRAIN-001"),
            "MACHINE", "TRAIN", "2026-03-19T14:23:00Z", "AWS us-east-1", "cron",
            "https://github.com/runs/12345");
        assertTrue(registry.registered("AR-EVN-M01"));

        (AnchorRegistry.AnchorBase memory b, string memory exec, string memory et,
         string memory ed, string memory loc, string memory orch, string memory url) =
            registry.eventAnchors("AR-EVN-M01");
        assertEq(uint8(b.artifactType), uint8(AnchorRegistry.ArtifactType.EVENT));
        assertEq(exec, "MACHINE");
        assertEq(et,   "TRAIN");
        assertEq(ed,   "2026-03-19T14:23:00Z");
        assertEq(loc,  "AWS us-east-1");
        assertEq(orch, "cron");
        assertEq(url,  "https://github.com/runs/12345");
    }

    function test_Event_Machine_Deploy_Succeeds() public {
        vm.prank(operator);
        registry.registerEvent("AR-EVN-M02",
            _base(AnchorRegistry.ArtifactType.EVENT, "sha256:evnm02", "DEFIMIND-DEPLOY-V2"),
            "MACHINE", "DEPLOY", "2026-03-19T15:00:00Z", "Railway prod", "GitHub Actions",
            "https://railway.app/deployments/abc123");
        assertTrue(registry.registered("AR-EVN-M02"));
        (,, string memory et,,,,) = registry.eventAnchors("AR-EVN-M02");
        assertEq(et, "DEPLOY");
    }

    function test_Event_Machine_Pipeline_Succeeds() public {
        vm.prank(operator);
        registry.registerEvent("AR-EVN-M03",
            _base(AnchorRegistry.ArtifactType.EVENT, "sha256:evnm03", "DATA-PIPELINE-RUN-001"),
            "MACHINE", "PIPELINE", "2026-03-19T08:00:00Z", "GitHub Actions", "Airflow",
            "https://airflow.example.com/runs/dag-001");
        assertTrue(registry.registered("AR-EVN-M03"));
        (, string memory exec,,,,, ) = registry.eventAnchors("AR-EVN-M03");
        assertEq(exec, "MACHINE");
    }

    function test_Event_Agent_Deploy_Succeeds() public {
        vm.prank(operator);
        registry.registerEvent("AR-EVN-A01",
            _base(AnchorRegistry.ArtifactType.EVENT, "sha256:evna01", "DEFIMIND-AGENT-DEPLOY"),
            "AGENT", "DEPLOY", "2026-03-19T16:45:00Z", "Railway prod", "DeFiMind v1.2",
            "https://railway.app/deployments/agent-001");
        assertTrue(registry.registered("AR-EVN-A01"));

        (AnchorRegistry.AnchorBase memory b, string memory exec, string memory et,
         string memory ed, string memory loc, string memory orch, string memory url) =
            registry.eventAnchors("AR-EVN-A01");
        assertEq(uint8(b.artifactType), uint8(AnchorRegistry.ArtifactType.EVENT));
        assertEq(exec, "AGENT");
        assertEq(et,   "DEPLOY");
        assertEq(ed,   "2026-03-19T16:45:00Z");
        assertEq(loc,  "Railway prod");
        assertEq(orch, "DeFiMind v1.2");
        assertEq(url,  "https://railway.app/deployments/agent-001");
    }

    function test_Event_Agent_Infer_Succeeds() public {
        vm.prank(operator);
        registry.registerEvent("AR-EVN-A02",
            _base(AnchorRegistry.ArtifactType.EVENT, "sha256:evna02", "DEFIMIND-INFERENCE-001"),
            "AGENT", "INFER", "2026-03-19T17:00:00Z", "AWS us-east-1", "DeFiMind agent v1.2",
            "https://api.defimind.ai/runs/inf-001");
        assertTrue(registry.registered("AR-EVN-A02"));
        (, string memory exec,,,,, ) = registry.eventAnchors("AR-EVN-A02");
        assertEq(exec, "AGENT");
    }

    function test_Event_AllExecutorValues_Stored() public {
        vm.prank(operator);
        registry.registerEvent("AR-EX-H",
            _base(AnchorRegistry.ArtifactType.EVENT, "sha256:exh", "EXEC-HUMAN"),
            "HUMAN", "CONFERENCE", "2026-03-19", "Vancouver, BC", "Ian Moore", "");
        (, string memory execH,,,,, ) = registry.eventAnchors("AR-EX-H");
        assertEq(execH, "HUMAN");

        vm.prank(operator);
        registry.registerEvent("AR-EX-M",
            _base(AnchorRegistry.ArtifactType.EVENT, "sha256:exm", "EXEC-MACHINE"),
            "MACHINE", "BUILD", "2026-03-19T10:00:00Z", "GitHub Actions", "cron", "");
        (, string memory execM,,,,, ) = registry.eventAnchors("AR-EX-M");
        assertEq(execM, "MACHINE");

        vm.prank(operator);
        registry.registerEvent("AR-EX-A",
            _base(AnchorRegistry.ArtifactType.EVENT, "sha256:exa", "EXEC-AGENT"),
            "AGENT", "TASK", "2026-03-19T11:00:00Z", "Railway prod", "DeFiMind v1.2", "");
        (, string memory execA,,,,, ) = registry.eventAnchors("AR-EX-A");
        assertEq(execA, "AGENT");
    }

    function test_Event_Machine_AsChildOfModel_Succeeds() public {
        vm.prank(operator);
        registry.registerData("AR-DS-001",
            _base(AnchorRegistry.ArtifactType.DATA, "sha256:ds001", "TRAINING-DATASET"),
            "v1.0", "Parquet", "10000000", "", "https://huggingface.co/datasets/test");

        AnchorRegistry.AnchorBase memory eb = _base(
            AnchorRegistry.ArtifactType.EVENT, "sha256:train001", "DEFIMIND-TRAIN-RUN"
        );
        eb.parentHash = "AR-DS-001";
        vm.prank(operator);
        registry.registerEvent("AR-TR-001", eb,
            "MACHINE", "TRAIN", "2026-03-19T14:00:00Z",
            "AWS us-east-1", "cron", "https://github.com/runs/train-001");

        AnchorRegistry.AnchorBase memory mb = _base(
            AnchorRegistry.ArtifactType.MODEL, "sha256:mdl002", "DEFIMIND-MODEL-V2"
        );
        mb.parentHash = "AR-TR-001";
        vm.prank(operator);
        registry.registerModel("AR-MDL-002", mb,
            "v2.0", "Transformer", "7B", "AR-DS-001", "https://huggingface.co/defimind/v2");

        assertTrue(registry.registered("AR-DS-001"));
        assertTrue(registry.registered("AR-TR-001"));
        assertTrue(registry.registered("AR-MDL-002"));

        (AnchorRegistry.AnchorBase memory trainBase,,,,,,) = registry.eventAnchors("AR-TR-001");
        assertEq(trainBase.parentHash, "AR-DS-001");

        (AnchorRegistry.AnchorBase memory modelBase,,,,,) = registry.modelAnchors("AR-MDL-002");
        assertEq(modelBase.parentHash, "AR-TR-001");
    }

    function test_Event_MinimalFields_Succeeds() public {
        vm.prank(operator);
        registry.registerEvent("AR-EVN08",
            _base(AnchorRegistry.ArtifactType.EVENT, "sha256:evn08", "EVENT-MINIMAL"),
            "HUMAN", "LAUNCH", "2026-03-19", "", "", "");
        assertTrue(registry.registered("AR-EVN08"));
    }

    function test_Event_ByBackupOperator_Succeeds() public {
        vm.prank(opBackup);
        registry.registerEvent("AR-EVN09",
            _base(AnchorRegistry.ArtifactType.EVENT, "sha256:evn09", "EVENT-BACKUP"),
            "HUMAN", "CONFERENCE", "2026-09-01", "Berlin", "Devcon",
            "https://devcon.org");
        assertTrue(registry.registered("AR-EVN09"));
    }

    function test_Event_ByStranger_Reverts() public {
        vm.prank(stranger);
        vm.expectRevert(AnchorRegistry.NotOperator.selector);
        registry.registerEvent("AR-EVN10",
            _base(AnchorRegistry.ArtifactType.EVENT, "sha256:evn10", "EVENT-STRANGER"),
            "HUMAN", "LAUNCH", "2026-03-19", "online", "Attacker", "https://test.com");
    }

    function test_Event_DuplicateArId_Reverts() public {
        vm.prank(operator);
        registry.registerEvent("AR-EVN11",
            _base(AnchorRegistry.ArtifactType.EVENT, "sha256:evn11", "EVENT"),
            "HUMAN", "LAUNCH", "2026-03-19", "online", "AnchorRegistry", "");
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(AnchorRegistry.AlreadyRegistered.selector, "AR-EVN11"));
        registry.registerEvent("AR-EVN11",
            _base(AnchorRegistry.ArtifactType.EVENT, "sha256:evn11b", "EVENT"),
            "HUMAN", "LAUNCH", "2026-03-19", "online", "AnchorRegistry", "");
    }

    function test_Event_AnchoredEvent_Emitted() public {
        vm.prank(operator);
        vm.expectEmit(true, true, false, true);
        emit AnchorRegistry.Anchored(
            "AR-EVN12", operator,
            AnchorRegistry.ArtifactType.EVENT,
            "ANCHORREGISTRY-LAUNCH", "Test Artifact", "Test Author", "sha256:evn12", "", ""
        );
        registry.registerEvent("AR-EVN12",
            _base(AnchorRegistry.ArtifactType.EVENT, "sha256:evn12", "ANCHORREGISTRY-LAUNCH"),
            "HUMAN", "LAUNCH", "2026-03-19", "online", "AnchorRegistry", "https://anchorregistry.com");
    }

    function test_Event_AsChildOfCode_Succeeds() public {
        _code("AR-PROJECT01", "sha256:project01");
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.EVENT, "sha256:evn13", "LAUNCH-PROJECT01"
        );
        b.parentHash = "AR-PROJECT01";
        vm.prank(operator);
        registry.registerEvent("AR-EVN13", b,
            "HUMAN", "LAUNCH", "2026-03-19", "online", "AnchorRegistry", "https://anchorregistry.com");
        assertTrue(registry.registered("AR-EVN13"));
    }

    // =========================================================================
    // 5. TRANSACTION TYPES (12) — RECEIPT
    // =========================================================================

    function test_Receipt_EnumValue_Is12() public pure {
        assertEq(uint8(AnchorRegistry.ArtifactType.RECEIPT), 12);
    }

    function test_Receipt_Purchase_Succeeds() public {
        vm.prank(operator);
        registry.registerReceipt("AR-RCP01",
            _base(AnchorRegistry.ArtifactType.RECEIPT, "sha256:rcp01", "COUCH-WAYFAIR-2026"),
            "PURCHASE", "Wayfair", "1299.99", "CAD",
            "ORDER-WF-2026-123456", "shopify", "https://wayfair.com/orders/123456");
        assertTrue(registry.registered("AR-RCP01"));

        (AnchorRegistry.AnchorBase memory b, string memory rt, string memory merch,
         string memory amt, string memory curr, string memory oid,,) =
            registry.receiptAnchors("AR-RCP01");
        assertEq(uint8(b.artifactType), uint8(AnchorRegistry.ArtifactType.RECEIPT));
        assertEq(rt,    "PURCHASE");
        assertEq(merch, "Wayfair");
        assertEq(amt,   "1299.99");
        assertEq(curr,  "CAD");
        assertEq(oid,   "ORDER-WF-2026-123456");
    }

    function test_Receipt_Medical_Succeeds() public {
        vm.prank(operator);
        registry.registerReceipt("AR-RCP02",
            _base(AnchorRegistry.ArtifactType.RECEIPT, "sha256:rcp02", "PRESCRIPTION-2026"),
            "MEDICAL", "Shoppers Drug Mart", "48.50", "CAD",
            "RX-2026-789012", "", "");
        assertTrue(registry.registered("AR-RCP02"));
        (, string memory rt,,,,,, ) = registry.receiptAnchors("AR-RCP02");
        assertEq(rt, "MEDICAL");
    }

    function test_Receipt_Financial_Succeeds() public {
        vm.prank(operator);
        registry.registerReceipt("AR-RCP03",
            _base(AnchorRegistry.ArtifactType.RECEIPT, "sha256:rcp03", "WIRE-TRANSFER-2026"),
            "FINANCIAL", "RBC Royal Bank", "50000.00", "CAD",
            "WIRE-2026-456789", "", "");
        assertTrue(registry.registered("AR-RCP03"));
        (, string memory rt,,,,,, ) = registry.receiptAnchors("AR-RCP03");
        assertEq(rt, "FINANCIAL");
    }

    function test_Receipt_Government_Succeeds() public {
        vm.prank(operator);
        registry.registerReceipt("AR-RCP04",
            _base(AnchorRegistry.ArtifactType.RECEIPT, "sha256:rcp04", "TAX-PAYMENT-2026"),
            "GOVERNMENT", "Canada Revenue Agency", "12500.00", "CAD",
            "CRA-2026-TAX-654321", "", "https://cra.canada.ca/receipt/654321");
        assertTrue(registry.registered("AR-RCP04"));
        (, string memory rt,,,,,, ) = registry.receiptAnchors("AR-RCP04");
        assertEq(rt, "GOVERNMENT");
    }

    function test_Receipt_Event_Succeeds() public {
        vm.prank(operator);
        registry.registerReceipt("AR-RCP05",
            _base(AnchorRegistry.ArtifactType.RECEIPT, "sha256:rcp05", "CONCERT-TICKET-2026"),
            "EVENT", "Ticketmaster", "189.50", "CAD",
            "TM-2026-987654", "ticketmaster", "https://ticketmaster.ca/orders/987654");
        assertTrue(registry.registered("AR-RCP05"));
        (, string memory rt,,,,,, ) = registry.receiptAnchors("AR-RCP05");
        assertEq(rt, "EVENT");
    }

    function test_Receipt_Service_Succeeds() public {
        vm.prank(operator);
        registry.registerReceipt("AR-RCP06",
            _base(AnchorRegistry.ArtifactType.RECEIPT, "sha256:rcp06", "PLUMBER-2026"),
            "SERVICE", "Vancouver Plumbing Co.", "450.00", "CAD",
            "INV-2026-111222", "", "");
        assertTrue(registry.registered("AR-RCP06"));
        (, string memory rt,,,,,, ) = registry.receiptAnchors("AR-RCP06");
        assertEq(rt, "SERVICE");
    }

    function test_Receipt_MinimalFields_Succeeds() public {
        vm.prank(operator);
        registry.registerReceipt("AR-RCP07",
            _base(AnchorRegistry.ArtifactType.RECEIPT, "sha256:rcp07", "RECEIPT-MINIMAL"),
            "PURCHASE", "", "99.99", "USD", "ORD-001", "", "");
        assertTrue(registry.registered("AR-RCP07"));
    }

    function test_Receipt_ByStandardOperator_Succeeds() public {
        vm.prank(opBackup);
        registry.registerReceipt("AR-RCP08",
            _base(AnchorRegistry.ArtifactType.RECEIPT, "sha256:rcp08", "RECEIPT-BACKUP"),
            "PURCHASE", "Amazon", "299.99", "USD", "AMZ-2026-001", "amazon", "");
        assertTrue(registry.registered("AR-RCP08"));
    }

    function test_Receipt_ByStranger_Reverts() public {
        vm.prank(stranger);
        vm.expectRevert(AnchorRegistry.NotOperator.selector);
        registry.registerReceipt("AR-RCP09",
            _base(AnchorRegistry.ArtifactType.RECEIPT, "sha256:rcp09", "RECEIPT-STRANGER"),
            "PURCHASE", "Amazon", "299.99", "USD", "AMZ-001", "", "");
    }

    function test_Receipt_AnchoredEvent_Emitted() public {
        vm.prank(operator);
        vm.expectEmit(true, true, false, true);
        emit AnchorRegistry.Anchored(
            "AR-RCP10", operator,
            AnchorRegistry.ArtifactType.RECEIPT,
            "LAPTOP-BESTBUY-2026", "Test Artifact", "Test Author", "sha256:rcp10", "", ""
        );
        registry.registerReceipt("AR-RCP10",
            _base(AnchorRegistry.ArtifactType.RECEIPT, "sha256:rcp10", "LAPTOP-BESTBUY-2026"),
            "PURCHASE", "Best Buy", "1899.99", "CAD", "BB-2026-555666", "bestbuy", "");
    }

    function test_Receipt_DuplicateArId_Reverts() public {
        vm.prank(operator);
        registry.registerReceipt("AR-RCP11",
            _base(AnchorRegistry.ArtifactType.RECEIPT, "sha256:rcp11", "RECEIPT"),
            "PURCHASE", "Merchant", "100.00", "USD", "ORD-001", "", "");
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(AnchorRegistry.AlreadyRegistered.selector, "AR-RCP11"));
        registry.registerReceipt("AR-RCP11",
            _base(AnchorRegistry.ArtifactType.RECEIPT, "sha256:rcp11b", "RECEIPT"),
            "PURCHASE", "Merchant", "100.00", "USD", "ORD-001", "", "");
    }

    function test_Receipt_AsChildOfCode_Succeeds() public {
        _code("AR-PRODUCT01", "sha256:product01");
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.RECEIPT, "sha256:rcp12", "PURCHASE-PRODUCT01"
        );
        b.parentHash = "AR-PRODUCT01";
        vm.prank(operator);
        registry.registerReceipt("AR-RCP12", b,
            "PURCHASE", "Shopify Store", "49.99", "USD", "SHP-2026-001", "shopify", "");
        assertTrue(registry.registered("AR-RCP12"));
    }

    // =========================================================================
    // 6. GATED TYPES (13-15) — suppressed at launch
    // =========================================================================

    function test_Legal_SuppressedAtLaunch() public view {
        assertFalse(registry.legalOperators(operator));
        assertFalse(registry.legalOperators(legalOp));
    }

    function test_Legal_ByLegalOperator_Succeeds() public {
        vm.prank(owner); registry.addLegalOperator(legalOp);
        vm.prank(legalOp);
        registry.registerLegal("AR-LGL01",
            _base(AnchorRegistry.ArtifactType.LEGAL, "sha256:lgl01", "TRADEMARK"),
            "PATENT_APPLICATION", "Canada", "Ian Moore", "2026-03-16",
            "https://cipo.ic.gc.ca/test");
        assertTrue(registry.registered("AR-LGL01"));
    }

    function test_Legal_ByStandardOperator_Reverts() public {
        vm.prank(operator);
        vm.expectRevert(AnchorRegistry.NotLegalOperator.selector);
        registry.registerLegal("AR-LGL02",
            _base(AnchorRegistry.ArtifactType.LEGAL, "sha256:lgl02", "TRADEMARK"),
            "CONTRACT", "Delaware", "Acme Corp, Ian Moore", "2026-03-16", "https://test");
    }

    function test_Legal_RemovedOperator_Reverts() public {
        vm.prank(owner); registry.addLegalOperator(legalOp);
        vm.prank(owner); registry.removeLegalOperator(legalOp);
        vm.prank(legalOp);
        vm.expectRevert(AnchorRegistry.NotLegalOperator.selector);
        registry.registerLegal("AR-LGL03",
            _base(AnchorRegistry.ArtifactType.LEGAL, "sha256:lgl03", "TRADEMARK"),
            "NDA", "UK", "Party A, Party B", "2026-01-01", "https://test");
    }

    function test_Entity_SuppressedAtLaunch() public view {
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

    function test_Proof_SuppressedAtLaunch() public view {
        assertFalse(registry.proofOperators(operator));
        assertFalse(registry.proofOperators(proofOp));
    }

    function test_Proof_ZK_ByProofOperator_Succeeds() public {
        vm.prank(owner); registry.addProofOperator(proofOp);
        vm.prank(proofOp);
        registry.registerProof("AR-PRF01",
            _base(AnchorRegistry.ArtifactType.PROOF, "sha256:prf01", "ZKP-2026"),
            "ZK_PROOF", "Groth16",
            "circuit-v1-sha256", "sha256:vkeyhash01",
            "", "",
            "https://verifier.anchorregistry.ai/AR-PRF01", "",
            "sha256:proofhash01");
        assertTrue(registry.registered("AR-PRF01"));
    }

    function test_Proof_Audit_ByProofOperator_Succeeds() public {
        vm.prank(owner); registry.addProofOperator(proofOp);
        vm.prank(proofOp);
        registry.registerProof("AR-PRF04",
            _base(AnchorRegistry.ArtifactType.PROOF, "sha256:prf04", "AUDIT-2026"),
            "SECURITY_AUDIT", "Manual Review",
            "", "",
            "Trail of Bits", "AnchorRegistry.sol v1.0",
            "", "https://github.com/trailofbits/publications/test",
            "sha256:auditreport01");
        assertTrue(registry.registered("AR-PRF04"));
    }

    function test_Proof_ByStandardOperator_Reverts() public {
        vm.prank(operator);
        vm.expectRevert(AnchorRegistry.NotProofOperator.selector);
        registry.registerProof("AR-PRF02",
            _base(AnchorRegistry.ArtifactType.PROOF, "sha256:prf02", "ZKP"),
            "ZK_PROOF", "PLONK",
            "circuit-v2", "sha256:vkey02",
            "", "", "https://test", "", "sha256:proof02");
    }

    function test_Proof_RemovedOperator_Reverts() public {
        vm.prank(owner); registry.addProofOperator(proofOp);
        vm.prank(owner); registry.removeProofOperator(proofOp);
        vm.prank(proofOp);
        vm.expectRevert(AnchorRegistry.NotProofOperator.selector);
        registry.registerProof("AR-PRF03",
            _base(AnchorRegistry.ArtifactType.PROOF, "sha256:prf03", "ZKP"),
            "ZK_PROOF", "STARKs",
            "circuit-v3", "sha256:vkey03",
            "", "", "https://test", "", "sha256:proof03");
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
    // 7. RETRACTION (type 16)
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

        (, string memory retTargetArId,, string memory retReplacedBy) = registry.retractionAnchors("AR-RET02");
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
        registry.registerCode("AR-V1", _child("sha256:v1", "AR-ROOT"),
            "git:v1", "MIT", "Python", "v1.0.0", "https://test");
        vm.prank(operator);
        registry.registerCode("AR-CHILD", _child("sha256:child", "AR-V1"),
            "git:child", "MIT", "Python", "v1.0.1", "https://test");
        vm.prank(operator);
        registry.registerCode("AR-V2", _child("sha256:v2", "AR-ROOT"),
            "git:v2", "MIT", "Python", "v2.0.0", "https://test");

        AnchorRegistry.AnchorBase memory retb = _base(
            AnchorRegistry.ArtifactType.RETRACTION, "sha256:ret", "RETRACTION-V1"
        );
        retb.parentHash = "AR-V1";
        vm.prank(operator);
        registry.registerRetraction("AR-RET", retb, "AR-V1", "Superseded by V2", "AR-V2");

        (,,, string memory retReplacedBy) = registry.retractionAnchors("AR-RET");
        assertEq(retReplacedBy, "AR-V2");

        (AnchorRegistry.AnchorBase memory childBase,,,,,) = registry.codeAnchors("AR-CHILD");
        assertEq(childBase.parentHash, "AR-V1");
    }

    // =========================================================================
    // 8. REVIEW, VOID, AFFIRMED (types 17-19)
    // =========================================================================

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
    // 9. OTHER (type 20)
    // =========================================================================

    function test_RegisterOther() public {
        vm.prank(operator);
        registry.registerOther("AR-OTH01",
            _base(AnchorRegistry.ArtifactType.OTHER, "sha256:oth01", "COURSE"),
            "course", "Thinkific", "https://thinkific.com/test", "DeFi 101");
        assertTrue(registry.registered("AR-OTH01"));
    }

    function test_Other_EnumValue_Is20() public pure {
        assertEq(uint8(AnchorRegistry.ArtifactType.OTHER), 20);
    }

    // =========================================================================
    // 10. ACCESS CONTROL
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
        registry.registerCode("AR-FAIL01", base,
            "git:fail", "MIT", "Python", "v1.0.0", "https://test");
    }

    function test_OwnerCannotRegisterContent() public {
        vm.prank(owner);
        vm.expectRevert(AnchorRegistry.NotOperator.selector);
        registry.registerCode("AR-FAIL02", base,
            "git:fail", "MIT", "Python", "v1.0.0", "https://test");
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
        registry.registerCode("AR-FAIL03", base,
            "git:fail", "MIT", "Python", "v1.0.0", "https://test");
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
    // 11. EDGE CASES & VALIDATION
    // =========================================================================

    function test_EmptyArId_Reverts() public {
        vm.prank(operator);
        vm.expectRevert(AnchorRegistry.EmptyArId.selector);
        registry.registerCode("", base,
            "git:abc", "MIT", "Python", "v1.0.0", "https://test");
    }

    function test_EmptyManifestHash_Reverts() public {
        vm.prank(operator);
        vm.expectRevert(AnchorRegistry.EmptyManifestHash.selector);
        registry.registerCode("AR-FAIL04",
            _base(AnchorRegistry.ArtifactType.CODE, "", "TEST"),
            "git:abc", "MIT", "Python", "v1.0.0", "https://test");
    }

    function test_DuplicateArId_Reverts() public {
        _code("AR-DUP01", "sha256:first");
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(AnchorRegistry.AlreadyRegistered.selector, "AR-DUP01"));
        registry.registerCode("AR-DUP01", base,
            "git:abc", "MIT", "Python", "v1.0.0", "https://test");
    }

    function test_DuplicateArIdAcrossTypes_Reverts() public {
        _code("AR-CROSS01", "sha256:cross01");
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(AnchorRegistry.AlreadyRegistered.selector, "AR-CROSS01"));
        registry.registerText("AR-CROSS01",
            _base(AnchorRegistry.ArtifactType.TEXT, "sha256:cross02", "TEXT"),
            "", "", "", "https://test");
    }

    function test_InvalidParentHash_Reverts() public {
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(AnchorRegistry.InvalidParent.selector, "AR-DOESNOTEXIST"));
        registry.registerCode("AR-CHILD01", _child("sha256:child01", "AR-DOESNOTEXIST"),
            "git:child", "MIT", "Python", "v1.0.0", "https://test");
    }

    // =========================================================================
    // 12. TREE INTEGRITY
    // =========================================================================

    function test_ValidParentHash_Succeeds() public {
        _code("AR-ROOT01", "sha256:root");
        vm.prank(operator);
        registry.registerCode("AR-CHILD02", _child("sha256:child", "AR-ROOT01"),
            "git:child", "MIT", "Rust", "v0.1.0", "https://test");
        assertTrue(registry.registered("AR-CHILD02"));
    }

    function test_DeepLineageTree() public {
        _code("AR-L0", "sha256:l0");
        for (uint256 i = 1; i <= 5; i++) {
            string memory parent = string(abi.encodePacked("AR-L", vm.toString(i - 1)));
            string memory id     = string(abi.encodePacked("AR-L", vm.toString(i)));
            string memory h      = string(abi.encodePacked("sha256:l", vm.toString(i)));
            vm.prank(operator);
            registry.registerCode(id, _child(h, parent),
                "git:l", "MIT", "Go", "v1.0.0", "https://test");
        }
        assertTrue(registry.registered("AR-L5"));
    }

    function test_MultipleChildrenSameParent() public {
        _code("AR-PARENT01", "sha256:parent01");
        for (uint256 i = 0; i < 5; i++) {
            string memory id = string(abi.encodePacked("AR-SIB-", vm.toString(i)));
            string memory h  = string(abi.encodePacked("sha256:sib", vm.toString(i)));
            vm.prank(operator);
            registry.registerCode(id, _child(h, "AR-PARENT01"),
                "git:sib", "MIT", "TypeScript", "v1.0.0", "https://test");
            assertTrue(registry.registered(id));
        }
    }

    function test_CrossTypeParentChild() public {
        _code("AR-CODE-PARENT", "sha256:codeparent");
        AnchorRegistry.AnchorBase memory b = AnchorRegistry.AnchorBase({
            artifactType: AnchorRegistry.ArtifactType.RESEARCH,
            manifestHash: "sha256:res-child",
            parentHash:   "AR-CODE-PARENT",
            descriptor:   "PAPER-CHILD",
            title:        "Research Child",
            author:       "Test Author",
            treeId:       ""
        });
        vm.prank(operator);
        registry.registerResearch("AR-RES-CHILD", b,
            "10.1000/test", "MIT", "", "https://arxiv.org/test");
        assertTrue(registry.registered("AR-RES-CHILD"));
    }

    function test_EventAsChildOfCode_TreeIntegrity() public {
        _code("AR-TREE-ROOT", "sha256:treeroot");
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.EVENT, "sha256:tree-evt", "LAUNCH-TREE-ROOT"
        );
        b.parentHash = "AR-TREE-ROOT";
        vm.prank(operator);
        registry.registerEvent("AR-TREE-EVT", b,
            "HUMAN", "LAUNCH", "2026-03-19", "online", "AnchorRegistry", "https://anchorregistry.com");
        assertTrue(registry.registered("AR-TREE-EVT"));

        (AnchorRegistry.AnchorBase memory evtBase,,,,,,) = registry.eventAnchors("AR-TREE-EVT");
        assertEq(evtBase.parentHash, "AR-TREE-ROOT");
    }

    function test_ReportAsChildOfResearch_TreeIntegrity() public {
        vm.prank(operator);
        registry.registerResearch("AR-RESEARCH-ROOT",
            _base(AnchorRegistry.ArtifactType.RESEARCH, "sha256:resroot", "BASE-RESEARCH"),
            "10.1000/base", "MIT", "Ian Moore", "https://arxiv.org/test");

        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.REPORT, "sha256:rpt-child", "REPORT-ON-RESEARCH"
        );
        b.parentHash = "AR-RESEARCH-ROOT";
        vm.prank(operator);
        registry.registerReport("AR-RPT-CHILD", b,
            "TECHNICAL", "", "RESEARCH-ANALYSIS", "v1.0",
            "Jane Smith", "Hive Advisory", "");

        assertTrue(registry.registered("AR-RPT-CHILD"));
        (AnchorRegistry.AnchorBase memory rptBase,,,,,,,) = registry.reportAnchors("AR-RPT-CHILD");
        assertEq(rptBase.parentHash, "AR-RESEARCH-ROOT");
    }

    function test_NoteAsChildOfMeeting_TreeIntegrity() public {
        vm.prank(operator);
        registry.registerNote("AR-MEETING-ROOT",
            _base(AnchorRegistry.ArtifactType.NOTE, "sha256:meetroot", "KICKOFF-MEETING"),
            "MEETING", "2026-03-20", "Ian Moore, Jane Smith", "");

        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.NOTE, "sha256:followup", "FOLLOWUP-MEMO"
        );
        b.parentHash = "AR-MEETING-ROOT";
        vm.prank(operator);
        registry.registerNote("AR-MEMO-CHILD", b,
            "MEMO", "2026-03-21", "Ian Moore", "");

        assertTrue(registry.registered("AR-MEMO-CHILD"));
        (AnchorRegistry.AnchorBase memory noteBase,,,,) = registry.noteAnchors("AR-MEMO-CHILD");
        assertEq(noteBase.parentHash, "AR-MEETING-ROOT");
    }

    // =========================================================================
    // 13. ANCHORED EVENT & TREEID
    // =========================================================================

    function test_AR_TREE_ID_Constant() public view {
        assertEq(registry.AR_TREE_ID(), "ar-operator-v1");
    }

    function test_TreeId_StoredInBase_Code() public {
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.CODE, "sha256:tid01", "TREEID-TEST"
        );
        b.treeId = "sha256:tree-fingerprint-abc123";
        vm.prank(operator);
        registry.registerCode("AR-TID01", b,
            "git:tid", "MIT", "Python", "v1.0.0", "https://test");
        (AnchorRegistry.AnchorBase memory stored,,,,,) = registry.codeAnchors("AR-TID01");
        assertEq(stored.treeId, "sha256:tree-fingerprint-abc123");
    }

    function test_TreeId_StoredInBase_Note() public {
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.NOTE, "sha256:tid-note", "TREEID-NOTE"
        );
        b.treeId = "sha256:note-tree-fingerprint";
        vm.prank(operator);
        registry.registerNote("AR-TID-NOTE", b,
            "MEMO", "2026-03-20", "", "");
        (AnchorRegistry.AnchorBase memory stored,,,,) = registry.noteAnchors("AR-TID-NOTE");
        assertEq(stored.treeId, "sha256:note-tree-fingerprint");
    }

    function test_TreeId_StoredInBase_Report() public {
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.REPORT, "sha256:tid02", "TREEID-REPORT"
        );
        b.treeId = "sha256:hive-tree-fingerprint";
        vm.prank(operator);
        registry.registerReport("AR-TID02", b,
            "CONSULTING", "Client A", "ENG-001", "final",
            "Ian Moore", "Hive Advisory Inc.", "");
        (AnchorRegistry.AnchorBase memory stored,,,,,,,) = registry.reportAnchors("AR-TID02");
        assertEq(stored.treeId, "sha256:hive-tree-fingerprint");
    }

    function test_TreeId_EmptyString_Allowed() public {
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.CODE, "sha256:tid03", "TREEID-EMPTY"
        );
        b.treeId = "";
        vm.prank(operator);
        registry.registerCode("AR-TID03", b,
            "git:tid", "MIT", "Python", "v1.0.0", "https://test");
        (AnchorRegistry.AnchorBase memory stored,,,,,) = registry.codeAnchors("AR-TID03");
        assertEq(stored.treeId, "");
    }

    function test_TreeId_EmittedInAnchoredEvent() public {
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.CODE, "sha256:tid04", "TREEID-EVENT-TEST"
        );
        b.treeId = "sha256:my-tree-fingerprint";
        vm.prank(operator);
        vm.expectEmit(true, true, false, true);
        emit AnchorRegistry.Anchored(
            "AR-TID04", operator,
            AnchorRegistry.ArtifactType.CODE,
            "TREEID-EVENT-TEST", "Test Artifact", "Test Author",
            "sha256:tid04", "", "sha256:my-tree-fingerprint"
        );
        registry.registerCode("AR-TID04", b,
            "git:tid", "MIT", "Python", "v1.0.0", "https://test");
    }

    function test_AR_TREE_ID_UsedForReviewAnchor() public {
        _code("AR-DISPUTE-TARGET", "sha256:disputetarget");
        AnchorRegistry.AnchorBase memory b = _base(
            AnchorRegistry.ArtifactType.REVIEW, "sha256:ar-review", "AR-DISPUTE-REVIEW"
        );
        b.treeId = registry.AR_TREE_ID();
        b.parentHash = "AR-DISPUTE-TARGET";
        vm.prank(operator);
        registry.registerReview("AR-DISP-REV01", b,
            "AR-DISPUTE-TARGET", "FALSE_AUTHORSHIP", "https://anchorregistry.com/disputes/1");
        (AnchorRegistry.AnchorBase memory stored,,,) = registry.reviewAnchors("AR-DISP-REV01");
        assertEq(stored.treeId, "ar-operator-v1");
    }

    function test_AnchoredEvent_OnRegisterCode() public {
        vm.prank(operator);
        vm.expectEmit(true, true, false, true);
        emit AnchorRegistry.Anchored(
            "AR-EVT01", operator,
            AnchorRegistry.ArtifactType.CODE,
            "ICMOORE-2026-TEST", "Test Artifact", "Ian Moore", "sha256:abc123", "", "tree:test-root"
        );
        registry.registerCode("AR-EVT01", base,
            "git:abc", "MIT", "TypeScript", "v1.0.0", "https://test");
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
    // 14. RECOVERY & GRIEFING DEFENCE
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
            vm.warp(start + (i * 14 days) + 1);
            vm.prank(recovery); registry.initiateRecovery(newOwner);
            vm.prank(owner); registry.cancelRecovery();
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
