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
///         Eighteen artifact types in six logical groups:
///
///         CONTENT (0-8):     CODE, RESEARCH, DATA, MODEL, AGENT, MEDIA, TEXT, POST, ONCHAIN
///                            What creators make. Active at launch. onlyOperator.
///                            ONCHAIN: Ethereum addresses, transactions, contracts,
///                            NFTs, token IDs, DAOs, multisigs — on-chain asset provenance.
///
///         TRANSACTION (9):   RECEIPT
///                            Proof of commercial, medical, financial, government,
///                            event, or service transactions. Active at launch.
///                            onlyOperator. receiptType field handles subtypes:
///                            PURCHASE | MEDICAL | FINANCIAL | GOVERNMENT | EVENT | SERVICE
///
///         GATED (10-12):     LEGAL, ENTITY, PROOF
///                            Suppressed at launch. Separate operator gates.
///                            LEGAL opens in V2-V3 with document verification.
///                            ENTITY opens in V2 with domain verification.
///                            PROOF opens in V4 with ZK infrastructure.
///
///         SELF-SERVICE (13): RETRACTION
///                            Owner-initiated. Active at launch. Operator submits
///                            on behalf of creator after ownership token verification.
///
///         REVIEW (14-16):    REVIEW, VOID, AFFIRMED
///                            AnchorRegistry operator-only. Active at launch.
///                            REVIEW: soft flag, anchor under review.
///                            VOID: hard finding, subtree condemned, cascades down.
///                            AFFIRMED: exoneration, review resolved.
///
///         CATCH-ALL (17):    OTHER
///
///         Four access gates:
///         onlyOperator      — types 0-9, 13-17
///         onlyLegalOperator — type 10  (no operators added at deployment)
///         onlyEntityOperator— type 11  (no operators added at deployment)
///         onlyProofOperator — type 12  (no operators added at deployment)

