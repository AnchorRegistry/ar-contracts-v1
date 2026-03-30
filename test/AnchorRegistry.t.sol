// SPDX-License-Identifier: BUSL-1.1
// Change Date:    March 12, 2028
// Change License: Apache-2.0
// Licensor:       Ian Moore (icmoore)

pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/AnchorRegistry.sol";

/// @title  AnchorRegistryTest
/// @notice Foundry test suite for AnchorRegistry.sol (22 artifact types).
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
///         9.  BILLING (type 20) — ACCOUNT
///         10. OTHER (type 21)
///         11. Access control
///         12. Edge cases & validation
///         13. Tree integrity
///         14. Anchored event & treeId
///         15. Recovery & griefing defence

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

    AnchorBase base = AnchorBase({
        artifactType: ArtifactType.CODE,
        manifestHash: "sha256:abc123",
        parentArId:   "",
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
        ArtifactType t,
        string memory h,
        string memory d
    ) internal pure returns (AnchorBase memory) {
        return AnchorBase({
            artifactType: t,
            manifestHash: h,
            parentArId:   "",
            descriptor:   d,
            title:        "Test Artifact",
            author:       "Test Author",
            treeId:       ""
        });
    }

    function _child(string memory h, string memory parent)
        internal pure returns (AnchorBase memory)
    {
        return AnchorBase({
            artifactType: ArtifactType.CODE,
            manifestHash: h,
            parentArId:   parent,
            descriptor:   "CHILD",
            title:        "Child Artifact",
            author:       "Test Author",
            treeId:       ""
        });
    }

    function _code(string memory arId, string memory h) internal {
        vm.prank(operator);
        registry.registerContent(arId,
            _base(ArtifactType.CODE, h, "TEST"),
            abi.encode("git:abc", "MIT", "TypeScript", "v1.0.0", "https://test"));
    }

    function _review(string memory reviewArId, string memory targetArId) internal {
        _code(targetArId, string(abi.encodePacked("sha256:", targetArId)));
        AnchorBase memory b = _base(
            ArtifactType.REVIEW,
            string(abi.encodePacked("sha256:review-", reviewArId)),
            string(abi.encodePacked("REVIEW-", reviewArId))
        );
        b.parentArId = targetArId;
        vm.prank(operator);
        registry.registerTargeted(reviewArId, b, targetArId, abi.encode("FALSE_AUTHORSHIP", "https://test"));
    }

    // =========================================================================
    // 1. CONTENT TYPES (0-8)
    // =========================================================================

    function test_RegisterCode() public {
        vm.prank(operator);
        registry.registerContent("AR-CODE01", base,
            abi.encode("git:abc", "MIT", "TypeScript", "v1.0.0", "https://test"));
        assertTrue(registry.registered("AR-CODE01"));
    }

    function test_RegisterResearch() public {
        vm.prank(operator);
        registry.registerContent("AR-RES01",
            _base(ArtifactType.RESEARCH, "sha256:res01", "PAPER"),
            abi.encode("10.1000/test", "MIT", "Jane Smith, John Doe", "https://arxiv.org/test"));
        assertTrue(registry.registered("AR-RES01"));
    }

    function test_RegisterData() public {
        vm.prank(operator);
        registry.registerContent("AR-DATA01",
            _base(ArtifactType.DATA, "sha256:data01", "DATASET"),
            abi.encode("v1.0.0", "CSV", "1000000", "https://schema.org/test", "https://huggingface.co/test"));
        assertTrue(registry.registered("AR-DATA01"));
    }

    function test_RegisterModel() public {
        vm.prank(operator);
        registry.registerContent("AR-MDL01",
            _base(ArtifactType.MODEL, "sha256:mdl01", "MODEL"),
            abi.encode("v1.0.0", "Transformer", "7B", "CommonCrawl", "https://huggingface.co/test"));
        assertTrue(registry.registered("AR-MDL01"));
    }

    function test_RegisterAgent() public {
        vm.prank(operator);
        registry.registerContent("AR-AGT01",
            _base(ArtifactType.AGENT, "sha256:agt01", "AGENT"),
            abi.encode("v0.1.0", "Python 3.11", "web search, code execution", "https://github.com/test"));
        assertTrue(registry.registered("AR-AGT01"));
    }

    function test_RegisterMedia() public {
        vm.prank(operator);
        registry.registerContent("AR-MED01",
            _base(ArtifactType.MEDIA, "sha256:med01", "MEDIA"),
            abi.encode("image/png", "PNG", "1920x1080", "USRC17607839", "https://ipfs.io/test"));
        assertTrue(registry.registered("AR-MED01"));
    }

    function test_RegisterText() public {
        vm.prank(operator);
        registry.registerContent("AR-TXT01",
            _base(ArtifactType.TEXT, "sha256:txt01", "ARTICLE"),
            abi.encode("978-3-16-148410-0", "O'Reilly Media", "English", "https://medium.com/test"));
        assertTrue(registry.registered("AR-TXT01"));
    }

    function test_RegisterPost() public {
        vm.prank(operator);
        registry.registerContent("AR-PST01",
            _base(ArtifactType.POST, "sha256:pst01", "TWEET"),
            abi.encode("X/Twitter", "1234567890", "2026-03-16", "https://x.com/test"));
        assertTrue(registry.registered("AR-PST01"));
    }

    function test_RegisterOnChain_ByAddress() public {
        vm.prank(operator);
        registry.registerContent("AR-ONC01",
            _base(ArtifactType.ONCHAIN, "sha256:onc01", "WALLET-CLAIM"),
            abi.encode("base", "ADDRESS",
            "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266",
            "", "", "22041887",
            "https://basescan.org/address/0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"));
        assertTrue(registry.registered("AR-ONC01"));
    }

    function test_RegisterOnChain_ByTxHash() public {
        vm.prank(operator);
        registry.registerContent("AR-ONC02",
            _base(ArtifactType.ONCHAIN, "sha256:onc02", "TX-CLAIM"),
            abi.encode("ethereum", "TX",
            "",
            "0xabc123def456abc123def456abc123def456abc123def456abc123def456abc123",
            "", "19000000",
            "https://etherscan.io/tx/0xabc123def456"));
        assertTrue(registry.registered("AR-ONC02"));
    }

    function test_RegisterOnChain_NFT_BothAddressAndTx() public {
        vm.prank(operator);
        registry.registerContent("AR-ONC03",
            _base(ArtifactType.ONCHAIN, "sha256:onc03", "NFT-CLAIM"),
            abi.encode("ethereum", "NFT",
            "0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d",
            "0xdef789abc123def789abc123def789abc123def789abc123def789abc123def789",
            "1234", "14000000",
            "https://etherscan.io/token/0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d?a=1234"));
        assertTrue(registry.registered("AR-ONC03"));
    }

    function test_BackupOperatorCanRegister() public {
        vm.prank(opBackup);
        registry.registerContent("AR-BACK01", base,
            abi.encode("git:backup", "MIT", "Python", "v2.0.0", "https://test"));
        assertTrue(registry.registered("AR-BACK01"));
    }

    // =========================================================================
    // 2. CONTENT TYPES (9) — REPORT
    // =========================================================================

    function test_Report_EnumValue_Is9() public pure {
        assertEq(uint8(ArtifactType.REPORT), 9);
    }

    function test_Report_Consulting_Succeeds() public {
        vm.prank(operator);
        registry.registerContent("AR-RPT01",
            _base(ArtifactType.REPORT, "sha256:rpt01", "HIVE-Q1-2026"),
            abi.encode("CONSULTING", "Acme Corp", "Q1-STRATEGY-2026", "final",
            "Ian Moore", "Hive Advisory Inc.", "https://portal.hive.com/reports/q1-2026"));
        assertTrue(registry.registered("AR-RPT01"));

        (string memory rt, string memory cl, string memory eng,
         string memory ver, string memory auth, string memory inst, string memory url) =
            abi.decode(registry.getAnchorData("AR-RPT01"), (string, string, string, string, string, string, string));
        assertEq(uint8(registry.anchorTypes("AR-RPT01")), uint8(ArtifactType.REPORT));
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
        registry.registerContent("AR-RPT02",
            _base(ArtifactType.REPORT, "sha256:rpt02", "ANNUAL-REPORT-2025"),
            abi.encode("FINANCIAL", "", "FY2025-ANNUAL", "final",
            "CFO Office", "Acme Corp", "https://acme.com/investors/2025-annual"));
        assertTrue(registry.registered("AR-RPT02"));
        (string memory rt,,,,,,) = abi.decode(registry.getAnchorData("AR-RPT02"), (string, string, string, string, string, string, string));
        assertEq(rt, "FINANCIAL");
    }

    function test_Report_Compliance_Succeeds() public {
        vm.prank(operator);
        registry.registerContent("AR-RPT03",
            _base(ArtifactType.REPORT, "sha256:rpt03", "SOC2-TYPE2-2026"),
            abi.encode("COMPLIANCE", "Acme Corp", "SOC2-2026", "final",
            "Audit Team", "Deloitte", "https://secure.deloitte.com/soc2/acme-2026"));
        assertTrue(registry.registered("AR-RPT03"));
        (string memory rt,,,,,,) = abi.decode(registry.getAnchorData("AR-RPT03"), (string, string, string, string, string, string, string));
        assertEq(rt, "COMPLIANCE");
    }

    function test_Report_ESG_Succeeds() public {
        vm.prank(operator);
        registry.registerContent("AR-RPT04",
            _base(ArtifactType.REPORT, "sha256:rpt04", "ESG-REPORT-2025"),
            abi.encode("ESG", "", "ESG-FY2025", "v1.0",
            "Sustainability Team", "Acme Corp", "https://acme.com/esg/2025"));
        assertTrue(registry.registered("AR-RPT04"));
        (string memory rt,,,,,,) = abi.decode(registry.getAnchorData("AR-RPT04"), (string, string, string, string, string, string, string));
        assertEq(rt, "ESG");
    }

    function test_Report_Technical_Succeeds() public {
        vm.prank(operator);
        registry.registerContent("AR-RPT05",
            _base(ArtifactType.REPORT, "sha256:rpt05", "ARCH-REVIEW-2026"),
            abi.encode("TECHNICAL", "Acme Corp", "ARCH-2026-Q1", "draft",
            "Ian Moore, Jane Smith", "Hive Advisory Inc.", ""));
        assertTrue(registry.registered("AR-RPT05"));
        (string memory rt,,, string memory ver,,,) = abi.decode(registry.getAnchorData("AR-RPT05"), (string, string, string, string, string, string, string));
        assertEq(rt,  "TECHNICAL");
        assertEq(ver, "draft");
    }

    function test_Report_Audit_Succeeds() public {
        vm.prank(operator);
        registry.registerContent("AR-RPT06",
            _base(ArtifactType.REPORT, "sha256:rpt06", "SECURITY-AUDIT-2026"),
            abi.encode("AUDIT", "AnchorRegistry", "SMART-CONTRACT-AUDIT-V1", "final",
            "Trail of Bits", "Trail of Bits", "https://github.com/trailofbits/publications/anchorregistry"));
        assertTrue(registry.registered("AR-RPT06"));
        (string memory rt,,,,,,) = abi.decode(registry.getAnchorData("AR-RPT06"), (string, string, string, string, string, string, string));
        assertEq(rt, "AUDIT");
    }

    function test_Report_Other_Succeeds() public {
        vm.prank(operator);
        registry.registerContent("AR-RPT07",
            _base(ArtifactType.REPORT, "sha256:rpt07", "CUSTOM-REPORT"),
            abi.encode("OTHER", "Client X", "ENGAGEMENT-001", "v2.1",
            "Author A, Author B", "Firm Y", "https://example.com/report"));
        assertTrue(registry.registered("AR-RPT07"));
    }

    function test_Report_MinimalFields_Succeeds() public {
        vm.prank(operator);
        registry.registerContent("AR-RPT08",
            _base(ArtifactType.REPORT, "sha256:rpt08", "REPORT-MINIMAL"),
            abi.encode("CONSULTING", "", "", "draft", "", "", ""));
        assertTrue(registry.registered("AR-RPT08"));
    }

    function test_Report_ByBackupOperator_Succeeds() public {
        vm.prank(opBackup);
        registry.registerContent("AR-RPT09",
            _base(ArtifactType.REPORT, "sha256:rpt09", "REPORT-BACKUP"),
            abi.encode("FINANCIAL", "Client A", "ENG-002", "final",
            "Jane Smith", "Backup Firm", ""));
        assertTrue(registry.registered("AR-RPT09"));
    }

    function test_Report_ByStranger_Reverts() public {
        vm.prank(stranger);
        vm.expectRevert(AnchorRegistry.NotOperator.selector);
        registry.registerContent("AR-RPT10",
            _base(ArtifactType.REPORT, "sha256:rpt10", "REPORT-STRANGER"),
            abi.encode("CONSULTING", "", "", "draft", "", "", ""));
    }

    function test_Report_DuplicateArId_Reverts() public {
        vm.prank(operator);
        registry.registerContent("AR-RPT11",
            _base(ArtifactType.REPORT, "sha256:rpt11", "REPORT"),
            abi.encode("CONSULTING", "", "ENG-001", "final", "Author", "Firm", ""));
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(AnchorRegistry.AlreadyRegistered.selector, "AR-RPT11"));
        registry.registerContent("AR-RPT11",
            _base(ArtifactType.REPORT, "sha256:rpt11b", "REPORT"),
            abi.encode("CONSULTING", "", "ENG-001", "final", "Author", "Firm", ""));
    }

    function test_Report_AnchoredEvent_Emitted() public {
        vm.prank(operator);
        vm.expectEmit(true, true, false, true);
        emit AnchorRegistry.Anchored(
            "AR-RPT12", operator,
            ArtifactType.REPORT,
            "AR-RPT12",
            "HIVE-Q2-2026", "Test Artifact", "Test Author", "sha256:rpt12", "", ""
        );
        registry.registerContent("AR-RPT12",
            _base(ArtifactType.REPORT, "sha256:rpt12", "HIVE-Q2-2026"),
            abi.encode("CONSULTING", "Client B", "Q2-2026", "final",
            "Ian Moore", "Hive Advisory Inc.", "https://portal.hive.com/q2-2026"));
    }

    function test_Report_AsChildOfResearch_Succeeds() public {
        vm.prank(operator);
        registry.registerContent("AR-PAPER01",
            _base(ArtifactType.RESEARCH, "sha256:paper01", "BASE-PAPER"),
            abi.encode("10.1000/base", "MIT", "Ian Moore", "https://arxiv.org/test"));

        AnchorBase memory b = _base(
            ArtifactType.REPORT, "sha256:rpt13", "REPORT-ON-PAPER"
        );
        b.parentArId = "AR-PAPER01";
        vm.prank(operator);
        registry.registerContent("AR-RPT13", b,
            abi.encode("TECHNICAL", "MIT", "PAPER-ANALYSIS", "v1.0",
            "Jane Smith", "MIT Research", "https://mit.edu/reports/paper-analysis"));
        assertTrue(registry.registered("AR-RPT13"));
    }

    function test_Report_EnumShift_AllTypesCorrect() public pure {
        assertEq(uint8(ArtifactType.REPORT),     9);
        assertEq(uint8(ArtifactType.NOTE),       10);
        assertEq(uint8(ArtifactType.WEBSITE),    11);
        assertEq(uint8(ArtifactType.EVENT),      12);
        assertEq(uint8(ArtifactType.RECEIPT),    13);
        assertEq(uint8(ArtifactType.LEGAL),      14);
        assertEq(uint8(ArtifactType.ENTITY),     15);
        assertEq(uint8(ArtifactType.PROOF),      16);
        assertEq(uint8(ArtifactType.RETRACTION), 17);
        assertEq(uint8(ArtifactType.REVIEW),     18);
        assertEq(uint8(ArtifactType.VOID),       19);
        assertEq(uint8(ArtifactType.AFFIRMED),   20);
        assertEq(uint8(ArtifactType.ACCOUNT),    21);
        assertEq(uint8(ArtifactType.OTHER),      22);
    }

    // =========================================================================
    // 3. CONTENT TYPES (10) — NOTE
    // =========================================================================

    function test_Note_EnumValue_Is10() public pure {
        assertEq(uint8(ArtifactType.NOTE), 10);
    }

    function test_Note_Memo_Succeeds() public {
        vm.prank(operator);
        registry.registerContent("AR-NOT01",
            _base(ArtifactType.NOTE, "sha256:not01", "MEMO-2026-03-20"),
            abi.encode("MEMO", "2026-03-20", "", ""));
        assertTrue(registry.registered("AR-NOT01"));

        (string memory nt, string memory d,
         string memory p, string memory url) =
            abi.decode(registry.getAnchorData("AR-NOT01"), (string, string, string, string));
        assertEq(uint8(registry.anchorTypes("AR-NOT01")), uint8(ArtifactType.NOTE));
        assertEq(nt,  "MEMO");
        assertEq(d,   "2026-03-20");
        assertEq(p,   "");
        assertEq(url, "");
    }

    function test_Note_Meeting_Succeeds() public {
        vm.prank(operator);
        registry.registerContent("AR-NOT02",
            _base(ArtifactType.NOTE, "sha256:not02", "MEETING-KICKOFF"),
            abi.encode("MEETING", "2026-03-20", "Ian Moore, Jane Smith, Bob Lee",
            "https://docs.example.com/meeting/kickoff"));
        assertTrue(registry.registered("AR-NOT02"));

        (string memory nt, string memory d, string memory p, string memory url) =
            abi.decode(registry.getAnchorData("AR-NOT02"), (string, string, string, string));
        assertEq(nt,  "MEETING");
        assertEq(d,   "2026-03-20");
        assertEq(p,   "Ian Moore, Jane Smith, Bob Lee");
        assertEq(url, "https://docs.example.com/meeting/kickoff");
    }

    function test_Note_Correspondence_Succeeds() public {
        vm.prank(operator);
        registry.registerContent("AR-NOT03",
            _base(ArtifactType.NOTE, "sha256:not03", "EMAIL-THREAD-001"),
            abi.encode("CORRESPONDENCE", "2026-03-18", "Ian Moore, Acme Corp",
            "https://mail.example.com/thread/001"));
        assertTrue(registry.registered("AR-NOT03"));
        (string memory nt,,,) = abi.decode(registry.getAnchorData("AR-NOT03"), (string, string, string, string));
        assertEq(nt, "CORRESPONDENCE");
    }

    function test_Note_Observation_Succeeds() public {
        vm.prank(operator);
        registry.registerContent("AR-NOT04",
            _base(ArtifactType.NOTE, "sha256:not04", "FIELD-OBSERVATION-001"),
            abi.encode("OBSERVATION", "2026-03-15", "Ian Moore", ""));
        assertTrue(registry.registered("AR-NOT04"));
        (string memory nt,,,) = abi.decode(registry.getAnchorData("AR-NOT04"), (string, string, string, string));
        assertEq(nt, "OBSERVATION");
    }

    function test_Note_Field_Succeeds() public {
        vm.prank(operator);
        registry.registerContent("AR-NOT05",
            _base(ArtifactType.NOTE, "sha256:not05", "FIELD-NOTES-SITE-A"),
            abi.encode("FIELD", "2026-03-10", "Research Team",
            "https://fieldnotes.example.com/site-a"));
        assertTrue(registry.registered("AR-NOT05"));
        (string memory nt,,,) = abi.decode(registry.getAnchorData("AR-NOT05"), (string, string, string, string));
        assertEq(nt, "FIELD");
    }

    function test_Note_Other_Succeeds() public {
        vm.prank(operator);
        registry.registerContent("AR-NOT06",
            _base(ArtifactType.NOTE, "sha256:not06", "NOTE-OTHER"),
            abi.encode("OTHER", "2026-03-20", "", ""));
        assertTrue(registry.registered("AR-NOT06"));
    }

    function test_Note_MinimalFields_Succeeds() public {
        vm.prank(operator);
        registry.registerContent("AR-NOT07",
            _base(ArtifactType.NOTE, "sha256:not07", "NOTE-MINIMAL"),
            abi.encode("MEMO", "2026-03-20", "", ""));
        assertTrue(registry.registered("AR-NOT07"));
    }

    function test_Note_ByBackupOperator_Succeeds() public {
        vm.prank(opBackup);
        registry.registerContent("AR-NOT08",
            _base(ArtifactType.NOTE, "sha256:not08", "NOTE-BACKUP"),
            abi.encode("MEETING", "2026-03-20", "Backup Operator", ""));
        assertTrue(registry.registered("AR-NOT08"));
    }

    function test_Note_ByStranger_Reverts() public {
        vm.prank(stranger);
        vm.expectRevert(AnchorRegistry.NotOperator.selector);
        registry.registerContent("AR-NOT09",
            _base(ArtifactType.NOTE, "sha256:not09", "NOTE-STRANGER"),
            abi.encode("MEMO", "2026-03-20", "", ""));
    }

    function test_Note_DuplicateArId_Reverts() public {
        vm.prank(operator);
        registry.registerContent("AR-NOT10",
            _base(ArtifactType.NOTE, "sha256:not10", "NOTE"),
            abi.encode("MEMO", "2026-03-20", "", ""));
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(AnchorRegistry.AlreadyRegistered.selector, "AR-NOT10"));
        registry.registerContent("AR-NOT10",
            _base(ArtifactType.NOTE, "sha256:not10b", "NOTE"),
            abi.encode("MEMO", "2026-03-20", "", ""));
    }

    function test_Note_AnchoredEvent_Emitted() public {
        vm.prank(operator);
        vm.expectEmit(true, true, false, true);
        emit AnchorRegistry.Anchored(
            "AR-NOT11", operator,
            ArtifactType.NOTE,
            "AR-NOT11",
            "KICKOFF-MEETING-NOTE", "Test Artifact", "Test Author", "sha256:not11", "", ""
        );
        registry.registerContent("AR-NOT11",
            _base(ArtifactType.NOTE, "sha256:not11", "KICKOFF-MEETING-NOTE"),
            abi.encode("MEETING", "2026-03-20", "Ian Moore, Jane Smith", ""));
    }

    function test_Note_AsChildOfReport_Succeeds() public {
        vm.prank(operator);
        registry.registerContent("AR-RPT-PARENT",
            _base(ArtifactType.REPORT, "sha256:rptparent", "BASE-REPORT"),
            abi.encode("CONSULTING", "Client A", "ENG-001", "final", "Ian Moore", "Hive Advisory", ""));

        AnchorBase memory b = _base(
            ArtifactType.NOTE, "sha256:not12", "NOTE-ON-REPORT"
        );
        b.parentArId = "AR-RPT-PARENT";
        vm.prank(operator);
        registry.registerContent("AR-NOT12", b,
            abi.encode("MEMO", "2026-03-20", "", ""));
        assertTrue(registry.registered("AR-NOT12"));
    }

    // =========================================================================
    // 4. LIFECYCLE TYPES (11) — EVENT
    // =========================================================================

    function test_Event_EnumValue_Is12() public pure {
        assertEq(uint8(ArtifactType.EVENT), 12);
    }

    function test_Event_Conference_Succeeds() public {
        vm.prank(operator);
        registry.registerContent("AR-EVN01",
            _base(ArtifactType.EVENT, "sha256:evn01", "ETHDENVER-2026"),
            abi.encode("HUMAN", "CONFERENCE", "2026-02-23", "Denver, CO", "ETHDenver",
            "https://ethdenver.com/2026"));
        assertTrue(registry.registered("AR-EVN01"));

        (string memory exec, string memory et,
         string memory ed, string memory loc, string memory orch, string memory url) =
            abi.decode(registry.getAnchorData("AR-EVN01"), (string, string, string, string, string, string));
        assertEq(uint8(registry.anchorTypes("AR-EVN01")), uint8(ArtifactType.EVENT));
        assertEq(exec, "HUMAN");
        assertEq(et,   "CONFERENCE");
        assertEq(ed,   "2026-02-23");
        assertEq(loc,  "Denver, CO");
        assertEq(orch, "ETHDenver");
        assertEq(url,  "https://ethdenver.com/2026");
    }

    function test_Event_Launch_Succeeds() public {
        vm.prank(operator);
        registry.registerContent("AR-EVN02",
            _base(ArtifactType.EVENT, "sha256:evn02", "ANCHORREGISTRY-LAUNCH"),
            abi.encode("HUMAN", "LAUNCH", "2026-03-19", "online", "AnchorRegistry",
            "https://anchorregistry.com"));
        assertTrue(registry.registered("AR-EVN02"));
        (, string memory et,,,,) = abi.decode(registry.getAnchorData("AR-EVN02"), (string, string, string, string, string, string));
        assertEq(et, "LAUNCH");
    }

    function test_Event_Governance_Succeeds() public {
        vm.prank(operator);
        registry.registerContent("AR-EVN03",
            _base(ArtifactType.EVENT, "sha256:evn03", "DAO-VOTE-001"),
            abi.encode("HUMAN", "GOVERNANCE", "2026-03-10", "on-chain", "Uniswap DAO",
            "https://app.uniswap.org/vote/1"));
        assertTrue(registry.registered("AR-EVN03"));
        (, string memory et,,,,) = abi.decode(registry.getAnchorData("AR-EVN03"), (string, string, string, string, string, string));
        assertEq(et, "GOVERNANCE");
    }

    function test_Event_Performance_Succeeds() public {
        vm.prank(operator);
        registry.registerContent("AR-EVN04",
            _base(ArtifactType.EVENT, "sha256:evn04", "CONCERT-2026"),
            abi.encode("HUMAN", "PERFORMANCE", "2026-06-15T20:00:00Z", "Rogers Centre, Toronto", "Live Nation",
            "https://livenation.com/events/test"));
        assertTrue(registry.registered("AR-EVN04"));
        (, string memory et,,,,) = abi.decode(registry.getAnchorData("AR-EVN04"), (string, string, string, string, string, string));
        assertEq(et, "PERFORMANCE");
    }

    function test_Event_Milestone_Succeeds() public {
        vm.prank(operator);
        registry.registerContent("AR-EVN05",
            _base(ArtifactType.EVENT, "sha256:evn05", "BASE-1M-TX"),
            abi.encode("HUMAN", "MILESTONE", "2026-01-01", "on-chain", "Base",
            "https://basescan.org/block/25000000"));
        assertTrue(registry.registered("AR-EVN05"));
        (, string memory et,,,,) = abi.decode(registry.getAnchorData("AR-EVN05"), (string, string, string, string, string, string));
        assertEq(et, "MILESTONE");
    }

    function test_Event_Competition_Succeeds() public {
        vm.prank(operator);
        registry.registerContent("AR-EVN06",
            _base(ArtifactType.EVENT, "sha256:evn06", "HACKATHON-2026"),
            abi.encode("HUMAN", "COMPETITION", "2026-04-01", "online", "ETHGlobal",
            "https://ethglobal.com/events/test"));
        assertTrue(registry.registered("AR-EVN06"));
        (, string memory et,,,,) = abi.decode(registry.getAnchorData("AR-EVN06"), (string, string, string, string, string, string));
        assertEq(et, "COMPETITION");
    }

    function test_Event_Other_Succeeds() public {
        vm.prank(operator);
        registry.registerContent("AR-EVN07",
            _base(ArtifactType.EVENT, "sha256:evn07", "EVENT-OTHER"),
            abi.encode("HUMAN", "OTHER", "2026-05-01", "Vancouver, BC", "Ian Moore",
            "https://test.com"));
        assertTrue(registry.registered("AR-EVN07"));
    }

    function test_Event_Machine_Train_Succeeds() public {
        vm.prank(operator);
        registry.registerContent("AR-EVN-M01",
            _base(ArtifactType.EVENT, "sha256:evnm01", "DEFIMIND-TRAIN-001"),
            abi.encode("MACHINE", "TRAIN", "2026-03-19T14:23:00Z", "AWS us-east-1", "cron",
            "https://github.com/runs/12345"));
        assertTrue(registry.registered("AR-EVN-M01"));

        (string memory exec, string memory et,
         string memory ed, string memory loc, string memory orch, string memory url) =
            abi.decode(registry.getAnchorData("AR-EVN-M01"), (string, string, string, string, string, string));
        assertEq(uint8(registry.anchorTypes("AR-EVN-M01")), uint8(ArtifactType.EVENT));
        assertEq(exec, "MACHINE");
        assertEq(et,   "TRAIN");
        assertEq(ed,   "2026-03-19T14:23:00Z");
        assertEq(loc,  "AWS us-east-1");
        assertEq(orch, "cron");
        assertEq(url,  "https://github.com/runs/12345");
    }

    function test_Event_Machine_Deploy_Succeeds() public {
        vm.prank(operator);
        registry.registerContent("AR-EVN-M02",
            _base(ArtifactType.EVENT, "sha256:evnm02", "DEFIMIND-DEPLOY-V2"),
            abi.encode("MACHINE", "DEPLOY", "2026-03-19T15:00:00Z", "Railway prod", "GitHub Actions",
            "https://railway.app/deployments/abc123"));
        assertTrue(registry.registered("AR-EVN-M02"));
        (, string memory et,,,,) = abi.decode(registry.getAnchorData("AR-EVN-M02"), (string, string, string, string, string, string));
        assertEq(et, "DEPLOY");
    }

    function test_Event_Machine_Pipeline_Succeeds() public {
        vm.prank(operator);
        registry.registerContent("AR-EVN-M03",
            _base(ArtifactType.EVENT, "sha256:evnm03", "DATA-PIPELINE-RUN-001"),
            abi.encode("MACHINE", "PIPELINE", "2026-03-19T08:00:00Z", "GitHub Actions", "Airflow",
            "https://airflow.example.com/runs/dag-001"));
        assertTrue(registry.registered("AR-EVN-M03"));
        (string memory exec,,,,,) = abi.decode(registry.getAnchorData("AR-EVN-M03"), (string, string, string, string, string, string));
        assertEq(exec, "MACHINE");
    }

    function test_Event_Agent_Deploy_Succeeds() public {
        vm.prank(operator);
        registry.registerContent("AR-EVN-A01",
            _base(ArtifactType.EVENT, "sha256:evna01", "DEFIMIND-AGENT-DEPLOY"),
            abi.encode("AGENT", "DEPLOY", "2026-03-19T16:45:00Z", "Railway prod", "DeFiMind v1.2",
            "https://railway.app/deployments/agent-001"));
        assertTrue(registry.registered("AR-EVN-A01"));

        (string memory exec, string memory et,
         string memory ed, string memory loc, string memory orch, string memory url) =
            abi.decode(registry.getAnchorData("AR-EVN-A01"), (string, string, string, string, string, string));
        assertEq(uint8(registry.anchorTypes("AR-EVN-A01")), uint8(ArtifactType.EVENT));
        assertEq(exec, "AGENT");
        assertEq(et,   "DEPLOY");
        assertEq(ed,   "2026-03-19T16:45:00Z");
        assertEq(loc,  "Railway prod");
        assertEq(orch, "DeFiMind v1.2");
        assertEq(url,  "https://railway.app/deployments/agent-001");
    }

    function test_Event_Agent_Infer_Succeeds() public {
        vm.prank(operator);
        registry.registerContent("AR-EVN-A02",
            _base(ArtifactType.EVENT, "sha256:evna02", "DEFIMIND-INFERENCE-001"),
            abi.encode("AGENT", "INFER", "2026-03-19T17:00:00Z", "AWS us-east-1", "DeFiMind agent v1.2",
            "https://api.defimind.ai/runs/inf-001"));
        assertTrue(registry.registered("AR-EVN-A02"));
        (string memory exec,,,,,) = abi.decode(registry.getAnchorData("AR-EVN-A02"), (string, string, string, string, string, string));
        assertEq(exec, "AGENT");
    }

    function test_Event_AllExecutorValues_Stored() public {
        vm.prank(operator);
        registry.registerContent("AR-EX-H",
            _base(ArtifactType.EVENT, "sha256:exh", "EXEC-HUMAN"),
            abi.encode("HUMAN", "CONFERENCE", "2026-03-19", "Vancouver, BC", "Ian Moore", ""));
        (string memory execH,,,,,) = abi.decode(registry.getAnchorData("AR-EX-H"), (string, string, string, string, string, string));
        assertEq(execH, "HUMAN");

        vm.prank(operator);
        registry.registerContent("AR-EX-M",
            _base(ArtifactType.EVENT, "sha256:exm", "EXEC-MACHINE"),
            abi.encode("MACHINE", "BUILD", "2026-03-19T10:00:00Z", "GitHub Actions", "cron", ""));
        (string memory execM,,,,,) = abi.decode(registry.getAnchorData("AR-EX-M"), (string, string, string, string, string, string));
        assertEq(execM, "MACHINE");

        vm.prank(operator);
        registry.registerContent("AR-EX-A",
            _base(ArtifactType.EVENT, "sha256:exa", "EXEC-AGENT"),
            abi.encode("AGENT", "TASK", "2026-03-19T11:00:00Z", "Railway prod", "DeFiMind v1.2", ""));
        (string memory execA,,,,,) = abi.decode(registry.getAnchorData("AR-EX-A"), (string, string, string, string, string, string));
        assertEq(execA, "AGENT");
    }

    function test_Event_Machine_AsChildOfModel_Succeeds() public {
        vm.prank(operator);
        registry.registerContent("AR-DS-001",
            _base(ArtifactType.DATA, "sha256:ds001", "TRAINING-DATASET"),
            abi.encode("v1.0", "Parquet", "10000000", "", "https://huggingface.co/datasets/test"));

        AnchorBase memory eb = _base(
            ArtifactType.EVENT, "sha256:train001", "DEFIMIND-TRAIN-RUN"
        );
        eb.parentArId = "AR-DS-001";
        vm.prank(operator);
        registry.registerContent("AR-TR-001", eb,
            abi.encode("MACHINE", "TRAIN", "2026-03-19T14:00:00Z",
            "AWS us-east-1", "cron", "https://github.com/runs/train-001"));

        AnchorBase memory mb = _base(
            ArtifactType.MODEL, "sha256:mdl002", "DEFIMIND-MODEL-V2"
        );
        mb.parentArId = "AR-TR-001";
        vm.prank(operator);
        registry.registerContent("AR-MDL-002", mb,
            abi.encode("v2.0", "Transformer", "7B", "AR-DS-001", "https://huggingface.co/defimind/v2"));

        assertTrue(registry.registered("AR-DS-001"));
        assertTrue(registry.registered("AR-TR-001"));
        assertTrue(registry.registered("AR-MDL-002"));
    }

    function test_Event_MinimalFields_Succeeds() public {
        vm.prank(operator);
        registry.registerContent("AR-EVN08",
            _base(ArtifactType.EVENT, "sha256:evn08", "EVENT-MINIMAL"),
            abi.encode("HUMAN", "LAUNCH", "2026-03-19", "", "", ""));
        assertTrue(registry.registered("AR-EVN08"));
    }

    function test_Event_ByBackupOperator_Succeeds() public {
        vm.prank(opBackup);
        registry.registerContent("AR-EVN09",
            _base(ArtifactType.EVENT, "sha256:evn09", "EVENT-BACKUP"),
            abi.encode("HUMAN", "CONFERENCE", "2026-09-01", "Berlin", "Devcon",
            "https://devcon.org"));
        assertTrue(registry.registered("AR-EVN09"));
    }

    function test_Event_ByStranger_Reverts() public {
        vm.prank(stranger);
        vm.expectRevert(AnchorRegistry.NotOperator.selector);
        registry.registerContent("AR-EVN10",
            _base(ArtifactType.EVENT, "sha256:evn10", "EVENT-STRANGER"),
            abi.encode("HUMAN", "LAUNCH", "2026-03-19", "online", "Attacker", "https://test.com"));
    }

    function test_Event_DuplicateArId_Reverts() public {
        vm.prank(operator);
        registry.registerContent("AR-EVN11",
            _base(ArtifactType.EVENT, "sha256:evn11", "EVENT"),
            abi.encode("HUMAN", "LAUNCH", "2026-03-19", "online", "AnchorRegistry", ""));
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(AnchorRegistry.AlreadyRegistered.selector, "AR-EVN11"));
        registry.registerContent("AR-EVN11",
            _base(ArtifactType.EVENT, "sha256:evn11b", "EVENT"),
            abi.encode("HUMAN", "LAUNCH", "2026-03-19", "online", "AnchorRegistry", ""));
    }

    function test_Event_AnchoredEvent_Emitted() public {
        vm.prank(operator);
        vm.expectEmit(true, true, false, true);
        emit AnchorRegistry.Anchored(
            "AR-EVN12", operator,
            ArtifactType.EVENT,
            "AR-EVN12",
            "ANCHORREGISTRY-LAUNCH", "Test Artifact", "Test Author", "sha256:evn12", "", ""
        );
        registry.registerContent("AR-EVN12",
            _base(ArtifactType.EVENT, "sha256:evn12", "ANCHORREGISTRY-LAUNCH"),
            abi.encode("HUMAN", "LAUNCH", "2026-03-19", "online", "AnchorRegistry", "https://anchorregistry.com"));
    }

    function test_Event_AsChildOfCode_Succeeds() public {
        _code("AR-PROJECT01", "sha256:project01");
        AnchorBase memory b = _base(
            ArtifactType.EVENT, "sha256:evn13", "LAUNCH-PROJECT01"
        );
        b.parentArId = "AR-PROJECT01";
        vm.prank(operator);
        registry.registerContent("AR-EVN13", b,
            abi.encode("HUMAN", "LAUNCH", "2026-03-19", "online", "AnchorRegistry", "https://anchorregistry.com"));
        assertTrue(registry.registered("AR-EVN13"));
    }

    // =========================================================================
    // 5. TRANSACTION TYPES (12) — RECEIPT
    // =========================================================================

    function test_Receipt_EnumValue_Is13() public pure {
        assertEq(uint8(ArtifactType.RECEIPT), 13);
    }

    function test_Receipt_Purchase_Succeeds() public {
        vm.prank(operator);
        registry.registerContent("AR-RCP01",
            _base(ArtifactType.RECEIPT, "sha256:rcp01", "COUCH-WAYFAIR-2026"),
            abi.encode("PURCHASE", "Wayfair", "1299.99", "CAD",
            "ORDER-WF-2026-123456", "shopify", "https://wayfair.com/orders/123456"));
        assertTrue(registry.registered("AR-RCP01"));

        (string memory rt, string memory merch,
         string memory amt, string memory curr, string memory oid,,) =
            abi.decode(registry.getAnchorData("AR-RCP01"), (string, string, string, string, string, string, string));
        assertEq(uint8(registry.anchorTypes("AR-RCP01")), uint8(ArtifactType.RECEIPT));
        assertEq(rt,    "PURCHASE");
        assertEq(merch, "Wayfair");
        assertEq(amt,   "1299.99");
        assertEq(curr,  "CAD");
        assertEq(oid,   "ORDER-WF-2026-123456");
    }

    function test_Receipt_Medical_Succeeds() public {
        vm.prank(operator);
        registry.registerContent("AR-RCP02",
            _base(ArtifactType.RECEIPT, "sha256:rcp02", "PRESCRIPTION-2026"),
            abi.encode("MEDICAL", "Shoppers Drug Mart", "48.50", "CAD",
            "RX-2026-789012", "", ""));
        assertTrue(registry.registered("AR-RCP02"));
        (string memory rt,,,,,,) = abi.decode(registry.getAnchorData("AR-RCP02"), (string, string, string, string, string, string, string));
        assertEq(rt, "MEDICAL");
    }

    function test_Receipt_Financial_Succeeds() public {
        vm.prank(operator);
        registry.registerContent("AR-RCP03",
            _base(ArtifactType.RECEIPT, "sha256:rcp03", "WIRE-TRANSFER-2026"),
            abi.encode("FINANCIAL", "RBC Royal Bank", "50000.00", "CAD",
            "WIRE-2026-456789", "", ""));
        assertTrue(registry.registered("AR-RCP03"));
        (string memory rt,,,,,,) = abi.decode(registry.getAnchorData("AR-RCP03"), (string, string, string, string, string, string, string));
        assertEq(rt, "FINANCIAL");
    }

    function test_Receipt_Government_Succeeds() public {
        vm.prank(operator);
        registry.registerContent("AR-RCP04",
            _base(ArtifactType.RECEIPT, "sha256:rcp04", "TAX-PAYMENT-2026"),
            abi.encode("GOVERNMENT", "Canada Revenue Agency", "12500.00", "CAD",
            "CRA-2026-TAX-654321", "", "https://cra.canada.ca/receipt/654321"));
        assertTrue(registry.registered("AR-RCP04"));
        (string memory rt,,,,,,) = abi.decode(registry.getAnchorData("AR-RCP04"), (string, string, string, string, string, string, string));
        assertEq(rt, "GOVERNMENT");
    }

    function test_Receipt_Event_Succeeds() public {
        vm.prank(operator);
        registry.registerContent("AR-RCP05",
            _base(ArtifactType.RECEIPT, "sha256:rcp05", "CONCERT-TICKET-2026"),
            abi.encode("EVENT", "Ticketmaster", "189.50", "CAD",
            "TM-2026-987654", "ticketmaster", "https://ticketmaster.ca/orders/987654"));
        assertTrue(registry.registered("AR-RCP05"));
        (string memory rt,,,,,,) = abi.decode(registry.getAnchorData("AR-RCP05"), (string, string, string, string, string, string, string));
        assertEq(rt, "EVENT");
    }

    function test_Receipt_Service_Succeeds() public {
        vm.prank(operator);
        registry.registerContent("AR-RCP06",
            _base(ArtifactType.RECEIPT, "sha256:rcp06", "PLUMBER-2026"),
            abi.encode("SERVICE", "Vancouver Plumbing Co.", "450.00", "CAD",
            "INV-2026-111222", "", ""));
        assertTrue(registry.registered("AR-RCP06"));
        (string memory rt,,,,,,) = abi.decode(registry.getAnchorData("AR-RCP06"), (string, string, string, string, string, string, string));
        assertEq(rt, "SERVICE");
    }

    function test_Receipt_MinimalFields_Succeeds() public {
        vm.prank(operator);
        registry.registerContent("AR-RCP07",
            _base(ArtifactType.RECEIPT, "sha256:rcp07", "RECEIPT-MINIMAL"),
            abi.encode("PURCHASE", "", "99.99", "USD", "ORD-001", "", ""));
        assertTrue(registry.registered("AR-RCP07"));
    }

    function test_Receipt_ByStandardOperator_Succeeds() public {
        vm.prank(opBackup);
        registry.registerContent("AR-RCP08",
            _base(ArtifactType.RECEIPT, "sha256:rcp08", "RECEIPT-BACKUP"),
            abi.encode("PURCHASE", "Amazon", "299.99", "USD", "AMZ-2026-001", "amazon", ""));
        assertTrue(registry.registered("AR-RCP08"));
    }

    function test_Receipt_ByStranger_Reverts() public {
        vm.prank(stranger);
        vm.expectRevert(AnchorRegistry.NotOperator.selector);
        registry.registerContent("AR-RCP09",
            _base(ArtifactType.RECEIPT, "sha256:rcp09", "RECEIPT-STRANGER"),
            abi.encode("PURCHASE", "Amazon", "299.99", "USD", "AMZ-001", "", ""));
    }

    function test_Receipt_AnchoredEvent_Emitted() public {
        vm.prank(operator);
        vm.expectEmit(true, true, false, true);
        emit AnchorRegistry.Anchored(
            "AR-RCP10", operator,
            ArtifactType.RECEIPT,
            "AR-RCP10",
            "LAPTOP-BESTBUY-2026", "Test Artifact", "Test Author", "sha256:rcp10", "", ""
        );
        registry.registerContent("AR-RCP10",
            _base(ArtifactType.RECEIPT, "sha256:rcp10", "LAPTOP-BESTBUY-2026"),
            abi.encode("PURCHASE", "Best Buy", "1899.99", "CAD", "BB-2026-555666", "bestbuy", ""));
    }

    function test_Receipt_DuplicateArId_Reverts() public {
        vm.prank(operator);
        registry.registerContent("AR-RCP11",
            _base(ArtifactType.RECEIPT, "sha256:rcp11", "RECEIPT"),
            abi.encode("PURCHASE", "Merchant", "100.00", "USD", "ORD-001", "", ""));
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(AnchorRegistry.AlreadyRegistered.selector, "AR-RCP11"));
        registry.registerContent("AR-RCP11",
            _base(ArtifactType.RECEIPT, "sha256:rcp11b", "RECEIPT"),
            abi.encode("PURCHASE", "Merchant", "100.00", "USD", "ORD-001", "", ""));
    }

    function test_Receipt_AsChildOfCode_Succeeds() public {
        _code("AR-PRODUCT01", "sha256:product01");
        AnchorBase memory b = _base(
            ArtifactType.RECEIPT, "sha256:rcp12", "PURCHASE-PRODUCT01"
        );
        b.parentArId = "AR-PRODUCT01";
        vm.prank(operator);
        registry.registerContent("AR-RCP12", b,
            abi.encode("PURCHASE", "Shopify Store", "49.99", "USD", "SHP-2026-001", "shopify", ""));
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
        registry.registerGated("AR-LGL01",
            _base(ArtifactType.LEGAL, "sha256:lgl01", "TRADEMARK"),
            abi.encode("PATENT_APPLICATION", "Canada", "Ian Moore", "2026-03-16",
            "https://cipo.ic.gc.ca/test"));
        assertTrue(registry.registered("AR-LGL01"));
    }

    function test_Legal_ByStandardOperator_Reverts() public {
        vm.prank(operator);
        vm.expectRevert(AnchorRegistry.NotLegalOperator.selector);
        registry.registerGated("AR-LGL02",
            _base(ArtifactType.LEGAL, "sha256:lgl02", "TRADEMARK"),
            abi.encode("CONTRACT", "Delaware", "Acme Corp, Ian Moore", "2026-03-16", "https://test"));
    }

    function test_Legal_RemovedOperator_Reverts() public {
        vm.prank(owner); registry.addLegalOperator(legalOp);
        vm.prank(owner); registry.removeLegalOperator(legalOp);
        vm.prank(legalOp);
        vm.expectRevert(AnchorRegistry.NotLegalOperator.selector);
        registry.registerGated("AR-LGL03",
            _base(ArtifactType.LEGAL, "sha256:lgl03", "TRADEMARK"),
            abi.encode("NDA", "UK", "Party A, Party B", "2026-01-01", "https://test"));
    }

    function test_Entity_SuppressedAtLaunch() public view {
        assertFalse(registry.entityOperators(operator));
        assertFalse(registry.entityOperators(entityOp));
    }

    function test_Entity_ByEntityOperator_Succeeds() public {
        vm.prank(owner); registry.addEntityOperator(entityOp);
        vm.prank(entityOp);
        registry.registerGated("AR-ENT01",
            _base(ArtifactType.ENTITY, "sha256:ent01", "ICMOORE-ENTITY"),
            abi.encode("PERSON", "icmoore.com", "DNS_TXT",
            "anchorregistry-verify=abc123",
            "https://anchorregistry.ai/canonical/AR-ENT01",
            "sha256:canonicaldoc01"));
        assertTrue(registry.registered("AR-ENT01"));
    }

    function test_Entity_ByStandardOperator_Reverts() public {
        vm.prank(operator);
        vm.expectRevert(AnchorRegistry.NotEntityOperator.selector);
        registry.registerGated("AR-ENT02",
            _base(ArtifactType.ENTITY, "sha256:ent02", "ENTITY"),
            abi.encode("PERSON", "icmoore.com", "DNS_TXT", "proof", "", ""));
    }

    function test_Entity_RemovedOperator_Reverts() public {
        vm.prank(owner); registry.addEntityOperator(entityOp);
        vm.prank(owner); registry.removeEntityOperator(entityOp);
        vm.prank(entityOp);
        vm.expectRevert(AnchorRegistry.NotEntityOperator.selector);
        registry.registerGated("AR-ENT03",
            _base(ArtifactType.ENTITY, "sha256:ent03", "ENTITY"),
            abi.encode("PERSON", "icmoore.com", "DNS_TXT", "proof", "", ""));
    }

    function test_Proof_SuppressedAtLaunch() public view {
        assertFalse(registry.proofOperators(operator));
        assertFalse(registry.proofOperators(proofOp));
    }

    function test_Proof_ZK_ByProofOperator_Succeeds() public {
        vm.prank(owner); registry.addProofOperator(proofOp);
        vm.prank(proofOp);
        registry.registerGated("AR-PRF01",
            _base(ArtifactType.PROOF, "sha256:prf01", "ZKP-2026"),
            abi.encode("ZK_PROOF", "Groth16",
            "circuit-v1-sha256", "sha256:vkeyhash01",
            "", "",
            "https://verifier.anchorregistry.ai/AR-PRF01", "",
            "sha256:proofhash01"));
        assertTrue(registry.registered("AR-PRF01"));
    }

    function test_Proof_Audit_ByProofOperator_Succeeds() public {
        vm.prank(owner); registry.addProofOperator(proofOp);
        vm.prank(proofOp);
        registry.registerGated("AR-PRF04",
            _base(ArtifactType.PROOF, "sha256:prf04", "AUDIT-2026"),
            abi.encode("SECURITY_AUDIT", "Manual Review",
            "", "",
            "Trail of Bits", "AnchorRegistry.sol v1.0",
            "", "https://github.com/trailofbits/publications/test",
            "sha256:auditreport01"));
        assertTrue(registry.registered("AR-PRF04"));
    }

    function test_Proof_ByStandardOperator_Reverts() public {
        vm.prank(operator);
        vm.expectRevert(AnchorRegistry.NotProofOperator.selector);
        registry.registerGated("AR-PRF02",
            _base(ArtifactType.PROOF, "sha256:prf02", "ZKP"),
            abi.encode("ZK_PROOF", "PLONK",
            "circuit-v2", "sha256:vkey02",
            "", "", "https://test", "", "sha256:proof02"));
    }

    function test_Proof_RemovedOperator_Reverts() public {
        vm.prank(owner); registry.addProofOperator(proofOp);
        vm.prank(owner); registry.removeProofOperator(proofOp);
        vm.prank(proofOp);
        vm.expectRevert(AnchorRegistry.NotProofOperator.selector);
        registry.registerGated("AR-PRF03",
            _base(ArtifactType.PROOF, "sha256:prf03", "ZKP"),
            abi.encode("ZK_PROOF", "STARKs",
            "circuit-v3", "sha256:vkey03",
            "", "", "https://test", "", "sha256:proof03"));
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
        AnchorBase memory b = _base(
            ArtifactType.RETRACTION, "sha256:ret01", "RETRACTION-TARGET01"
        );
        b.parentArId = "AR-TARGET01";
        vm.prank(operator);
        registry.registerTargeted("AR-RET01", b, "AR-TARGET01", abi.encode("Wrong file", ""));
        assertTrue(registry.registered("AR-RET01"));
    }

    function test_Retraction_WithReplacement() public {
        _code("AR-V1", "sha256:v1");
        _code("AR-V2", "sha256:v2");
        AnchorBase memory b = _base(
            ArtifactType.RETRACTION, "sha256:ret02", "RETRACTION-V1"
        );
        b.parentArId = "AR-V1";
        vm.prank(operator);
        vm.expectEmit(true, true, false, true);
        emit AnchorRegistry.Retracted("AR-RET02", "AR-V1", "AR-V2");
        registry.registerTargeted("AR-RET02", b, "AR-V1", abi.encode("Superseded", "AR-V2"));

        (string memory reason, string memory retReplacedBy) = abi.decode(registry.getAnchorData("AR-RET02"), (string, string));
        assertEq(retReplacedBy, "AR-V2");
        // silence unused variable warning
        bytes(reason).length;
    }

    function test_Retraction_NonExistentTarget_Reverts() public {
        AnchorBase memory b = _base(
            ArtifactType.RETRACTION, "sha256:ret03", "RETRACTION"
        );
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(AnchorRegistry.InvalidTarget.selector, "AR-MISSING"));
        registry.registerTargeted("AR-RET03", b, "AR-MISSING", abi.encode("", ""));
    }

    function test_Retraction_EmptyTarget_Reverts() public {
        AnchorBase memory b = _base(
            ArtifactType.RETRACTION, "sha256:ret04", "RETRACTION"
        );
        vm.prank(operator);
        vm.expectRevert(AnchorRegistry.EmptyTargetArId.selector);
        registry.registerTargeted("AR-RET04", b, "", abi.encode("", ""));
    }

    function test_NodeSwap_ChildrenPreservedOnChain() public {
        _code("AR-ROOT", "sha256:root");

        vm.prank(operator);
        registry.registerContent("AR-V1", _child("sha256:v1", "AR-ROOT"),
            abi.encode("git:v1", "MIT", "Python", "v1.0.0", "https://test"));
        vm.prank(operator);
        registry.registerContent("AR-CHILD", _child("sha256:child", "AR-V1"),
            abi.encode("git:child", "MIT", "Python", "v1.0.1", "https://test"));
        vm.prank(operator);
        registry.registerContent("AR-V2", _child("sha256:v2", "AR-ROOT"),
            abi.encode("git:v2", "MIT", "Python", "v2.0.0", "https://test"));

        AnchorBase memory retb = _base(
            ArtifactType.RETRACTION, "sha256:ret", "RETRACTION-V1"
        );
        retb.parentArId = "AR-V1";
        vm.prank(operator);
        registry.registerTargeted("AR-RET", retb, "AR-V1", abi.encode("Superseded by V2", "AR-V2"));

        (, string memory retReplacedBy) = abi.decode(registry.getAnchorData("AR-RET"), (string, string));
        assertEq(retReplacedBy, "AR-V2");

        assertTrue(registry.registered("AR-CHILD"));
    }

    // =========================================================================
    // 8. REVIEW, VOID, AFFIRMED (types 17-19)
    // =========================================================================

    function test_Review_Succeeds() public {
        _code("AR-RTARGET01", "sha256:rtarget01");
        AnchorBase memory b = _base(
            ArtifactType.REVIEW, "sha256:rev01", "REVIEW-RTARGET01"
        );
        b.parentArId = "AR-RTARGET01";
        vm.prank(operator);
        vm.expectEmit(true, true, false, true);
        emit AnchorRegistry.Reviewed("AR-REV01", "AR-RTARGET01", "FALSE_AUTHORSHIP", "https://test");
        registry.registerTargeted("AR-REV01", b, "AR-RTARGET01", abi.encode("FALSE_AUTHORSHIP", "https://test"));
        assertTrue(registry.registered("AR-REV01"));
    }

    function test_Review_NonExistentTarget_Reverts() public {
        AnchorBase memory b = _base(
            ArtifactType.REVIEW, "sha256:rev02", "REVIEW"
        );
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(AnchorRegistry.InvalidTarget.selector, "AR-MISSING"));
        registry.registerTargeted("AR-REV02", b, "AR-MISSING", abi.encode("OTHER", "https://test"));
    }

    function test_Review_EmptyTarget_Reverts() public {
        AnchorBase memory b = _base(
            ArtifactType.REVIEW, "sha256:rev03", "REVIEW"
        );
        vm.prank(operator);
        vm.expectRevert(AnchorRegistry.EmptyTargetArId.selector);
        registry.registerTargeted("AR-REV03", b, "", abi.encode("OTHER", "https://test"));
    }

    function test_Review_ByStranger_Reverts() public {
        _code("AR-RTARGET02", "sha256:rtarget02");
        AnchorBase memory b = _base(
            ArtifactType.REVIEW, "sha256:rev04", "REVIEW"
        );
        vm.prank(stranger);
        vm.expectRevert(AnchorRegistry.NotOperator.selector);
        registry.registerTargeted("AR-REV04", b, "AR-RTARGET02", abi.encode("OTHER", "https://test"));
    }

    function test_Void_Succeeds() public {
        _review("AR-REV-V01", "AR-VTARGET01");
        AnchorBase memory b = _base(
            ArtifactType.VOID, "sha256:void01", "VOID-VTARGET01"
        );
        b.parentArId = "AR-REV-V01";
        vm.prank(operator);
        vm.expectEmit(true, true, true, true);
        emit AnchorRegistry.Voided("AR-VOID01", "AR-VTARGET01", "AR-REV-V01", "Fraud confirmed");
        registry.registerTargeted("AR-VOID01", b, "AR-VTARGET01", abi.encode("AR-REV-V01", "https://test", "Fraud confirmed"));
        assertTrue(registry.registered("AR-VOID01"));

        (string memory vReviewArId, string memory vFindingUrl, string memory vEvidence) = abi.decode(registry.getAnchorData("AR-VOID01"), (string, string, string));
        assertEq(vReviewArId, "AR-REV-V01");
        assertEq(vEvidence,   "Fraud confirmed");
        // silence unused variable warning
        bytes(vFindingUrl).length;
    }

    function test_Void_NonExistentTarget_Reverts() public {
        AnchorBase memory b = _base(
            ArtifactType.VOID, "sha256:void02", "VOID"
        );
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(AnchorRegistry.InvalidTarget.selector, "AR-MISSING"));
        registry.registerTargeted("AR-VOID02", b, "AR-MISSING", abi.encode("AR-SOMEREVIEW", "https://test", "evidence"));
    }

    function test_Void_NonExistentReviewArId_Reverts() public {
        _code("AR-VTARGET02", "sha256:vtarget02");
        AnchorBase memory b = _base(
            ArtifactType.VOID, "sha256:void03", "VOID"
        );
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(AnchorRegistry.InvalidTarget.selector, "AR-NOREVIEW"));
        registry.registerTargeted("AR-VOID03", b, "AR-VTARGET02", abi.encode("AR-NOREVIEW", "https://test", "evidence"));
    }

    function test_Void_ByStranger_Reverts() public {
        _review("AR-REV-V02", "AR-VTARGET03");
        AnchorBase memory b = _base(
            ArtifactType.VOID, "sha256:void04", "VOID"
        );
        vm.prank(stranger);
        vm.expectRevert(AnchorRegistry.NotOperator.selector);
        registry.registerTargeted("AR-VOID04", b, "AR-VTARGET03", abi.encode("AR-REV-V02", "https://test", "evidence"));
    }

    function test_Affirmed_OnReview_Investigation() public {
        _review("AR-REV-A01", "AR-ATARGET01");
        AnchorBase memory b = _base(
            ArtifactType.AFFIRMED, "sha256:aff01", "AFFIRMED-REV-A01"
        );
        b.parentArId = "AR-REV-A01";
        vm.prank(operator);
        vm.expectEmit(true, true, false, true);
        emit AnchorRegistry.Affirmed("AR-AFF01", "AR-REV-A01", "INVESTIGATION");
        registry.registerTargeted("AR-AFF01", b, "AR-REV-A01", abi.encode("INVESTIGATION", "https://test"));
        assertTrue(registry.registered("AR-AFF01"));
    }

    function test_Affirmed_OnVoid_Appeal() public {
        _review("AR-REV-A02", "AR-ATARGET02");

        AnchorBase memory vb = _base(
            ArtifactType.VOID, "sha256:void-a02", "VOID-A02"
        );
        vb.parentArId = "AR-REV-A02";
        vm.prank(operator);
        registry.registerTargeted("AR-VOID-A02", vb, "AR-ATARGET02", abi.encode("AR-REV-A02", "https://test", "evidence"));

        AnchorBase memory ab = _base(
            ArtifactType.AFFIRMED, "sha256:aff02", "AFFIRMED-VOID-A02"
        );
        ab.parentArId = "AR-VOID-A02";
        vm.prank(operator);
        vm.expectEmit(true, true, false, true);
        emit AnchorRegistry.Affirmed("AR-AFF02", "AR-VOID-A02", "APPEAL");
        registry.registerTargeted("AR-AFF02", ab, "AR-VOID-A02", abi.encode("APPEAL", "https://test"));

        (string memory affAffirmedBy, string memory affFindingUrl) = abi.decode(registry.getAnchorData("AR-AFF02"), (string, string));
        assertEq(affAffirmedBy, "APPEAL");
        // silence unused variable warning
        bytes(affFindingUrl).length;
    }

    function test_Affirmed_NonExistentTarget_Reverts() public {
        AnchorBase memory b = _base(
            ArtifactType.AFFIRMED, "sha256:aff03", "AFFIRMED"
        );
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(AnchorRegistry.InvalidTarget.selector, "AR-MISSING"));
        registry.registerTargeted("AR-AFF03", b, "AR-MISSING", abi.encode("INVESTIGATION", "https://test"));
    }

    function test_Affirmed_ByStranger_Reverts() public {
        _review("AR-REV-A03", "AR-ATARGET03");
        AnchorBase memory b = _base(
            ArtifactType.AFFIRMED, "sha256:aff04", "AFFIRMED"
        );
        vm.prank(stranger);
        vm.expectRevert(AnchorRegistry.NotOperator.selector);
        registry.registerTargeted("AR-AFF04", b, "AR-REV-A03", abi.encode("INVESTIGATION", "https://test"));
    }

    function test_FullLifecycle_ReviewVoidAffirmedReopen() public {
        _code("AR-LC01", "sha256:lc01");

        AnchorBase memory rb = _base(
            ArtifactType.REVIEW, "sha256:lc-rev", "REVIEW-LC01"
        );
        rb.parentArId = "AR-LC01";
        vm.prank(operator);
        registry.registerTargeted("AR-LC-REV", rb, "AR-LC01", abi.encode("FALSE_AUTHORSHIP", "https://test"));

        AnchorBase memory ab = _base(
            ArtifactType.AFFIRMED, "sha256:lc-aff", "AFFIRMED-LC01"
        );
        ab.parentArId = "AR-LC-REV";
        vm.prank(operator);
        registry.registerTargeted("AR-LC-AFF", ab, "AR-LC-REV", abi.encode("INVESTIGATION", "https://test"));

        AnchorBase memory rb2 = _base(
            ArtifactType.REVIEW, "sha256:lc-rev2", "REVIEW-LC01-REOPEN"
        );
        rb2.parentArId = "AR-LC-AFF";
        vm.prank(operator);
        registry.registerTargeted("AR-LC-REV2", rb2, "AR-LC01", abi.encode("MALICIOUS_TREE", "https://test"));

        AnchorBase memory vb = _base(
            ArtifactType.VOID, "sha256:lc-void", "VOID-LC01"
        );
        vb.parentArId = "AR-LC-REV2";
        vm.prank(operator);
        registry.registerTargeted("AR-LC-VOID", vb, "AR-LC01", abi.encode("AR-LC-REV2", "https://test", "New evidence"));

        assertTrue(registry.registered("AR-LC-REV"));
        assertTrue(registry.registered("AR-LC-AFF"));
        assertTrue(registry.registered("AR-LC-REV2"));
        assertTrue(registry.registered("AR-LC-VOID"));
    }

    // =========================================================================
    // 9. BILLING (type 20) — ACCOUNT
    // =========================================================================

    function test_Account_EnumValue_Is21() public pure {
        assertEq(uint8(ArtifactType.ACCOUNT), 21);
    }

    function test_Account_HappyPath_Succeeds() public {
        vm.prank(operator);
        registry.registerContent(
            "AR-ACC01",
            _base(ArtifactType.ACCOUNT, "sha256:acc01", "ACCOUNT-BATCH-001"),
            abi.encode(uint256(25))
        );
        assertTrue(registry.registered("AR-ACC01"));
    }

    function test_Account_Capacity_StoredCorrectly() public {
        vm.prank(operator);
        registry.registerContent(
            "AR-ACC02",
            _base(ArtifactType.ACCOUNT, "sha256:acc02", "ACCOUNT-BATCH-002"),
            abi.encode(uint256(42))
        );
        uint256 cap = abi.decode(registry.getAnchorData("AR-ACC02"), (uint256));
        assertEq(cap, 42);
    }

    function test_Account_ExactMinimumCapacity_Succeeds() public {
        vm.prank(operator);
        registry.registerContent(
            "AR-ACC03",
            _base(ArtifactType.ACCOUNT, "sha256:acc03", "ACCOUNT-MIN"),
            abi.encode(uint256(10))
        );
        uint256 cap = abi.decode(registry.getAnchorData("AR-ACC03"), (uint256));
        assertEq(cap, 10);
    }

    function test_Account_BelowMinimumCapacity_Reverts() public {
        vm.prank(operator);
        vm.expectRevert(AnchorRegistry.InsufficientCapacity.selector);
        registry.registerContent(
            "AR-ACC03B",
            _base(ArtifactType.ACCOUNT, "sha256:acc03b", "ACCOUNT-LOW"),
            abi.encode(uint256(9))
        );
    }

    function test_Account_ZeroCapacity_Reverts() public {
        vm.prank(operator);
        vm.expectRevert(AnchorRegistry.InsufficientCapacity.selector);
        registry.registerContent(
            "AR-ACC03C",
            _base(ArtifactType.ACCOUNT, "sha256:acc03c", "ACCOUNT-ZERO"),
            abi.encode(uint256(0))
        );
    }

    function test_Account_LargeCapacity_Succeeds() public {
        vm.prank(operator);
        registry.registerContent(
            "AR-ACC04",
            _base(ArtifactType.ACCOUNT, "sha256:acc04", "ACCOUNT-LARGE"),
            abi.encode(uint256(1000))
        );
        uint256 cap = abi.decode(registry.getAnchorData("AR-ACC04"), (uint256));
        assertEq(cap, 1000);
    }

    function test_Account_InvalidParent_Reverts() public {
        AnchorBase memory b = _base(
            ArtifactType.ACCOUNT, "sha256:acc05", "ACCOUNT-BADPARENT"
        );
        b.parentArId = "AR-DOESNOTEXIST";
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(AnchorRegistry.InvalidParent.selector, "AR-DOESNOTEXIST"));
        registry.registerContent("AR-ACC05", b, abi.encode(uint256(25)));
    }

    function test_Account_AlreadyRegistered_Reverts() public {
        vm.prank(operator);
        registry.registerContent(
            "AR-ACC06",
            _base(ArtifactType.ACCOUNT, "sha256:acc06", "ACCOUNT"),
            abi.encode(uint256(25))
        );
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(AnchorRegistry.AlreadyRegistered.selector, "AR-ACC06"));
        registry.registerContent(
            "AR-ACC06",
            _base(ArtifactType.ACCOUNT, "sha256:acc06b", "ACCOUNT"),
            abi.encode(uint256(25))
        );
    }

    function test_Account_EmptyManifestHash_Reverts() public {
        vm.prank(operator);
        vm.expectRevert(AnchorRegistry.EmptyManifestHash.selector);
        registry.registerContent(
            "AR-ACC07",
            _base(ArtifactType.ACCOUNT, "", "ACCOUNT-NOHASH"),
            abi.encode(uint256(25))
        );
    }

    function test_Account_ByStranger_Reverts() public {
        vm.prank(stranger);
        vm.expectRevert(AnchorRegistry.NotOperator.selector);
        registry.registerContent(
            "AR-ACC08",
            _base(ArtifactType.ACCOUNT, "sha256:acc08", "ACCOUNT-STRANGER"),
            abi.encode(uint256(5))
        );
    }

    // =========================================================================
    // 10. OTHER (type 21)
    // =========================================================================

    function test_RegisterOther() public {
        vm.prank(operator);
        registry.registerContent("AR-OTH01",
            _base(ArtifactType.OTHER, "sha256:oth01", "COURSE"),
            abi.encode("course", "Thinkific", "https://thinkific.com/test", "DeFi 101"));
        assertTrue(registry.registered("AR-OTH01"));
    }

    function test_Other_EnumValue_Is22() public pure {
        assertEq(uint8(ArtifactType.OTHER), 22);
    }

    // =========================================================================
    // 11. ACCESS CONTROL
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
        registry.registerContent("AR-FAIL01", base,
            abi.encode("git:fail", "MIT", "Python", "v1.0.0", "https://test"));
    }

    function test_OwnerCannotRegisterContent() public {
        vm.prank(owner);
        vm.expectRevert(AnchorRegistry.NotOperator.selector);
        registry.registerContent("AR-FAIL02", base,
            abi.encode("git:fail", "MIT", "Python", "v1.0.0", "https://test"));
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
        registry.registerContent("AR-FAIL03", base,
            abi.encode("git:fail", "MIT", "Python", "v1.0.0", "https://test"));
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
    // 12. EDGE CASES & VALIDATION
    // =========================================================================

    function test_EmptyArId_Reverts() public {
        vm.prank(operator);
        vm.expectRevert(AnchorRegistry.EmptyArId.selector);
        registry.registerContent("", base,
            abi.encode("git:abc", "MIT", "Python", "v1.0.0", "https://test"));
    }

    function test_EmptyManifestHash_Reverts() public {
        vm.prank(operator);
        vm.expectRevert(AnchorRegistry.EmptyManifestHash.selector);
        registry.registerContent("AR-FAIL04",
            _base(ArtifactType.CODE, "", "TEST"),
            abi.encode("git:abc", "MIT", "Python", "v1.0.0", "https://test"));
    }

    function test_DuplicateArId_Reverts() public {
        _code("AR-DUP01", "sha256:first");
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(AnchorRegistry.AlreadyRegistered.selector, "AR-DUP01"));
        registry.registerContent("AR-DUP01", base,
            abi.encode("git:abc", "MIT", "Python", "v1.0.0", "https://test"));
    }

    function test_DuplicateArIdAcrossTypes_Reverts() public {
        _code("AR-CROSS01", "sha256:cross01");
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(AnchorRegistry.AlreadyRegistered.selector, "AR-CROSS01"));
        registry.registerContent("AR-CROSS01",
            _base(ArtifactType.TEXT, "sha256:cross02", "TEXT"),
            abi.encode("", "", "", "https://test"));
    }

    function test_InvalidParentHash_Reverts() public {
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(AnchorRegistry.InvalidParent.selector, "AR-DOESNOTEXIST"));
        registry.registerContent("AR-CHILD01", _child("sha256:child01", "AR-DOESNOTEXIST"),
            abi.encode("git:child", "MIT", "Python", "v1.0.0", "https://test"));
    }

    // =========================================================================
    // 13. TREE INTEGRITY
    // =========================================================================

    function test_ValidParentHash_Succeeds() public {
        _code("AR-ROOT01", "sha256:root");
        vm.prank(operator);
        registry.registerContent("AR-CHILD02", _child("sha256:child", "AR-ROOT01"),
            abi.encode("git:child", "MIT", "Rust", "v0.1.0", "https://test"));
        assertTrue(registry.registered("AR-CHILD02"));
    }

    function test_DeepLineageTree() public {
        _code("AR-L0", "sha256:l0");
        for (uint256 i = 1; i <= 5; i++) {
            string memory parent = string(abi.encodePacked("AR-L", vm.toString(i - 1)));
            string memory id     = string(abi.encodePacked("AR-L", vm.toString(i)));
            string memory h      = string(abi.encodePacked("sha256:l", vm.toString(i)));
            vm.prank(operator);
            registry.registerContent(id, _child(h, parent),
                abi.encode("git:l", "MIT", "Go", "v1.0.0", "https://test"));
        }
        assertTrue(registry.registered("AR-L5"));
    }

    function test_MultipleChildrenSameParent() public {
        _code("AR-PARENT01", "sha256:parent01");
        for (uint256 i = 0; i < 5; i++) {
            string memory id = string(abi.encodePacked("AR-SIB-", vm.toString(i)));
            string memory h  = string(abi.encodePacked("sha256:sib", vm.toString(i)));
            vm.prank(operator);
            registry.registerContent(id, _child(h, "AR-PARENT01"),
                abi.encode("git:sib", "MIT", "TypeScript", "v1.0.0", "https://test"));
            assertTrue(registry.registered(id));
        }
    }

    function test_CrossTypeParentChild() public {
        _code("AR-CODE-PARENT", "sha256:codeparent");
        AnchorBase memory b = AnchorBase({
            artifactType: ArtifactType.RESEARCH,
            manifestHash: "sha256:res-child",
            parentArId:   "AR-CODE-PARENT",
            descriptor:   "PAPER-CHILD",
            title:        "Research Child",
            author:       "Test Author",
            treeId:       ""
        });
        vm.prank(operator);
        registry.registerContent("AR-RES-CHILD", b,
            abi.encode("10.1000/test", "MIT", "", "https://arxiv.org/test"));
        assertTrue(registry.registered("AR-RES-CHILD"));
    }

    function test_EventAsChildOfCode_TreeIntegrity() public {
        _code("AR-TREE-ROOT", "sha256:treeroot");
        AnchorBase memory b = _base(
            ArtifactType.EVENT, "sha256:tree-evt", "LAUNCH-TREE-ROOT"
        );
        b.parentArId = "AR-TREE-ROOT";
        vm.prank(operator);
        registry.registerContent("AR-TREE-EVT", b,
            abi.encode("HUMAN", "LAUNCH", "2026-03-19", "online", "AnchorRegistry", "https://anchorregistry.com"));
        assertTrue(registry.registered("AR-TREE-EVT"));
    }

    function test_ReportAsChildOfResearch_TreeIntegrity() public {
        vm.prank(operator);
        registry.registerContent("AR-RESEARCH-ROOT",
            _base(ArtifactType.RESEARCH, "sha256:resroot", "BASE-RESEARCH"),
            abi.encode("10.1000/base", "MIT", "Ian Moore", "https://arxiv.org/test"));

        AnchorBase memory b = _base(
            ArtifactType.REPORT, "sha256:rpt-child", "REPORT-ON-RESEARCH"
        );
        b.parentArId = "AR-RESEARCH-ROOT";
        vm.prank(operator);
        registry.registerContent("AR-RPT-CHILD", b,
            abi.encode("TECHNICAL", "", "RESEARCH-ANALYSIS", "v1.0",
            "Jane Smith", "Hive Advisory", ""));

        assertTrue(registry.registered("AR-RPT-CHILD"));
    }

    function test_NoteAsChildOfMeeting_TreeIntegrity() public {
        vm.prank(operator);
        registry.registerContent("AR-MEETING-ROOT",
            _base(ArtifactType.NOTE, "sha256:meetroot", "KICKOFF-MEETING"),
            abi.encode("MEETING", "2026-03-20", "Ian Moore, Jane Smith", ""));

        AnchorBase memory b = _base(
            ArtifactType.NOTE, "sha256:followup", "FOLLOWUP-MEMO"
        );
        b.parentArId = "AR-MEETING-ROOT";
        vm.prank(operator);
        registry.registerContent("AR-MEMO-CHILD", b,
            abi.encode("MEMO", "2026-03-21", "Ian Moore", ""));

        assertTrue(registry.registered("AR-MEMO-CHILD"));
    }

    // =========================================================================
    // 14. ANCHORED EVENT & TREEID
    // =========================================================================

    function test_AR_TREE_ID_Constant() public view {
        assertEq(registry.AR_TREE_ID(), "ar-operator-v1");
    }

    function test_TreeId_StoredInBase_Code() public {
        AnchorBase memory b = _base(
            ArtifactType.CODE, "sha256:tid01", "TREEID-TEST"
        );
        b.treeId = "sha256:tree-fingerprint-abc123";
        vm.prank(operator);
        registry.registerContent("AR-TID01", b,
            abi.encode("git:tid", "MIT", "Python", "v1.0.0", "https://test"));
        assertTrue(registry.registered("AR-TID01"));
    }

    function test_TreeId_StoredInBase_Note() public {
        AnchorBase memory b = _base(
            ArtifactType.NOTE, "sha256:tid-note", "TREEID-NOTE"
        );
        b.treeId = "sha256:note-tree-fingerprint";
        vm.prank(operator);
        registry.registerContent("AR-TID-NOTE", b,
            abi.encode("MEMO", "2026-03-20", "", ""));
        assertTrue(registry.registered("AR-TID-NOTE"));
    }

    function test_TreeId_StoredInBase_Report() public {
        AnchorBase memory b = _base(
            ArtifactType.REPORT, "sha256:tid02", "TREEID-REPORT"
        );
        b.treeId = "sha256:hive-tree-fingerprint";
        vm.prank(operator);
        registry.registerContent("AR-TID02", b,
            abi.encode("CONSULTING", "Client A", "ENG-001", "final",
            "Ian Moore", "Hive Advisory Inc.", ""));
        assertTrue(registry.registered("AR-TID02"));
    }

    function test_TreeId_EmptyString_Allowed() public {
        AnchorBase memory b = _base(
            ArtifactType.CODE, "sha256:tid03", "TREEID-EMPTY"
        );
        b.treeId = "";
        vm.prank(operator);
        registry.registerContent("AR-TID03", b,
            abi.encode("git:tid", "MIT", "Python", "v1.0.0", "https://test"));
        assertTrue(registry.registered("AR-TID03"));
    }

    function test_TreeId_EmittedInAnchoredEvent() public {
        AnchorBase memory b = _base(
            ArtifactType.CODE, "sha256:tid04", "TREEID-EVENT-TEST"
        );
        b.treeId = "sha256:my-tree-fingerprint";
        vm.prank(operator);
        vm.expectEmit(true, true, false, true);
        emit AnchorRegistry.Anchored(
            "AR-TID04", operator,
            ArtifactType.CODE,
            "AR-TID04",
            "TREEID-EVENT-TEST", "Test Artifact", "Test Author",
            "sha256:tid04", "", "sha256:my-tree-fingerprint"
        );
        registry.registerContent("AR-TID04", b,
            abi.encode("git:tid", "MIT", "Python", "v1.0.0", "https://test"));
    }

    function test_AR_TREE_ID_UsedForReviewAnchor() public {
        _code("AR-DISPUTE-TARGET", "sha256:disputetarget");
        AnchorBase memory b = _base(
            ArtifactType.REVIEW, "sha256:ar-review", "AR-DISPUTE-REVIEW"
        );
        b.treeId = registry.AR_TREE_ID();
        b.parentArId = "AR-DISPUTE-TARGET";
        vm.prank(operator);
        registry.registerTargeted("AR-DISP-REV01", b,
            "AR-DISPUTE-TARGET", abi.encode("FALSE_AUTHORSHIP", "https://anchorregistry.com/disputes/1"));
        assertTrue(registry.registered("AR-DISP-REV01"));
    }

    function test_AnchoredEvent_OnRegisterCode() public {
        vm.prank(operator);
        vm.expectEmit(true, true, false, true);
        emit AnchorRegistry.Anchored(
            "AR-EVT01", operator,
            ArtifactType.CODE,
            "AR-EVT01",
            "ICMOORE-2026-TEST", "Test Artifact", "Ian Moore", "sha256:abc123", "", "tree:test-root"
        );
        registry.registerContent("AR-EVT01", base,
            abi.encode("git:abc", "MIT", "TypeScript", "v1.0.0", "https://test"));
    }

    function test_RetractedEvent() public {
        _code("AR-EVT-T01", "sha256:evtt01");
        _code("AR-EVT-REP01", "sha256:evtrep01");
        AnchorBase memory b = _base(
            ArtifactType.RETRACTION, "sha256:evtret01", "RETRACTION"
        );
        b.parentArId = "AR-EVT-T01";
        vm.prank(operator);
        vm.expectEmit(true, true, false, true);
        emit AnchorRegistry.Retracted("AR-EVT-RET01", "AR-EVT-T01", "AR-EVT-REP01");
        registry.registerTargeted("AR-EVT-RET01", b, "AR-EVT-T01", abi.encode("superseded", "AR-EVT-REP01"));
    }

    function test_ReviewedEvent() public {
        _code("AR-EVT-DT01", "sha256:evtdt01");
        AnchorBase memory b = _base(
            ArtifactType.REVIEW, "sha256:evtrev01", "REVIEW"
        );
        b.parentArId = "AR-EVT-DT01";
        vm.prank(operator);
        vm.expectEmit(true, true, false, true);
        emit AnchorRegistry.Reviewed("AR-EVT-REV01", "AR-EVT-DT01", "IMPERSONATION", "https://test");
        registry.registerTargeted("AR-EVT-REV01", b, "AR-EVT-DT01", abi.encode("IMPERSONATION", "https://test"));
    }

    function test_VoidedEvent() public {
        _review("AR-EVT-REV02", "AR-EVT-VT01");
        AnchorBase memory b = _base(
            ArtifactType.VOID, "sha256:evtvoid01", "VOID"
        );
        b.parentArId = "AR-EVT-REV02";
        vm.prank(operator);
        vm.expectEmit(true, true, true, true);
        emit AnchorRegistry.Voided("AR-EVT-VOID01", "AR-EVT-VT01", "AR-EVT-REV02", "evidence");
        registry.registerTargeted("AR-EVT-VOID01", b, "AR-EVT-VT01", abi.encode("AR-EVT-REV02", "https://test", "evidence"));
    }

    function test_AffirmedEvent() public {
        _review("AR-EVT-REV03", "AR-EVT-AT01");
        AnchorBase memory b = _base(
            ArtifactType.AFFIRMED, "sha256:evtaff01", "AFFIRMED"
        );
        b.parentArId = "AR-EVT-REV03";
        vm.prank(operator);
        vm.expectEmit(true, true, false, true);
        emit AnchorRegistry.Affirmed("AR-EVT-AFF01", "AR-EVT-REV03", "INVESTIGATION");
        registry.registerTargeted("AR-EVT-AFF01", b, "AR-EVT-REV03", abi.encode("INVESTIGATION", "https://test"));
    }

    // =========================================================================
    // 15. RECOVERY & GRIEFING DEFENCE
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

    // =========================================================================
    // 16. ACCOUNT TREE PATTERNS
    // =========================================================================
    //
    // Two valid on-chain shapes. Enforcement that ACCOUNT only attaches to root
    // is a UI/FastAPI concern — the contract is type-agnostic on parentHash.
    //
    // Pattern 1 — ACCOUNT is the root:
    //   ACCOUNT (AAAAA) capacity:25
    //   ├── CODE    (00001)
    //   ├── DATA    (00002)
    //   ├── MODEL   (00003)
    //   │   ├── CODE  (00004)
    //   │   └── DATA  (00005)
    //   ├── ACCOUNT (TTTTT) top-up capacity:100
    //   └── REPORT  (00006)
    //
    // Pattern 2 — Content root, ACCOUNTs pinned flat as direct children:
    //   CODE (XXXXX) original $5 root
    //   ├── DATA    (00001) paid individually
    //   ├── ACCOUNT (AAAAA) capacity:25
    //   ├── ACCOUNT (TTTTT) top-up capacity:100
    //   ├── MODEL   (00002) batch-funded
    //   ├── AGENT   (00003) batch-funded
    //   └── REPORT  (00004) batch-funded

    // ── Helpers used only in section 16 ──────────────────────────────────────

    function _childOf(
        ArtifactType t,
        string memory h,
        string memory parent
    ) internal pure returns (AnchorBase memory) {
        return AnchorBase({
            artifactType: t,
            manifestHash: h,
            parentArId:   parent,
            descriptor:   "TREE-TEST",
            title:        "Tree Test Artifact",
            author:       "Test Author",
            treeId:       ""
        });
    }

    function _registerAccount(
        string memory arId,
        string memory h,
        string memory parent,
        uint256 cap
    ) internal {
        AnchorBase memory b = AnchorBase({
            artifactType: ArtifactType.ACCOUNT,
            manifestHash: h,
            parentArId:   parent,
            descriptor:   string(abi.encodePacked("ACCOUNT-", arId)),
            title:        "Account Anchor",
            author:       "Test Author",
            treeId:       ""
        });
        vm.prank(operator);
        registry.registerContent(arId, b, abi.encode(cap));
    }

    // ── Pattern 1 tests ──────────────────────────────────────────────────────

    function test_P1_AccountRoot_Registered() public {
        _registerAccount("AR-AAAAA", "sha256:aaaaa", "", 25);
        assertTrue(registry.registered("AR-AAAAA"));
        uint256 cap = abi.decode(registry.getAnchorData("AR-AAAAA"), (uint256));
        assertEq(cap, 25);
    }

    function test_P1_ContentChildrenOfAccountRoot() public {
        _registerAccount("AR-AAAAA", "sha256:aaaaa", "", 25);

        vm.prank(operator);
        registry.registerContent("AR-P1-00001",
            _childOf(ArtifactType.CODE, "sha256:p1c01", "AR-AAAAA"),
            abi.encode("git:abc", "MIT", "Python", "v1.0.0", ""));
        vm.prank(operator);
        registry.registerContent("AR-P1-00002",
            _childOf(ArtifactType.DATA, "sha256:p1d01", "AR-AAAAA"),
            abi.encode("v1.0", "CSV", "10000", "", ""));
        vm.prank(operator);
        registry.registerContent("AR-P1-00006",
            _childOf(ArtifactType.REPORT, "sha256:p1r01", "AR-AAAAA"),
            abi.encode("TECHNICAL", "", "ENG-001", "v1.0", "Ian Moore", "AR", ""));

        assertTrue(registry.registered("AR-P1-00001"));
        assertTrue(registry.registered("AR-P1-00002"));
        assertTrue(registry.registered("AR-P1-00006"));
    }

    function test_P1_NestedContentUnderAccountRoot() public {
        // ACCOUNT root → MODEL → CODE + DATA grandchildren
        _registerAccount("AR-AAAAA", "sha256:aaaaa", "", 25);

        vm.prank(operator);
        registry.registerContent("AR-P1-00003",
            _childOf(ArtifactType.MODEL, "sha256:p1m01", "AR-AAAAA"),
            abi.encode("v1.0", "Transformer", "7B", "CommonCrawl", ""));
        vm.prank(operator);
        registry.registerContent("AR-P1-00004",
            _childOf(ArtifactType.CODE, "sha256:p1c02", "AR-P1-00003"),
            abi.encode("git:abc", "MIT", "Python", "v1.0.0", ""));
        vm.prank(operator);
        registry.registerContent("AR-P1-00005",
            _childOf(ArtifactType.DATA, "sha256:p1d02", "AR-P1-00003"),
            abi.encode("v1.0", "Parquet", "50000", "", ""));

        assertTrue(registry.registered("AR-P1-00003"));
        assertTrue(registry.registered("AR-P1-00004"));
        assertTrue(registry.registered("AR-P1-00005"));
    }

    function test_P1_TopupAccountChildOfAccountRoot() public {
        _registerAccount("AR-AAAAA", "sha256:aaaaa", "", 25);
        _registerAccount("AR-TTTTT", "sha256:ttttt", "AR-AAAAA", 100);

        assertTrue(registry.registered("AR-TTTTT"));
        uint256 topupCap = abi.decode(registry.getAnchorData("AR-TTTTT"), (uint256));
        assertEq(topupCap, 100);
    }

    function test_P1_CapacityStoredIndependently() public {
        // Contract stores each ACCOUNT capacity independently.
        // Off-chain sums them — this confirms the on-chain values are correct.
        _registerAccount("AR-AAAAA", "sha256:aaaaa", "", 25);
        _registerAccount("AR-TTTTT", "sha256:ttttt", "AR-AAAAA", 100);

        uint256 rootCap  = abi.decode(registry.getAnchorData("AR-AAAAA"), (uint256));
        uint256 topupCap = abi.decode(registry.getAnchorData("AR-TTTTT"), (uint256));
        assertEq(rootCap,  25);
        assertEq(topupCap, 100);
        // off-chain total would be 125 — not computed on-chain
    }

    function test_P1_FullTree() public {
        // Complete Pattern 1 tree
        _registerAccount("AR-AAAAA", "sha256:aaaaa", "", 25);

        vm.prank(operator);
        registry.registerContent("AR-P1-00001",
            _childOf(ArtifactType.CODE, "sha256:p1c01", "AR-AAAAA"),
            abi.encode("git:abc", "MIT", "Python", "v1.0.0", ""));
        vm.prank(operator);
        registry.registerContent("AR-P1-00002",
            _childOf(ArtifactType.DATA, "sha256:p1d01", "AR-AAAAA"),
            abi.encode("v1.0", "CSV", "10000", "", ""));
        vm.prank(operator);
        registry.registerContent("AR-P1-00003",
            _childOf(ArtifactType.MODEL, "sha256:p1m01", "AR-AAAAA"),
            abi.encode("v1.0", "Transformer", "7B", "", ""));
        vm.prank(operator);
        registry.registerContent("AR-P1-00004",
            _childOf(ArtifactType.CODE, "sha256:p1c02", "AR-P1-00003"),
            abi.encode("git:def", "MIT", "Python", "v1.0.1", ""));
        vm.prank(operator);
        registry.registerContent("AR-P1-00005",
            _childOf(ArtifactType.DATA, "sha256:p1d02", "AR-P1-00003"),
            abi.encode("v1.0", "Parquet", "50000", "", ""));
        _registerAccount("AR-TTTTT", "sha256:ttttt", "AR-AAAAA", 100);
        vm.prank(operator);
        registry.registerContent("AR-P1-00006",
            _childOf(ArtifactType.REPORT, "sha256:p1r01", "AR-AAAAA"),
            abi.encode("TECHNICAL", "", "ENG-001", "v1.0", "Ian Moore", "AR", ""));

        string[7] memory ids = ["AR-AAAAA", "AR-P1-00001", "AR-P1-00002",
                                  "AR-P1-00003", "AR-P1-00004", "AR-P1-00005", "AR-TTTTT"];
        for (uint256 i = 0; i < ids.length; i++) {
            assertTrue(registry.registered(ids[i]));
        }
    }

    // ── Pattern 2 tests ──────────────────────────────────────────────────────

    function test_P2_ContentRoot_Registered() public {
        _code("AR-XXXXX", "sha256:xxxxx");
        assertTrue(registry.registered("AR-XXXXX"));
    }

    function test_P2_AccountPinnedToContentRoot() public {
        _code("AR-XXXXX", "sha256:xxxxx");
        _registerAccount("AR-AAAAA", "sha256:aaaaa", "AR-XXXXX", 25);

        assertTrue(registry.registered("AR-AAAAA"));
        uint256 cap = abi.decode(registry.getAnchorData("AR-AAAAA"), (uint256));
        assertEq(cap, 25);
    }

    function test_P2_MultipleAccountSiblingsOnContentRoot() public {
        _code("AR-XXXXX", "sha256:xxxxx");
        _registerAccount("AR-AAAAA", "sha256:aaaaa", "AR-XXXXX", 25);
        _registerAccount("AR-TTTTT", "sha256:ttttt", "AR-XXXXX", 100);

        uint256 capA = abi.decode(registry.getAnchorData("AR-AAAAA"), (uint256));
        uint256 capT = abi.decode(registry.getAnchorData("AR-TTTTT"), (uint256));
        assertEq(capA, 25);
        assertEq(capT, 100);
    }

    function test_P2_ContentSiblingsAlongsideAccounts() public {
        // DATA paid individually, MODEL/AGENT/REPORT batch-funded — all siblings
        _code("AR-XXXXX", "sha256:xxxxx");
        _registerAccount("AR-AAAAA", "sha256:aaaaa", "AR-XXXXX", 25);

        vm.prank(operator);
        registry.registerContent("AR-P2-00001",
            _childOf(ArtifactType.DATA, "sha256:p2d01", "AR-XXXXX"),
            abi.encode("v1.0", "CSV", "5000", "", ""));
        vm.prank(operator);
        registry.registerContent("AR-P2-00002",
            _childOf(ArtifactType.MODEL, "sha256:p2m01", "AR-XXXXX"),
            abi.encode("v1.0", "Transformer", "7B", "", ""));
        vm.prank(operator);
        registry.registerContent("AR-P2-00003",
            _childOf(ArtifactType.AGENT, "sha256:p2a01", "AR-XXXXX"),
            abi.encode("v0.1", "Python 3.11", "inference", ""));
        vm.prank(operator);
        registry.registerContent("AR-P2-00004",
            _childOf(ArtifactType.REPORT, "sha256:p2r01", "AR-XXXXX"),
            abi.encode("TECHNICAL", "", "ENG-002", "v1.0", "Ian Moore", "AR", ""));

        assertTrue(registry.registered("AR-P2-00001"));
        assertTrue(registry.registered("AR-P2-00002"));
        assertTrue(registry.registered("AR-P2-00003"));
        assertTrue(registry.registered("AR-P2-00004"));
    }

    function test_P2_TopupAccountSiblingOfOriginalAccount() public {
        _code("AR-XXXXX", "sha256:xxxxx");
        _registerAccount("AR-AAAAA", "sha256:aaaaa", "AR-XXXXX", 25);
        _registerAccount("AR-TTTTT", "sha256:ttttt", "AR-XXXXX", 100);

        uint256 capA = abi.decode(registry.getAnchorData("AR-AAAAA"), (uint256));
        uint256 capT = abi.decode(registry.getAnchorData("AR-TTTTT"), (uint256));
        assertEq(capA, 25);
        assertEq(capT, 100);
        // off-chain total = 125
    }

    function test_P2_FullTree() public {
        // Complete Pattern 2 tree
        _code("AR-XXXXX", "sha256:xxxxx");

        vm.prank(operator);
        registry.registerContent("AR-P2-00001",
            _childOf(ArtifactType.DATA, "sha256:p2d01", "AR-XXXXX"),
            abi.encode("v1.0", "CSV", "5000", "", ""));
        _registerAccount("AR-AAAAA", "sha256:aaaaa", "AR-XXXXX", 25);
        _registerAccount("AR-TTTTT", "sha256:ttttt", "AR-XXXXX", 100);
        vm.prank(operator);
        registry.registerContent("AR-P2-00002",
            _childOf(ArtifactType.MODEL, "sha256:p2m01", "AR-XXXXX"),
            abi.encode("v1.0", "Transformer", "7B", "", ""));
        vm.prank(operator);
        registry.registerContent("AR-P2-00003",
            _childOf(ArtifactType.AGENT, "sha256:p2a01", "AR-XXXXX"),
            abi.encode("v0.1", "Python 3.11", "inference", ""));
        vm.prank(operator);
        registry.registerContent("AR-P2-00004",
            _childOf(ArtifactType.REPORT, "sha256:p2r01", "AR-XXXXX"),
            abi.encode("TECHNICAL", "", "ENG-002", "v1.0", "Ian Moore", "AR", ""));

        string[7] memory ids = ["AR-XXXXX", "AR-P2-00001", "AR-AAAAA",
                                  "AR-TTTTT", "AR-P2-00002", "AR-P2-00003", "AR-P2-00004"];
        for (uint256 i = 0; i < ids.length; i++) {
            assertTrue(registry.registered(ids[i]));
        }
    }

    // ── Cross-pattern ─────────────────────────────────────────────────────────

    function test_BothPatterns_ContractIsAgnostic() public {
        // P1 and P2 trees coexist in the same registry deployment

        // P1 — ACCOUNT root
        _registerAccount("AR-P1-ROOT", "sha256:p1root", "", 25);
        vm.prank(operator);
        registry.registerContent("AR-P1-C01",
            _childOf(ArtifactType.CODE, "sha256:p1cc01", "AR-P1-ROOT"),
            abi.encode("git:abc", "MIT", "Python", "v1.0.0", ""));
        _registerAccount("AR-P1-TOPUP", "sha256:p1topup", "AR-P1-ROOT", 50);

        // P2 — content root
        _code("AR-P2-ROOT", "sha256:p2root");
        _registerAccount("AR-P2-ACC", "sha256:p2acc", "AR-P2-ROOT", 25);
        vm.prank(operator);
        registry.registerContent("AR-P2-M01",
            _childOf(ArtifactType.MODEL, "sha256:p2mm01", "AR-P2-ROOT"),
            abi.encode("v1.0", "CNN", "1B", "", ""));

        // P1 intact
        uint256 p1cap  = abi.decode(registry.getAnchorData("AR-P1-ROOT"), (uint256));
        uint256 p1tcap = abi.decode(registry.getAnchorData("AR-P1-TOPUP"), (uint256));
        assertEq(p1cap,  25);
        assertEq(p1tcap, 50);

        // P2 intact
        uint256 p2cap = abi.decode(registry.getAnchorData("AR-P2-ACC"), (uint256));
        assertEq(p2cap, 25);
    }
}
