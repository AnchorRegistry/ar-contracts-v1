// SPDX-License-Identifier: BUSL-1.1
// Change Date:    March 12, 2028
// Change License: Apache-2.0
// Licensor:       Ian Moore (icmoore)

pragma solidity ^0.8.24;

/// @title  AnchorRegistry
/// @notice On-chain registry of artifact provenance anchors.
///         Immutable record of what existed, when, and who registered it.
/// @dev    Deployed once on Base (Ethereum L2). Cannot be modified post-deployment.
///
///         Seventeen artifact types in six logical groups:
///
///         CONTENT (0-8):     CODE, RESEARCH, DATA, MODEL, AGENT, MEDIA, TEXT, POST, ONCHAIN
///                            What creators make. Active at launch. onlyOperator.
///                            ONCHAIN: Ethereum addresses, transactions, contracts,
///                            NFTs, token IDs, DAOs, multisigs — on-chain asset provenance.
///
///         GATED (9-11):      LEGAL, ENTITY, PROOF
///                            Suppressed at launch. Separate operator gates.
///                            LEGAL opens in V2-V3 with document verification.
///                            ENTITY opens in V2 with domain verification.
///                            PROOF opens in V4 with ZK infrastructure.
///
///         SELF-SERVICE (12): RETRACTION
///                            Owner-initiated. Active at launch. Operator submits
///                            on behalf of creator after ownership token verification.
///
///         REVIEW (13-15):    REVIEW, VOID, AFFIRMED
///                            AnchorRegistry operator-only. Active at launch.
///                            REVIEW: soft flag, anchor under review.
///                            VOID: hard finding, subtree condemned, cascades down.
///                            AFFIRMED: exoneration, review resolved.
///
///         CATCH-ALL (16):    OTHER
///
///         Four access gates:
///         onlyOperator      — types 0-8, 12-16
///         onlyLegalOperator — type 9   (no operators added at deployment)
///         onlyEntityOperator— type 10  (no operators added at deployment)
///         onlyProofOperator — type 11  (no operators added at deployment)