contract AnchorRegistry {

    // =========================================================================
    // ACCESS CONTROL STORAGE
    // =========================================================================

    address public owner;
    address public recoveryAddress;

    /// @notice Standard operators — content, transaction, retraction, review, and other types.
    ///         Can register types 0-9, 13-17. Cannot call registerLegal, registerEntity, or registerProof.
    mapping(address => bool) public operators;

    /// @notice Legal operators — LEGAL registration only (type 10).
    ///         Not added at deployment. Opens in V2-V3 with document verification.
    mapping(address => bool) public legalOperators;

    /// @notice Entity operators — ENTITY registration only (type 11).
    ///         Not added at deployment. Opens in V2 with domain verification.
    mapping(address => bool) public entityOperators;

    /// @notice Proof operators — PROOF registration only (type 12).
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

    /// @notice Gate for standard registration (types 0-9, 13-17).
    modifier onlyOperator() {
        if (!operators[msg.sender]) revert NotOperator();
        _;
    }

    /// @notice Gate for LEGAL registration (type 10). No operators added at launch.
    ///         Owner calls addLegalOperator() to activate in V2-V3.
    modifier onlyLegalOperator() {
        if (!legalOperators[msg.sender]) revert NotLegalOperator();
        _;
    }

    /// @notice Gate for ENTITY registration (type 11). No operators added at launch.
    ///         Owner calls addEntityOperator() to activate in V2.
    modifier onlyEntityOperator() {
        if (!entityOperators[msg.sender]) revert NotEntityOperator();
        _;
    }

    /// @notice Gate for PROOF registration (type 12). No operators added at launch.
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

    /// @notice Add a legal operator. Opens LEGAL registration (type 10).
    ///         Only call when document verification infrastructure is ready.
    function addLegalOperator(address op) external onlyOwner {
        if (op == address(0)) revert ZeroAddress();
        legalOperators[op] = true;
        emit LegalOperatorAdded(op);
    }

    function removeLegalOperator(address op) external onlyOwner {
        legalOperators[op] = false;
        emit LegalOperatorRemoved(op);
    }

    /// @notice Add an entity operator. Opens ENTITY registration (type 11).
    ///         Only call when domain verification infrastructure is ready.
    function addEntityOperator(address op) external onlyOwner {
        if (op == address(0)) revert ZeroAddress();
        entityOperators[op] = true;
        emit EntityOperatorAdded(op);
    }

    function removeEntityOperator(address op) external onlyOwner {
        entityOperators[op] = false;
        emit EntityOperatorRemoved(op);
    }

    /// @notice Add a proof operator. Opens PROOF registration (type 12).
    ///         Only call when ZK proof infrastructure is ready (V4).
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

    /// @notice Eighteen artifact types in six logical groups.
    ///
    ///         CONTENT (0-8)      — what creators make. Active at launch.
    ///         TRANSACTION (9)    — proof of transaction or exchange. Active at launch.
    ///         GATED (10-12)      — suppressed. Separate operator gates.
    ///         SELF-SERVICE (13)  — owner-initiated retraction. Active at launch.
    ///         REVIEW (14-16)     — AnchorRegistry authority. Active at launch.
    ///         CATCH-ALL (17)     — everything else. Active at launch.
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

        // ── TRANSACTION (9) ───────────────────────────────────────────────
        RECEIPT,     // 9  proof of commercial, medical, financial, government,
                     //    event, or service transactions.
                     //    receiptType field handles subtypes:
                     //    PURCHASE | MEDICAL | FINANCIAL | GOVERNMENT | EVENT | SERVICE
                     //    onlyOperator. Active at launch.

        // ── GATED (10-12) ─────────────────────────────────────────────────
        LEGAL,       // 10 contracts, patents, filings (V2-V3)
                     //    onlyLegalOperator. No operators at deployment.
        ENTITY,      // 11 persons, companies, institutions (V2)
                     //    onlyEntityOperator. No operators at deployment.
        PROOF,       // 12 ZK proofs, cryptographic proofs,
                     //    formal verifications (V4)
                     //    onlyProofOperator. No operators at deployment.
                     //    Single artifact proofs. Complex multi-artifact
                     //    compliance proofs handled by companion
                     //    AnchorRegistryZKP.sol contract.

        // ── SELF-SERVICE (13) ─────────────────────────────────────────────
        RETRACTION,  // 13 Owner-initiated. Operator submits on behalf of creator
                     //    after off-chain ownership token verification.
                     //    Creator is retracting their own work.
                     //    Not a finding of fraud — owner's autonomous choice.

        // ── REVIEW (14-16) ────────────────────────────────────────────────
        REVIEW,      // 14 Review opened. Attached to specific node under review.
                     //    Marks anchor CONTESTED. Provisional. Reversible.
                     //    onlyOperator.
        VOID,        // 15 Hard finding. Attached to parent of fraud origin.
                     //    Cascades DOWN. Does not cascade up.
                     //    Permanent unless AFFIRMED via appeal.
                     //    onlyOperator.
        AFFIRMED,    // 16 Exoneration. Attached to REVIEW (found legitimate)
                     //    or VOID (appeal upheld, tree reinstated).
                     //    onlyOperator.

        // ── CATCH-ALL (17) ────────────────────────────────────────────────
        OTHER        // 17 catch all
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
    struct OnChainAnchor {
        AnchorBase base;
        string chainId;    // "base" | "ethereum" | "polygon" | "arbitrum" | etc.
        string assetType;  // "ADDRESS" | "TX" | "CONTRACT" | "NFT"
                           // "TOKEN" | "DAO" | "MULTISIG" | "OTHER"
        string assetId;    // the address, tx hash, token ID, or contract address
        string url;        // optional — basescan.org/address/0x... etc.
    }

    // =========================================================================
    // TRANSACTION STRUCT — type 9
    // =========================================================================

    /// @notice Proof of transaction or exchange. Active at launch. onlyOperator.
    ///         The manifest hash is a SHA256 of the structured receipt data —
    ///         merchant, amount, order ID, date, items. Anyone with the original
    ///         receipt data can independently verify the hash matches.
    ///         receiptType handles all transaction subtypes:
    ///           PURCHASE   — retail, e-commerce, point of sale
    ///           MEDICAL    — prescription, procedure, insurance payment
    ///           FINANCIAL  — wire transfer, trade confirmation, crypto tx
    ///           GOVERNMENT — tax payment, permit, filing acknowledgment
    ///           EVENT      — ticket, boarding pass, hotel stay
    ///           SERVICE    — contractor, mechanic, repair, professional service
    struct ReceiptAnchor {
        AnchorBase base;
        string receiptType;  // PURCHASE | MEDICAL | FINANCIAL | GOVERNMENT | EVENT | SERVICE
        string merchant;     // merchant name or identifier
        string amount;       // transaction amount as string e.g. "1299.99"
        string currency;     // ISO 4217 currency code e.g. "USD" | "CAD" | "EUR"
        string orderId;      // merchant order ID or transaction reference
        string platform;     // optional — "shopify" | "stripe" | "square" | etc.
        string url;          // optional — receipt URL or IPFS hash
    }

    // =========================================================================
    // GATED STRUCTS — types 10-12 (suppressed at launch)
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
    struct ProofAnchor {
        AnchorBase base;
        string proofType;    // ZK_PROOF | GROTH16 | PLONK | STARK
                             // FORMAL_VERIFICATION | OTHER
        string proofSystem;  // the specific proof system used
        string verifierUrl;  // on-chain verifier contract address or URL
        string proofHash;    // hash of the proof itself
    }

    // =========================================================================
    // SELF-SERVICE STRUCT — type 13
    // =========================================================================

    /// @notice Owner-initiated retraction. The creator is marking their own
    ///         anchor as retracted. Not a finding of fraud — an autonomous
    ///         choice by the registrant.
    struct RetractionAnchor {
        AnchorBase base;
        string targetArId;   // the anchor being retracted
        string reason;       // optional, owner-provided free text
        string replacedBy;   // optional AR-ID of replacement anchor
    }

    // =========================================================================
    // REVIEW STRUCTS — types 14-16
    // =========================================================================

    /// @notice Review opened. Attached to the specific node under review.
    struct ReviewAnchor {
        AnchorBase base;
        string targetArId;  // the AR-ID of the anchor being reviewed
        string reviewType;  // MALICIOUS_TREE | IMPERSONATION | FALSE_AUTHORSHIP
                            // DEFAMATORY | OTHER
        string evidenceUrl; // anchorregistry.com/reviews/[review-ar-id]
    }

    /// @notice Hard finding. Attached to the PARENT of the fraud origin.
    ///         Cascades DOWN — all descendants are condemned (VOID).
    struct VoidAnchor {
        AnchorBase base;
        string targetArId;  // the parent AR-ID being condemned
        string reviewArId;  // the REVIEW anchor that preceded this finding
        string findingUrl;  // anchorregistry.com/reviews/[void-ar-id]
        string evidence;    // brief on-chain evidence summary
    }

    /// @notice Exoneration. Attached to a REVIEW or VOID anchor.
    struct AffirmedAnchor {
        AnchorBase base;
        string targetArId;  // the REVIEW or VOID AR-ID being affirmed
        string affirmedBy;  // INVESTIGATION | APPEAL
        string findingUrl;  // anchorregistry.com/reviews/[affirmed-ar-id]
    }

    // =========================================================================
    // CATCH-ALL STRUCT — type 17
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

    // Transaction anchors (type 9)
    mapping(string => ReceiptAnchor)    public receiptAnchors;

    // Gated anchors (types 10-12) — structs exist, register functions are gated
    mapping(string => LegalAnchor)      public legalAnchors;
    mapping(string => EntityAnchor)     public entityAnchors;
    mapping(string => ProofAnchor)      public proofAnchors;

    // Self-service anchors (type 13)
    mapping(string => RetractionAnchor) public retractionAnchors;

    // Review anchors (types 14-16)
    mapping(string => ReviewAnchor)     public reviewAnchors;
    mapping(string => VoidAnchor)       public voidAnchors;
    mapping(string => AffirmedAnchor)   public affirmedAnchors;

    // Catch-all anchors (type 17)
    mapping(string => OtherAnchor)      public otherAnchors;

    /// @notice Global AR-ID collision prevention.
    mapping(string => bool) public registered;

    // =========================================================================
    // EVENTS
    // =========================================================================

    event Anchored(
        string  indexed arId,
        address indexed registrant,
        ArtifactType    artifactType,
        string          descriptor,
        string          manifestHash,
        string          parentHash
    );

    event Retracted(
        string  indexed arId,
        string  indexed targetArId,
        string          replacedBy
    );

    event Reviewed(
        string  indexed arId,
        string  indexed targetArId,
        string          reviewType,
        string          evidenceUrl
    );

    event Voided(
        string  indexed arId,
        string  indexed targetArId,
        string  indexed reviewArId,
        string          evidence
    );

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
    // REGISTER FUNCTIONS — TRANSACTION (type 9)
    // =========================================================================

    /// @notice Register a RECEIPT anchor. Active at launch. onlyOperator.
    ///         The manifest hash is a SHA256 of the structured receipt data.
    ///         Anyone with the original receipt data can independently verify
    ///         the hash matches — no external verification infrastructure required.
    ///         receiptType: PURCHASE | MEDICAL | FINANCIAL | GOVERNMENT | EVENT | SERVICE
    ///         amount: string e.g. "1299.99" — preserve precision without float risk.
    ///         currency: ISO 4217 code e.g. "USD" | "CAD" | "EUR".
    ///         merchant, orderId, platform, url: all optional — empty string valid.
    function registerReceipt(
        string calldata arId,
        AnchorBase calldata base,
        string calldata receiptType,
        string calldata merchant,
        string calldata amount,
        string calldata currency,
        string calldata orderId,
        string calldata platform,
        string calldata url
    ) external onlyOperator {
        _validateBase(arId, base);
        receiptAnchors[arId] = ReceiptAnchor(
            base, receiptType, merchant, amount, currency, orderId, platform, url
        );
        _register(arId, base);
    }

    // =========================================================================
    // REGISTER FUNCTIONS — GATED (types 10-12, suppressed at launch)
    // =========================================================================

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
            base, entityType, entityDomain,
            verificationMethod, verificationProof,
            canonicalUrl, documentHash
        );
        _register(arId, base);
    }

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
    // REGISTER FUNCTIONS — SELF-SERVICE (type 13)
    // =========================================================================

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
    // REGISTER FUNCTIONS — REVIEW SYSTEM (types 14-16)
    // =========================================================================

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
    // REGISTER FUNCTIONS — CATCH-ALL (type 17)
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
