// SPDX-License-Identifier: BUSL-1.1
// Change Date:    March 12, 2028
// Change License: Apache-2.0
// Licensor:       Ian Moore (icmoore)

pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/AnchorRegistry.sol";

/// @notice Operator smoke test — registers one anchor per modified type and
///         verifies all new fields round-trip correctly.
///
/// Usage (Sepolia):
///   source .env
///   forge script script/SmokeTest.s.sol \
///     --rpc-url $SEPOLIA_RPC_URL --broadcast -vvvv
///
/// Usage (local Anvil):
///   forge script script/SmokeTest.s.sol \
///     --rpc-url http://127.0.0.1:8545 --broadcast -vvvv
///
/// Required env vars:
///   OPERATOR_PRIVATE_KEY       — hot wallet that is a registered operator
///   ANCHOR_REGISTRY_ADDRESS    — deployed contract address

contract SmokeTest is Script {

    AnchorRegistry reg;

    // -- helpers --------------------------------------------------------------─

    function _base(ArtifactType t, string memory h, string memory d)
        internal pure returns (AnchorBase memory)
    {
        return AnchorBase({
            artifactType: t,
            manifestHash: h,
            parentArId:   "",
            descriptor:   d,
            title:        "Smoke Test Artifact",
            author:       "Ian Moore",
            treeId:       ""
        });
    }

    function _check(string memory arId) internal view {
        require(reg.registered(arId), string(abi.encodePacked("FAIL: not registered: ", arId)));
        console.log("  registered() == true");
    }

    // -- run ------------------------------------------------------------------─

    function run() external {
        uint256 operatorKey = vm.envUint("OPERATOR_PRIVATE_KEY");
        reg = AnchorRegistry(vm.envAddress("ANCHOR_REGISTRY_ADDRESS"));

        console.log("============================================================");
        console.log("  AnchorRegistry Smoke Test");
        console.log("  Contract:", address(reg));
        console.log("  Operator:", vm.addr(operatorKey));
        console.log("============================================================\n");

        vm.startBroadcast(operatorKey);

        // -- 1. CODE (baseline) ------------------------------------------------
        console.log("-- AR-SMK-CODE (type 0) --");
        reg.registerContent("AR-SMK-CODE",
            _base(ArtifactType.CODE, "sha256:smk-code", "SMK-CODE"),
            abi.encode("git:smoke", "MIT", "Solidity", "v1.0.0", "https://github.com/test"));
        _check("AR-SMK-CODE");

        // -- 2. MEDIA — platform field --------------------------------------
        console.log("\n-- AR-SMK-MEDIA (type 5) --");
        reg.registerContent("AR-SMK-MEDIA",
            _base(ArtifactType.MEDIA, "sha256:smk-media", "SMK-MEDIA"),
            abi.encode("video/mp4", "YouTube", "MP4", "3:45", "USRC12345", "https://youtube.com/test"));
        _check("AR-SMK-MEDIA");
        (,string memory platform,,,,) =
            abi.decode(reg.getAnchorData("AR-SMK-MEDIA"),
                (string, string, string, string, string, string));
        require(keccak256(bytes(platform)) == keccak256(bytes("YouTube")),
            "FAIL: platform mismatch");
        console.log("  platform =", platform, "<- NEW");

        // -- 3. TEXT — textType field --------------------------------------─
        console.log("\n-- AR-SMK-TEXT (type 6) --");
        reg.registerContent("AR-SMK-TEXT",
            _base(ArtifactType.TEXT, "sha256:smk-text", "SMK-TEXT"),
            abi.encode("ARTICLE", "978-3-16-148410-0", "O'Reilly", "English", "https://example.com/article"));
        _check("AR-SMK-TEXT");
        (string memory textType,,,,) =
            abi.decode(reg.getAnchorData("AR-SMK-TEXT"),
                (string, string, string, string, string));
        require(keccak256(bytes(textType)) == keccak256(bytes("ARTICLE")),
            "FAIL: textType mismatch");
        console.log("  textType =", textType, "<- NEW");

        // -- 4. REPORT — fileManifestHash field ----------------------------
        console.log("\n-- AR-SMK-REPORT (type 9) --");
        reg.registerContent("AR-SMK-REPORT",
            _base(ArtifactType.REPORT, "sha256:smk-report", "SMK-REPORT"),
            abi.encode("CONSULTING", "Acme Corp", "SMK-ENG-001", "final",
                "Ian Moore", "Hive Advisory", "https://example.com/report",
                "sha256:report-manifest-abc123"));
        _check("AR-SMK-REPORT");
        (,,,,,, ,string memory rptFmh) =
            abi.decode(reg.getAnchorData("AR-SMK-REPORT"),
                (string, string, string, string, string, string, string, string));
        require(keccak256(bytes(rptFmh)) == keccak256(bytes("sha256:report-manifest-abc123")),
            "FAIL: report fileManifestHash mismatch");
        console.log("  fileManifestHash =", rptFmh, "<- NEW");

        // -- 5. NOTE — fileManifestHash field ------------------------------
        console.log("\n-- AR-SMK-NOTE (type 10) --");
        reg.registerContent("AR-SMK-NOTE",
            _base(ArtifactType.NOTE, "sha256:smk-note", "SMK-NOTE"),
            abi.encode("MEETING", "2026-03-30", "Ian Moore, Jane Smith",
                "https://example.com/notes", "sha256:note-manifest-def456"));
        _check("AR-SMK-NOTE");
        (,,,, string memory noteFmh) =
            abi.decode(reg.getAnchorData("AR-SMK-NOTE"),
                (string, string, string, string, string));
        require(keccak256(bytes(noteFmh)) == keccak256(bytes("sha256:note-manifest-def456")),
            "FAIL: note fileManifestHash mismatch");
        console.log("  fileManifestHash =", noteFmh, "<- NEW");

        // -- 6. RECEIPT — fileManifestHash field --------------------------─
        console.log("\n-- AR-SMK-RECEIPT (type 12) --");
        reg.registerContent("AR-SMK-RECEIPT",
            _base(ArtifactType.RECEIPT, "sha256:smk-receipt", "SMK-RECEIPT"),
            abi.encode("PURCHASE", "Wayfair", "1299.99", "CAD",
                "ORD-SMK-001", "shopify", "https://wayfair.com/orders/1",
                "sha256:receipt-manifest-ghi789"));
        _check("AR-SMK-RECEIPT");
        (,,,,,,, string memory rcpFmh) =
            abi.decode(reg.getAnchorData("AR-SMK-RECEIPT"),
                (string, string, string, string, string, string, string, string));
        require(keccak256(bytes(rcpFmh)) == keccak256(bytes("sha256:receipt-manifest-ghi789")),
            "FAIL: receipt fileManifestHash mismatch");
        console.log("  fileManifestHash =", rcpFmh, "<- NEW");

        // -- 7. OTHER — fileManifestHash field ----------------------------─
        console.log("\n-- AR-SMK-OTHER (type 21) --");
        reg.registerContent("AR-SMK-OTHER",
            _base(ArtifactType.OTHER, "sha256:smk-other", "SMK-OTHER"),
            abi.encode("course", "Thinkific", "https://thinkific.com/test",
                "DeFi 101", "sha256:other-manifest-jkl012"));
        _check("AR-SMK-OTHER");
        (,,,, string memory otherFmh) =
            abi.decode(reg.getAnchorData("AR-SMK-OTHER"),
                (string, string, string, string, string));
        require(keccak256(bytes(otherFmh)) == keccak256(bytes("sha256:other-manifest-jkl012")),
            "FAIL: other fileManifestHash mismatch");
        console.log("  fileManifestHash =", otherFmh, "<- NEW");

        vm.stopBroadcast();

        console.log("\n============================================================");
        console.log("  All checks passed");
        console.log("============================================================");
    }
}