contract AnchorRegistry {

    // =========================================================================
    // ACCESS CONTROL STORAGE
    // =========================================================================

    address public owner;
    address public recoveryAddress;

    /// @notice Standard operators — content, retraction, review, and other types.
    ///         Can register types 0-8, 12-16. Cannot call registerLegal, registerEntity, or registerProof.
    mapping(address => bool) public operators;

    /// @notice Legal operators — LEGAL registration only (type 9).
    ///         Not added at deployment. Opens in V2-V3 with document verification.
    mapping(address => bool) public legalOperators;

    /// @notice Entity operators — ENTITY registration only (type 10).
    ///         Not added at deployment. Opens in V2 with domain verification.
    mapping(address => bool) public entityOperators;

    /// @notice Proof operators — PROOF registration only (type 11).
    ///         Not added at deployment. Opens in V4 with ZK infrastructure.
    mapping(address => bool) public proofOperators;

    uint256 public constant RECOVERY_DELAY   = 7 days;
    uint256 public constant RECOVERY_LOCKOUT = 7 days;
    uint256 public recoveryInitiatedAt;
    uint256 public recoveryLockoutUntil;
    address public pendingOwner;

    // =========================================================================
    // ACCESS CONTROL EVENTS
    // =========================================================================

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OperatorAdded(address indexed operator);
    event OperatorRemoved(address indexed operator);
    event LegalOperatorAdded(address indexed operator);
    event LegalOperatorRemoved(address indexed operator);
    event EntityOperatorAdded(address indexed operator);
    event EntityOperatorRemoved(address indexed operator);
    event ProofOperatorAdded(address indexed operator);
    event ProofOperatorRemoved(address indexed operator);
    event RecoveryInitiated(address indexed recoveryAddress, address indexed pendingOwner);
    event RecoveryExecuted(address indexed newOwner);
    event RecoveryCancelled();
    event RecoveryAddressUpdated(address indexed newRecoveryAddress);

    // =========================================================================
    // ACCESS CONTROL ERRORS
    // =========================================================================

    error NotOwner();
    error NotOperator();
    error NotLegalOperator();
    error NotEntityOperator();
    error NotProofOperator();
    error NotRecoveryAddress();
    error RecoveryNotInitiated();
    error RecoveryDelayNotMet();
    error RecoveryLockedOut();
    error ZeroAddress();

    // =========================================================================
    // ACCESS CONTROL MODIFIERS
    // =========================================================================

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    /// @notice Gate for standard registration (types 0-8, 12-16).
    modifier onlyOperator() {
        if (!operators[msg.sender]) revert NotOperator();
        _;
    }

    /// @notice Gate for LEGAL registration (type 9). No operators added at launch.
    ///         Owner calls addLegalOperator() to activate in V2-V3.
    modifier onlyLegalOperator() {
        if (!legalOperators[msg.sender]) revert NotLegalOperator();
        _;
    }

    /// @notice Gate for ENTITY registration (type 10). No operators added at launch.
    ///         Owner calls addEntityOperator() to activate in V2.
    modifier onlyEntityOperator() {
        if (!entityOperators[msg.sender]) revert NotEntityOperator();
        _;
    }

    /// @notice Gate for PROOF registration (type 11). No operators added at launch.
    ///         Owner calls addProofOperator() to activate in V4.
    modifier onlyProofOperator() {
        if (!proofOperators[msg.sender]) revert NotProofOperator();
        _;
    }

    // =========================================================================
    // CONSTRUCTOR
    // =========================================================================

    constructor(address _recoveryAddress) {
        if (_recoveryAddress == address(0)) revert ZeroAddress();
        owner           = msg.sender;
        recoveryAddress = _recoveryAddress;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    // =========================================================================
    // GOVERNANCE FUNCTIONS
    // =========================================================================

    function addOperator(address op) external onlyOwner {
        if (op == address(0)) revert ZeroAddress();
        operators[op] = true;
        emit OperatorAdded(op);
    }

    function removeOperator(address op) external onlyOwner {
        operators[op] = false;
        emit OperatorRemoved(op);
    }

    /// @notice Add a legal operator. Opens LEGAL registration (type 9).
    ///         Only call when document verification infrastructure is ready.
    ///         Legal operator is a cold wallet — LEGAL registrations are rare,
    ///         deliberate, and high-consequence.
    function addLegalOperator(address op) external onlyOwner {
        if (op == address(0)) revert ZeroAddress();
        legalOperators[op] = true;
        emit LegalOperatorAdded(op);
    }

    function removeLegalOperator(address op) external onlyOwner {
        legalOperators[op] = false;
        emit LegalOperatorRemoved(op);
    }

    /// @notice Add an entity operator. Opens ENTITY registration (type 10).
    ///         Only call when domain verification infrastructure is ready.
    ///         Entity operator is a cold wallet — ENTITY registrations are rare,
    ///         deliberate, and high-consequence.
    function addEntityOperator(address op) external onlyOwner {
        if (op == address(0)) revert ZeroAddress();
        entityOperators[op] = true;
        emit EntityOperatorAdded(op);
    }

    function removeEntityOperator(address op) external onlyOwner {
        entityOperators[op] = false;
        emit EntityOperatorRemoved(op);
    }

    /// @notice Add a proof operator. Opens PROOF registration (type 11).
    ///         Only call when ZK proof infrastructure is ready (V4).
    ///         Proof operator is a cold wallet — PROOF registrations require
    ///         verified cryptographic proof infrastructure.
    function addProofOperator(address op) external onlyOwner {
        if (op == address(0)) revert ZeroAddress();
        proofOperators[op] = true;
        emit ProofOperatorAdded(op);
    }

    function removeProofOperator(address op) external onlyOwner {
        proofOperators[op] = false;
        emit ProofOperatorRemoved(op);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // =========================================================================
    // RECOVERY FUNCTIONS
    // =========================================================================

    function initiateRecovery(address _pendingOwner) external {
        if (msg.sender != recoveryAddress)          revert NotRecoveryAddress();
        if (_pendingOwner == address(0))            revert ZeroAddress();
        if (block.timestamp < recoveryLockoutUntil) revert RecoveryLockedOut();
        pendingOwner        = _pendingOwner;
        recoveryInitiatedAt = block.timestamp;
        emit RecoveryInitiated(recoveryAddress, _pendingOwner);
    }

    function executeRecovery() external {
        if (msg.sender != recoveryAddress)                           revert NotRecoveryAddress();
        if (recoveryInitiatedAt == 0)                                revert RecoveryNotInitiated();
        if (block.timestamp < recoveryInitiatedAt + RECOVERY_DELAY)  revert RecoveryDelayNotMet();
        emit OwnershipTransferred(owner, pendingOwner);
        owner               = pendingOwner;
        pendingOwner        = address(0);
        recoveryInitiatedAt = 0;
        emit RecoveryExecuted(owner);
    }

    function cancelRecovery() external onlyOwner {
        pendingOwner         = address(0);
        recoveryInitiatedAt  = 0;
        recoveryLockoutUntil = block.timestamp + RECOVERY_LOCKOUT;
        emit RecoveryCancelled();
    }

    function setRecoveryAddress(address _newRecovery) external {
        if (msg.sender != recoveryAddress) revert NotRecoveryAddress();
        if (_newRecovery == address(0))    revert ZeroAddress();
        recoveryAddress = _newRecovery;
        emit RecoveryAddressUpdated(_newRecovery);
    }

    // =========================================================================
    // ARTIFACT TYPES
    // =========================================================================

    /// @notice Seventeen artifact types in six logical groups.
    ///
    ///         CONTENT (0-8)      — what creators make. Active at launch.
    ///         GATED (9-11)       — suppressed. Separate operator gates.
    ///         SELF-SERVICE (12)  — owner-initiated retraction. Active at launch.
    ///         REVIEW (13-15)     — AnchorRegistry authority. Active at launch.
    ///         CATCH-ALL (16)     — everything else. Active at launch.
    enum ArtifactType {
        // ── CONTENT (0-8) ─────────────────────────────────────────────────
        CODE,        // 0  repos, packages, commits, scripts
        RESEARCH,    // 1  papers, whitepapers, preprints, theses
        DATA,        // 2  training data, benchmarks, databases
        MODEL,       // 3  AI models, weights, checkpoints
        AGENT,       // 4  AI agents, bots, assistants
        MEDIA,       // 5  video, audio, images, photography
        TEXT,        // 6  blogs, articles, books, essays
        POST,        // 7  tweets, reddit, social
        ONCHAIN,     // 8  Ethereum addresses, transactions, contracts,
                     //    NFTs, token IDs, DAOs, multisigs
                     //    on-chain asset provenance and identity claims
                     //    onlyOperator.

        // ── GATED (9-11) ──────────────────────────────────────────────────
        LEGAL,       // 9  contracts, patents, filings (V2-V3)
                     //    onlyLegalOperator. No operators at deployment.
        ENTITY,      // 10 persons, companies, institutions (V2)
                     //    onlyEntityOperator. No operators at deployment.
        PROOF,       // 11 ZK proofs, cryptographic proofs,
                     //    formal verifications (V4)
                     //    onlyProofOperator. No operators at deployment.
                     //    Single artifact proofs. Complex multi-artifact
                     //    compliance proofs handled by companion
                     //    AnchorRegistryZKP.sol contract.

        // ── SELF-SERVICE (12) ─────────────────────────────────────────────
        RETRACTION,  // 12 Owner-initiated. Operator submits on behalf of creator
                     //    after off-chain ownership token verification.
                     //    Creator is retracting their own work.
                     //    Not a finding of fraud — owner's autonomous choice.

        // ── REVIEW (13-15) ────────────────────────────────────────────────
        REVIEW,      // 13 Review opened. Attached to specific node under review.
                     //    Marks anchor CONTESTED. Provisional. Reversible.
                     //    onlyOperator.
        VOID,        // 14 Hard finding. Attached to parent of fraud origin.
                     //    Cascades DOWN. Does not cascade up.
                     //    Permanent unless AFFIRMED via appeal.
                     //    onlyOperator.
        AFFIRMED,    // 15 Exoneration. Attached to REVIEW (found legitimate)
                     //    or VOID (appeal upheld, tree reinstated).
                     //    onlyOperator.

        // ── CATCH-ALL (16) ────────────────────────────────────────────────
        OTHER        // 16 catch all
    }

    // =========================================================================
    // BASE STRUCT
    // =========================================================================

    struct AnchorBase {
        ArtifactType artifactType;
        string manifestHash;  // SHA256 of SPDX or DAPX manifest
        string parentHash;    // AR-ID of parent anchor, empty if root
        string descriptor;    // human-readable e.g. ICMOORE-2026-UNISWAPPY
    }

    // =========================================================================
    // CONTENT STRUCTS — types 0-8
    // =========================================================================

    struct CodeAnchor     { AnchorBase base; string gitHash;      string license; string url; }
    struct ResearchAnchor { AnchorBase base; string doi;          string url; }
    struct DataAnchor     { AnchorBase base; string dataVersion;  string url; }
    struct ModelAnchor    { AnchorBase base; string modelVersion; string url; }
    struct AgentAnchor    { AnchorBase base; string agentVersion; string url; }
    struct MediaAnchor    { AnchorBase base; string mediaType;    string url; }
    struct TextAnchor     { AnchorBase base; string url; }
    struct PostAnchor     { AnchorBase base; string platform;     string url; }

    /// @notice On-chain asset provenance. Ethereum addresses, transactions,
    ///         contracts, NFTs, token IDs, DAOs, multisigs.
    ///         assetId is the address, tx hash, or token ID being anchored.
    ///         An ETH address anchor is an on-chain identity claim — the registrant
    ///         asserts ownership of that address at this moment in time.
    ///         chainId, assetType, and url are optional — empty string is valid.
    struct OnChainAnchor {
        AnchorBase base;
        string chainId;    // "base" | "ethereum" | "polygon" | "arbitrum" | etc.
        string assetType;  // "ADDRESS" | "TX" | "CONTRACT" | "NFT"
                           // "TOKEN" | "DAO" | "MULTISIG" | "OTHER"
        string assetId;    // the address, tx hash, token ID, or contract address
        string url;        // optional — basescan.org/address/0x... etc.
    }

    // =========================================================================
    // GATED STRUCTS — types 9-11 (suppressed at launch)
    // =========================================================================

    /// @notice Contracts, patents, filings, disclosures.
    ///         Requires document verification infrastructure.
    ///         Opens in V2-V3 when onlyLegalOperator operators are added.
    struct LegalAnchor {
        AnchorBase base;
        string docType;  // PATENT_APPLICATION | CONTRACT | COURT_FILING | DISCLOSURE
        string url;
    }

    /// @notice Persons, companies, institutions, governments, AI systems.
    ///         Requires domain verification infrastructure (DNS_TXT, GitHub, ORCID).
    ///         Opens in V2 when onlyEntityOperator operators are added.
    ///         claimedRoots stored off-chain in Supabase via canonicalUrl —
    ///         immutable parentHash on V1 anchors cannot be modified retroactively,
    ///         so entity-to-tree linkage is maintained in the resolution layer.
    struct EntityAnchor {
        AnchorBase base;
        string entityType;          // PERSON | COMPANY | INSTITUTION | GOVERNMENT
                                    // AI_SYSTEM | RESEARCH_GROUP | PROTOCOL
        string entityDomain;        // canonical domain e.g. icmoore.com
        string verificationMethod;  // DNS_TXT | GITHUB | ORCID | EMAIL
        string verificationProof;   // the specific proof string used
        string canonicalUrl;        // anchorregistry.ai/canonical/[entity-id]
        string documentHash;        // SHA256 of canonical document
    }

    /// @notice ZK proofs, cryptographic proofs, formal verifications.
    ///         Requires ZK proof infrastructure. Opens in V4.
    ///         For single artifact proofs — e.g. ZK proof of authorship,
    ///         ZK proof of prior art, formal verification of a specific claim.
    ///         Complex multi-artifact compliance proofs (e.g. training data
    ///         compliance across entire model lineage) are handled by the
    ///         companion AnchorRegistryZKP.sol contract which references
    ///         AR-IDs from this registry without touching the core contract.
    struct ProofAnchor {
        AnchorBase base;
        string proofType;    // ZK_PROOF | GROTH16 | PLONK | STARK
                             // FORMAL_VERIFICATION | OTHER
        string proofSystem;  // the specific proof system used
        string verifierUrl;  // on-chain verifier contract address or URL
        string proofHash;    // hash of the proof itself
    }

    // =========================================================================
    // SELF-SERVICE STRUCT — type 12
    // =========================================================================

    /// @notice Owner-initiated retraction. The creator is marking their own
    ///         anchor as retracted. Not a finding of fraud — an autonomous
    ///         choice by the registrant.
    ///         Operator submits on behalf of creator after off-chain ownership
    ///         token verification. The on-chain record cannot be deleted —
    ///         RETRACTION is a permanent annotation of the creator's intent.
    ///         replacedBy: optional AR-ID of a replacement anchor.
    ///         e.g. "I retracted v1.0 and registered v2.0 instead."
    struct RetractionAnchor {
        AnchorBase base;
        string targetArId;   // the anchor being retracted
        string reason;       // optional, owner-provided free text
        string replacedBy;   // optional AR-ID of replacement anchor
    }

    // =========================================================================
    // REVIEW STRUCTS — types 13-15
    // =========================================================================

    /// @notice Review opened. Attached to the specific node under review.
    ///         Marks the anchor CONTESTED pending investigation.
    ///         Only AnchorRegistry operators may attach.
    ///         parentHash in base should reference the reviewed anchor
    ///         to create an on-chain link in the tree.
    struct ReviewAnchor {
        AnchorBase base;
        string targetArId;   // the AR-ID of the anchor being reviewed
        string reviewType;  // MALICIOUS_TREE | IMPERSONATION | FALSE_AUTHORSHIP
                             // DEFAMATORY | OTHER
        string evidenceUrl;  // anchorregistry.com/reviews/[review-ar-id]
    }

    /// @notice Hard finding. Attached to the PARENT of the fraud origin.
    ///         Cascades DOWN — all descendants are condemned (VOID).
    ///         Does NOT cascade up — ancestors and siblings are unaffected.
    ///         Cascade is enforced off-chain by the resolution endpoint.
    ///         Only AnchorRegistry operators may attach.
    ///         A REVIEW anchor must have preceded this finding (reviewArId required).
    struct VoidAnchor {
        AnchorBase base;
        string targetArId;   // the parent AR-ID being condemned
        string reviewArId;  // the REVIEW anchor that preceded this finding
        string findingUrl;   // anchorregistry.com/reviews/[void-ar-id]
        string evidence;     // brief on-chain evidence summary
    }

    /// @notice Exoneration. Attached to a REVIEW or VOID anchor.
    ///         If attached to REVIEW: anchor was investigated, found legitimate.
    ///         If attached to VOID: appeal upheld, tree reinstated.
    ///         affirmedBy: INVESTIGATION or APPEAL.
    ///         Only AnchorRegistry operators may attach.
    ///         A tree that carries an AFFIRMED node is more trustworthy than
    ///         one that was never questioned — it was actively investigated
    ///         and found legitimate.
    struct AffirmedAnchor {
        AnchorBase base;
        string targetArId;   // the REVIEW or VOID AR-ID being affirmed
        string affirmedBy;   // INVESTIGATION | APPEAL
        string findingUrl;   // anchorregistry.com/reviews/[affirmed-ar-id]
    }

    // =========================================================================
    // CATCH-ALL STRUCT — type 16
    // =========================================================================

    struct OtherAnchor {
        AnchorBase base;
        string kind;
        string platform;
        string url;
        string value;
    }

    // =========================================================================
    // STORAGE
    // =========================================================================

    // Content anchors (types 0-8)
    mapping(string => CodeAnchor)       public codeAnchors;
    mapping(string => ResearchAnchor)   public researchAnchors;
    mapping(string => DataAnchor)       public dataAnchors;
    mapping(string => ModelAnchor)      public modelAnchors;
    mapping(string => AgentAnchor)      public agentAnchors;
    mapping(string => MediaAnchor)      public mediaAnchors;
    mapping(string => TextAnchor)       public textAnchors;
    mapping(string => PostAnchor)       public postAnchors;
    mapping(string => OnChainAnchor)    public onChainAnchors;

    // Gated anchors (types 9-11) — structs exist, register functions are gated
    mapping(string => LegalAnchor)      public legalAnchors;
    mapping(string => EntityAnchor)     public entityAnchors;
    mapping(string => ProofAnchor)      public proofAnchors;

    // Self-service anchors (type 12)
    mapping(string => RetractionAnchor) public retractionAnchors;

    // Review anchors (types 13-15)
    mapping(string => ReviewAnchor)     public reviewAnchors;
    mapping(string => VoidAnchor)       public voidAnchors;
    mapping(string => AffirmedAnchor)   public affirmedAnchors;

    // Catch-all anchors (type 16)
    mapping(string => OtherAnchor)      public otherAnchors;

    /// @notice Global AR-ID collision prevention. Once registered, an AR-ID
    ///         cannot be reused by any anchor type.
    mapping(string => bool) public registered;

    // =========================================================================
    // EVENTS
    // =========================================================================

    /// @notice Emitted on every successful anchor registration of any type.
    ///         Contains all fields needed to reconstruct the full registry
    ///         from Ethereum event logs alone. The contract address is the
    ///         only input required for complete off-chain recovery.
    event Anchored(
        string  indexed arId,
        address indexed registrant,
        ArtifactType    artifactType,
        string          descriptor,
        string          manifestHash,
        string          parentHash
    );

    /// @notice Emitted when a RETRACTION is registered.
    ///         Separate event — owner-initiated, not operator finding.
    event Retracted(
        string  indexed arId,
        string  indexed targetArId,
        string          replacedBy
    );

    /// @notice Emitted when a REVIEW anchor is registered.
    event Reviewed(
        string  indexed arId,
        string  indexed targetArId,
        string          reviewType,
        string          evidenceUrl
    );

    /// @notice Emitted when a VOID anchor is registered.
    event Voided(
        string  indexed arId,
        string  indexed targetArId,
        string  indexed reviewArId,
        string          evidence
    );

    /// @notice Emitted when an AFFIRMED anchor is registered.
    event Affirmed(
        string  indexed arId,
        string  indexed targetArId,
        string          affirmedBy
    );

    // =========================================================================
    // ERRORS
    // =========================================================================

    error AlreadyRegistered(string arId);
    error EmptyManifestHash();
    error EmptyArId();
    error InvalidParent(string parentHash);
    error EmptyTargetArId();
    error InvalidTarget(string targetArId);

    // =========================================================================
    // INTERNAL
    // =========================================================================

    function _validateBase(string calldata arId, AnchorBase calldata base) internal view {
        if (bytes(arId).length == 0)              revert EmptyArId();
        if (bytes(base.manifestHash).length == 0) revert EmptyManifestHash();
        if (registered[arId])                     revert AlreadyRegistered(arId);
        if (bytes(base.parentHash).length > 0 && !registered[base.parentHash])
                                                  revert InvalidParent(base.parentHash);
    }

    function _register(string calldata arId, AnchorBase calldata base) internal {
        registered[arId] = true;
        emit Anchored(arId, msg.sender, base.artifactType, base.descriptor, base.manifestHash, base.parentHash);
    }

    /// @notice Validates that a target AR-ID exists in the registry.
    ///         Used by review, retraction, and affirmed register functions.
    function _validateTarget(string calldata targetArId) internal view {
        if (bytes(targetArId).length == 0) revert EmptyTargetArId();
        if (!registered[targetArId])        revert InvalidTarget(targetArId);
    }

    // =========================================================================
    // REGISTER FUNCTIONS — CONTENT (types 0-8)
    // =========================================================================

    function registerCode(
        string calldata arId,
        AnchorBase calldata base,
        string calldata gitHash,
        string calldata license,
        string calldata url
    ) external onlyOperator {
        _validateBase(arId, base);
        codeAnchors[arId] = CodeAnchor(base, gitHash, license, url);
        _register(arId, base);
    }

    function registerResearch(
        string calldata arId,
        AnchorBase calldata base,
        string calldata doi,
        string calldata url
    ) external onlyOperator {
        _validateBase(arId, base);
        researchAnchors[arId] = ResearchAnchor(base, doi, url);
        _register(arId, base);
    }

    function registerData(
        string calldata arId,
        AnchorBase calldata base,
        string calldata dataVersion,
        string calldata url
    ) external onlyOperator {
        _validateBase(arId, base);
        dataAnchors[arId] = DataAnchor(base, dataVersion, url);
        _register(arId, base);
    }

    function registerModel(
        string calldata arId,
        AnchorBase calldata base,
        string calldata modelVersion,
        string calldata url
    ) external onlyOperator {
        _validateBase(arId, base);
        modelAnchors[arId] = ModelAnchor(base, modelVersion, url);
        _register(arId, base);
    }

    function registerAgent(
        string calldata arId,
        AnchorBase calldata base,
        string calldata agentVersion,
        string calldata url
    ) external onlyOperator {
        _validateBase(arId, base);
        agentAnchors[arId] = AgentAnchor(base, agentVersion, url);
        _register(arId, base);
    }

    function registerMedia(
        string calldata arId,
        AnchorBase calldata base,
        string calldata mediaType,
        string calldata url
    ) external onlyOperator {
        _validateBase(arId, base);
        mediaAnchors[arId] = MediaAnchor(base, mediaType, url);
        _register(arId, base);
    }

    function registerText(
        string calldata arId,
        AnchorBase calldata base,
        string calldata url
    ) external onlyOperator {
        _validateBase(arId, base);
        textAnchors[arId] = TextAnchor(base, url);
        _register(arId, base);
    }

    function registerPost(
        string calldata arId,
        AnchorBase calldata base,
        string calldata platform,
        string calldata url
    ) external onlyOperator {
        _validateBase(arId, base);
        postAnchors[arId] = PostAnchor(base, platform, url);
        _register(arId, base);
    }

    /// @notice Registers an on-chain asset anchor: Ethereum addresses, transactions,
    ///         contracts, NFTs, token IDs, DAOs, multisigs.
    ///         An ETH address anchor is an on-chain identity claim — the registrant
    ///         asserts that the anchored address belongs to them at this moment.
    ///         Combined with parentHash, a wallet address anchor can serve as the
    ///         trustless root of an entire artifact tree without ENTITY verification.
    ///         chainId, assetType, and url are optional — empty string is valid.
    function registerOnChain(
        string calldata arId,
        AnchorBase calldata base,
        string calldata chainId,
        string calldata assetType,
        string calldata assetId,
        string calldata url
    ) external onlyOperator {
        _validateBase(arId, base);
        onChainAnchors[arId] = OnChainAnchor(base, chainId, assetType, assetId, url);
        _register(arId, base);
    }

    // =========================================================================
    // REGISTER FUNCTIONS — GATED (types 9-11, suppressed at launch)
    // =========================================================================

    /// @notice LEGAL registration (type 9). Gate: onlyLegalOperator.
    ///         No operators added at deployment — zero attack surface until activated.
    ///         Registers a legal document anchor: contracts, patents, filings.
    ///         Opens in V2-V3 when document verification infrastructure is ready.
    ///         Owner calls addLegalOperator() to activate. Legal operator is a cold wallet.
    function registerLegal(
        string calldata arId,
        AnchorBase calldata base,
        string calldata docType,
        string calldata url
    ) external onlyLegalOperator {
        _validateBase(arId, base);
        legalAnchors[arId] = LegalAnchor(base, docType, url);
        _register(arId, base);
    }

    /// @notice ENTITY registration (type 10). Gate: onlyEntityOperator.
    ///         No operators added at deployment — zero attack surface until activated.
    ///         Registers a verified entity anchor: person, company, institution.
    ///         Opens in V2 when domain verification infrastructure is ready.
    ///         Owner calls addEntityOperator() to activate. Entity operator is a cold wallet.
    ///         claimedRoots stored off-chain in Supabase via canonicalUrl —
    ///         immutable parentHash on V1 anchors cannot be modified retroactively,
    ///         so entity-to-tree linkage is maintained in the resolution layer.
    function registerEntity(
        string calldata arId,
        AnchorBase calldata base,
        string calldata entityType,
        string calldata entityDomain,
        string calldata verificationMethod,
        string calldata verificationProof,
        string calldata canonicalUrl,
        string calldata documentHash
    ) external onlyEntityOperator {
        _validateBase(arId, base);
        entityAnchors[arId] = EntityAnchor(
            base,
            entityType,
            entityDomain,
            verificationMethod,
            verificationProof,
            canonicalUrl,
            documentHash
        );
        _register(arId, base);
    }

    /// @notice PROOF registration (type 11). Gate: onlyProofOperator.
    ///         No operators added at deployment — zero attack surface until activated.
    ///         Registers a cryptographic proof artifact: ZK proofs, formal
    ///         verifications, cryptographic proofs of specific claims.
    ///         Opens in V4 when ZK infrastructure is ready.
    ///         Owner calls addProofOperator() to activate. Proof operator is a cold wallet.
    ///         For complex multi-artifact compliance proofs (e.g. proving
    ///         training data compliance across an entire model lineage),
    ///         use the companion AnchorRegistryZKP.sol contract which
    ///         references AR-IDs from this registry.
    function registerProof(
        string calldata arId,
        AnchorBase calldata base,
        string calldata proofType,
        string calldata proofSystem,
        string calldata verifierUrl,
        string calldata proofHash
    ) external onlyProofOperator {
        _validateBase(arId, base);
        proofAnchors[arId] = ProofAnchor(base, proofType, proofSystem, verifierUrl, proofHash);
        _register(arId, base);
    }

    // =========================================================================
    // REGISTER FUNCTIONS — SELF-SERVICE (type 12)
    // =========================================================================

    /// @notice Register a RETRACTION on behalf of the anchor's owner.
    ///         The creator is retracting their own work — this is not a finding
    ///         of fraud. It is an autonomous choice by the registrant.
    ///         Ownership is verified off-chain by FastAPI via ownership token
    ///         before this function is called by the operator.
    ///         The original anchor is not deleted — the Anchored event is
    ///         permanent. RETRACTION is a permanent annotation of intent.
    ///         replacedBy: optional AR-ID of a replacement anchor.
    function registerRetraction(
        string calldata arId,
        AnchorBase calldata base,
        string calldata targetArId,
        string calldata reason,
        string calldata replacedBy
    ) external onlyOperator {
        _validateBase(arId, base);
        _validateTarget(targetArId);
        retractionAnchors[arId] = RetractionAnchor(base, targetArId, reason, replacedBy);
        _register(arId, base);
        emit Retracted(arId, targetArId, replacedBy);
    }

    // =========================================================================
    // REGISTER FUNCTIONS — REVIEW SYSTEM (types 13-15)
    // =========================================================================

    /// @notice Attach a REVIEW anchor to a flagged node.
    ///         Marks the target anchor CONTESTED pending investigation.
    ///         Only AnchorRegistry operators may call this.
    ///         The target must be a registered AR-ID.
    ///         parentHash in base should reference the reviewed anchor
    ///         to create an on-chain link in the tree.
    function registerReview(
        string calldata arId,
        AnchorBase calldata base,
        string calldata targetArId,
        string calldata reviewType,
        string calldata evidenceUrl
    ) external onlyOperator {
        _validateBase(arId, base);
        _validateTarget(targetArId);
        reviewAnchors[arId] = ReviewAnchor(base, targetArId, reviewType, evidenceUrl);
        _register(arId, base);
        emit Reviewed(arId, targetArId, reviewType, evidenceUrl);
    }

    /// @notice Attach a VOID anchor to the parent of the fraud origin.
    ///         Permanently condemns the target and all its descendants.
    ///         Cascade is enforced off-chain by the resolution endpoint —
    ///         any anchor with a VOID node in its ancestry is condemned.
    ///         Does not cascade up — ancestors and siblings are unaffected.
    ///         Only AnchorRegistry operators may call this.
    ///         A REVIEW anchor must have preceded this (reviewArId required).
    function registerVoid(
        string calldata arId,
        AnchorBase calldata base,
        string calldata targetArId,
        string calldata reviewArId,
        string calldata findingUrl,
        string calldata evidence
    ) external onlyOperator {
        _validateBase(arId, base);
        _validateTarget(targetArId);
        _validateTarget(reviewArId);
        voidAnchors[arId] = VoidAnchor(base, targetArId, reviewArId, findingUrl, evidence);
        _register(arId, base);
        emit Voided(arId, targetArId, reviewArId, evidence);
    }

    /// @notice Attach an AFFIRMED anchor to a REVIEW or VOID anchor.
    ///         If affirming a REVIEW: anchor was investigated, found legitimate.
    ///         If affirming a VOID: appeal upheld, tree reinstated.
    ///         affirmedBy must be INVESTIGATION or APPEAL.
    ///         Only AnchorRegistry operators may call this.
    ///         A tree carrying an AFFIRMED node is more trustworthy than one
    ///         never questioned — actively investigated and found legitimate.
    function registerAffirmed(
        string calldata arId,
        AnchorBase calldata base,
        string calldata targetArId,
        string calldata affirmedBy,
        string calldata findingUrl
    ) external onlyOperator {
        _validateBase(arId, base);
        _validateTarget(targetArId);
        affirmedAnchors[arId] = AffirmedAnchor(base, targetArId, affirmedBy, findingUrl);
        _register(arId, base);
        emit Affirmed(arId, targetArId, affirmedBy);
    }

    // =========================================================================
    // REGISTER FUNCTIONS — CATCH-ALL (type 16)
    // =========================================================================

    function registerOther(
        string calldata arId,
        AnchorBase calldata base,
        string calldata kind,
        string calldata platform,
        string calldata url,
        string calldata value
    ) external onlyOperator {
        _validateBase(arId, base);
        otherAnchors[arId] = OtherAnchor(base, kind, platform, url, value);
        _register(arId, base);
    }

}
