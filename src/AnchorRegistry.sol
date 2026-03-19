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
///         Nineteen artifact types in seven logical groups:
///
///         CONTENT (0-8):     CODE, RESEARCH, DATA, MODEL, AGENT, MEDIA, TEXT, POST, ONCHAIN
///                            What creators make. Active at launch. onlyOperator.
///                            ONCHAIN: Ethereum addresses, transactions, contracts,
///                            NFTs, token IDs, DAOs, multisigs — on-chain asset provenance.
///
///         LIFECYCLE (9):     EVENT
///                            Real-world and on-chain events — conferences, launches,
///                            performances, governance votes, protocol milestones.
///                            Active at launch. onlyOperator.
///
///         TRANSACTION (10):  RECEIPT
///                            Proof of commercial, medical, financial, government,
///                            event, or service transactions. Active at launch.
///                            onlyOperator. receiptType field handles subtypes:
///                            PURCHASE | MEDICAL | FINANCIAL | GOVERNMENT | EVENT | SERVICE
///
///         GATED (11-13):     LEGAL, ENTITY, PROOF
///                            Suppressed at launch. Separate operator gates.
///                            LEGAL opens in V2-V3 with document verification.
///                            ENTITY opens in V2 with domain verification.
///                            PROOF opens in V4 with ZK infrastructure.
///
///         SELF-SERVICE (14): RETRACTION
///                            Owner-initiated. Active at launch. Operator submits
///                            on behalf of creator after ownership token verification.
///
///         REVIEW (15-17):    REVIEW, VOID, AFFIRMED
///                            AnchorRegistry operator-only. Active at launch.
///                            REVIEW: soft flag, anchor under review.
///                            VOID: hard finding, subtree condemned, cascades down.
///                            AFFIRMED: exoneration, review resolved.
///
///         CATCH-ALL (18):    OTHER
///
///         Four access gates:
///         onlyOperator      — types 0-10, 14-18
///         onlyLegalOperator — type 11  (no operators added at deployment)
///         onlyEntityOperator— type 12  (no operators added at deployment)
///         onlyProofOperator — type 13  (no operators added at deployment)

contract AnchorRegistry {

    // =========================================================================
    // ACCESS CONTROL STORAGE
    // =========================================================================

    address public owner;
    address public recoveryAddress;

    mapping(address => bool) public operators;
    mapping(address => bool) public legalOperators;
    mapping(address => bool) public entityOperators;
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

    modifier onlyOperator() {
        if (!operators[msg.sender]) revert NotOperator();
        _;
    }

    modifier onlyLegalOperator() {
        if (!legalOperators[msg.sender]) revert NotLegalOperator();
        _;
    }

    modifier onlyEntityOperator() {
        if (!entityOperators[msg.sender]) revert NotEntityOperator();
        _;
    }

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

    function addLegalOperator(address op) external onlyOwner {
        if (op == address(0)) revert ZeroAddress();
        legalOperators[op] = true;
        emit LegalOperatorAdded(op);
    }

    function removeLegalOperator(address op) external onlyOwner {
        legalOperators[op] = false;
        emit LegalOperatorRemoved(op);
    }

    function addEntityOperator(address op) external onlyOwner {
        if (op == address(0)) revert ZeroAddress();
        entityOperators[op] = true;
        emit EntityOperatorAdded(op);
    }

    function removeEntityOperator(address op) external onlyOwner {
        entityOperators[op] = false;
        emit EntityOperatorRemoved(op);
    }

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

    enum ArtifactType {
        // ── CONTENT (0-8) ─────────────────────────────────────────────────
        CODE,        // 0
        RESEARCH,    // 1
        DATA,        // 2
        MODEL,       // 3
        AGENT,       // 4
        MEDIA,       // 5
        TEXT,        // 6
        POST,        // 7
        ONCHAIN,     // 8

        // ── LIFECYCLE (9) ─────────────────────────────────────────────────
        EVENT,       // 9

        // ── TRANSACTION (10) ──────────────────────────────────────────────
        RECEIPT,     // 10

        // ── GATED (11-13) ─────────────────────────────────────────────────
        LEGAL,       // 11
        ENTITY,      // 12
        PROOF,       // 13

        // ── SELF-SERVICE (14) ─────────────────────────────────────────────
        RETRACTION,  // 14

        // ── REVIEW (15-17) ────────────────────────────────────────────────
        REVIEW,      // 15
        VOID,        // 16
        AFFIRMED,    // 17

        // ── CATCH-ALL (18) ────────────────────────────────────────────────
        OTHER        // 18
    }

    // =========================================================================
    // BASE STRUCT
    // =========================================================================

    struct AnchorBase {
        ArtifactType artifactType;
        string manifestHash;  // SHA256 of full manifest (all fields including off-chain)
        string parentHash;    // AR-ID of parent anchor, empty if root
        string descriptor;    // human-readable e.g. ICMOORE-2026-UNISWAPPY
    }

    // =========================================================================
    // CONTENT STRUCTS — types 0-8
    // =========================================================================

    /// @notice CODE — repos, packages, commits, scripts.
    ///         gitHash: specific commit hash being anchored.
    ///         license: SPDX license identifier e.g. MIT, Apache-2.0.
    ///         language: primary language e.g. Python, TypeScript, Rust.
    ///         version: semver e.g. v1.0.0.
    ///         url: canonical repo URL e.g. github.com/user/repo.
    struct CodeAnchor {
        AnchorBase base;
        string gitHash;   // commit hash
        string license;   // SPDX identifier
        string language;  // primary language
        string version;   // semver
        string url;       // repo URL
    }

    /// @notice RESEARCH — papers, whitepapers, preprints, theses.
    ///         doi: Digital Object Identifier e.g. 10.1234/example.
    ///         institution: affiliated institution e.g. MIT, Stanford.
    ///         coAuthors: comma-separated co-author names.
    ///         url: canonical paper URL e.g. arxiv.org/abs/...
    struct ResearchAnchor {
        AnchorBase base;
        string doi;         // DOI
        string institution; // affiliated institution
        string coAuthors;   // comma-separated co-authors
        string url;         // paper URL
    }

    /// @notice DATA — datasets, benchmarks, databases.
    ///         dataVersion: dataset version string.
    ///         format: file format e.g. CSV, Parquet, JSON.
    ///         rowCount: approximate row count as string e.g. "1000000".
    ///         schemaUrl: URL to schema definition.
    ///         url: canonical dataset URL or DOI.
    struct DataAnchor {
        AnchorBase base;
        string dataVersion; // version
        string format;      // CSV, Parquet, JSON, etc.
        string rowCount;    // approximate size
        string schemaUrl;   // schema definition URL
        string url;         // dataset URL
    }

    /// @notice MODEL — AI models, weights, checkpoints.
    ///         modelVersion: version string.
    ///         architecture: model architecture e.g. Transformer, CNN.
    ///         parameters: parameter count e.g. "7B", "70B".
    ///         trainingDataset: training data description or URL.
    ///         url: canonical model URL e.g. huggingface.co/...
    struct ModelAnchor {
        AnchorBase base;
        string modelVersion;     // version
        string architecture;     // Transformer, CNN, etc.
        string parameters;       // 7B, 70B, etc.
        string trainingDataset;  // training data reference
        string url;              // model URL
    }

    /// @notice AGENT — AI agents, bots, assistants.
    ///         agentVersion: version string.
    ///         runtime: execution runtime e.g. Python 3.11, Node 20.
    ///         capabilities: comma-separated capability list.
    ///         url: canonical agent URL or repo.
    struct AgentAnchor {
        AnchorBase base;
        string agentVersion;  // version
        string runtime;       // Python 3.11, Node 20, etc.
        string capabilities;  // comma-separated
        string url;           // agent URL
    }

    /// @notice MEDIA — video, audio, images, photography.
    ///         mediaType: MIME type or category e.g. video/mp4, image/png.
    ///         format: specific format e.g. MP4, PNG, MP3.
    ///         duration: duration or dimensions e.g. "3:45" or "1920x1080".
    ///         isrc: ISRC or ISAN identifier for registered media.
    ///         url: canonical media URL.
    struct MediaAnchor {
        AnchorBase base;
        string mediaType;  // MIME type or category
        string format;     // MP4, PNG, MP3, etc.
        string duration;   // duration or dimensions
        string isrc;       // ISRC / ISAN identifier
        string url;        // media URL
    }

    /// @notice TEXT — blogs, articles, books, essays.
    ///         isbn: ISBN for published books.
    ///         publisher: publisher name.
    ///         language: language of the text e.g. English, French.
    ///         url: canonical text URL.
    struct TextAnchor {
        AnchorBase base;
        string isbn;       // ISBN
        string publisher;  // publisher name
        string language;   // language
        string url;        // text URL
    }

    /// @notice POST — tweets, reddit posts, social content.
    ///         platform: social platform e.g. Twitter, LinkedIn, Farcaster.
    ///         postId: platform-specific post ID.
    ///         postDate: ISO 8601 date of the post e.g. 2026-03-16.
    ///         url: direct URL to the post.
    struct PostAnchor {
        AnchorBase base;
        string platform;  // Twitter, LinkedIn, Farcaster, etc.
        string postId;    // platform post ID
        string postDate;  // ISO 8601 date
        string url;       // post URL
    }

    /// @notice ONCHAIN — Ethereum addresses, transactions, contracts, NFTs,
    ///         token IDs, DAOs, multisigs. On-chain asset provenance.
    ///         chainId: chain identifier e.g. ethereum, base, polygon.
    ///         assetType: ADDRESS | TX | CONTRACT | NFT | TOKEN | DAO | MULTISIG | OTHER.
    ///         contractAddress: smart contract address (0x...).
    ///         txHash: transaction hash (0x...).
    ///         tokenId: NFT or token ID.
    ///         blockNumber: block number of the relevant transaction.
    ///         url: explorer URL e.g. basescan.org/address/0x...
    struct OnChainAnchor {
        AnchorBase base;
        string chainId;          // ethereum, base, polygon, etc.
        string assetType;        // ADDRESS | TX | CONTRACT | NFT | TOKEN | DAO | MULTISIG | OTHER
        string contractAddress;  // 0x... (optional if using txHash)
        string txHash;           // 0x... (optional if using contractAddress)
        string tokenId;          // NFT or token ID
        string blockNumber;      // block number
        string url;              // explorer URL
    }

    // =========================================================================
    // LIFECYCLE STRUCT — type 9
    // =========================================================================

    /// @notice EVENT — real-world and on-chain events.
    ///         Conferences, product launches, performances, governance votes,
    ///         protocol milestones, live recordings, competition results.
    ///         eventType: CONFERENCE | LAUNCH | PERFORMANCE | GOVERNANCE | MILESTONE | COMPETITION | OTHER
    ///         eventDate: ISO 8601 date or date-time e.g. 2026-03-16 or 2026-03-16T19:00:00Z.
    ///         location: venue name, city, or "online" for virtual events.
    ///         organizer: organizing entity or person.
    ///         url: canonical event URL, recording, or result page.
    struct EventAnchor {
        AnchorBase base;
        string eventType;   // CONFERENCE | LAUNCH | PERFORMANCE | GOVERNANCE | MILESTONE | COMPETITION | OTHER
        string eventDate;   // ISO 8601 date or datetime
        string location;    // venue, city, or "online"
        string organizer;   // organizing entity or person
        string url;         // event URL, recording, or result page
    }

    // =========================================================================
    // TRANSACTION STRUCT — type 10
    // =========================================================================

    /// @notice RECEIPT — proof of commercial, medical, financial, government,
    ///         event, or service transactions. Active at launch.
    ///         receiptType: PURCHASE | MEDICAL | FINANCIAL | GOVERNMENT | EVENT | SERVICE
    ///         amount: string e.g. "1299.99" — preserves precision without float risk.
    ///         currency: ISO 4217 code e.g. USD, CAD, EUR.
    struct ReceiptAnchor {
        AnchorBase base;
        string receiptType;  // PURCHASE | MEDICAL | FINANCIAL | GOVERNMENT | EVENT | SERVICE
        string merchant;     // merchant name or identifier
        string amount;       // transaction amount as string e.g. "1299.99"
        string currency;     // ISO 4217 currency code
        string orderId;      // merchant order ID or transaction reference
        string platform;     // shopify | stripe | square | etc.
        string url;          // receipt URL or IPFS hash
    }

    // =========================================================================
    // GATED STRUCTS — types 11-13 (suppressed at launch)
    // =========================================================================

    /// @notice LEGAL — contracts, patents, filings, disclosures.
    ///         Opens in V2-V3 with onlyLegalOperator gate.
    ///         docType: PATENT_APPLICATION | CONTRACT | COURT_FILING | DISCLOSURE | NDA | OTHER
    ///         jurisdiction: legal jurisdiction e.g. Delaware, UK, Canada.
    ///         parties: comma-separated parties to the document.
    ///         effectiveDate: ISO 8601 effective date e.g. 2026-03-16.
    ///         url: document URL or IPFS hash.
    struct LegalAnchor {
        AnchorBase base;
        string docType;        // document type
        string jurisdiction;   // legal jurisdiction
        string parties;        // comma-separated parties
        string effectiveDate;  // ISO 8601 date
        string url;            // document URL
    }

    /// @notice ENTITY — persons, companies, institutions, governments, AI systems.
    ///         Opens in V2 with onlyEntityOperator gate.
    struct EntityAnchor {
        AnchorBase base;
        string entityType;          // PERSON | COMPANY | INSTITUTION | GOVERNMENT | AI_SYSTEM | OTHER
        string entityDomain;        // canonical domain e.g. icmoore.com
        string verificationMethod;  // DNS_TXT | GITHUB | ORCID | EMAIL
        string verificationProof;   // the specific proof string used
        string canonicalUrl;        // anchorregistry.ai/canonical/[entity-id]
        string documentHash;        // SHA256 of canonical document
    }

    /// @notice PROOF — ZK proofs, cryptographic proofs, formal verifications, security audits.
    ///         Opens in V4 with onlyProofOperator gate.
    ///         proofType: ZK_PROOF | FORMAL_VERIFICATION | SECURITY_AUDIT | MATHEMATICAL | OTHER
    ///         proofSystem: Groth16 | PLONK | STARKs | Halo2 | Coq | Lean4 | Isabelle | snarkjs | etc.
    ///         circuitId: ZK circuit identifier.
    ///         vkeyHash: verification key hash (ZK proofs).
    ///         auditFirm: audit firm name (security audits).
    ///         auditScope: scope of the audit.
    ///         verifierUrl: on-chain verifier contract or URL.
    ///         reportUrl: audit report or paper URL.
    ///         proofHash: hash of the proof artifact itself.
    struct ProofAnchor {
        AnchorBase base;
        string proofType;    // ZK_PROOF | FORMAL_VERIFICATION | SECURITY_AUDIT | MATHEMATICAL | OTHER
        string proofSystem;  // Groth16, PLONK, STARKs, Coq, Lean4, etc.
        string circuitId;    // ZK circuit ID
        string vkeyHash;     // verification key hash
        string auditFirm;    // audit firm (security audits)
        string auditScope;   // scope of audit
        string verifierUrl;  // verifier contract or URL
        string reportUrl;    // report or paper URL
        string proofHash;    // hash of the proof itself
    }

    // =========================================================================
    // SELF-SERVICE STRUCT — type 14
    // =========================================================================

    struct RetractionAnchor {
        AnchorBase base;
        string targetArId;  // the anchor being retracted
        string reason;      // optional, owner-provided free text
        string replacedBy;  // optional AR-ID of replacement anchor
    }

    // =========================================================================
    // REVIEW STRUCTS — types 15-17
    // =========================================================================

    struct ReviewAnchor {
        AnchorBase base;
        string targetArId;  // the AR-ID of the anchor being reviewed
        string reviewType;  // MALICIOUS_TREE | IMPERSONATION | FALSE_AUTHORSHIP | DEFAMATORY | OTHER
        string evidenceUrl; // anchorregistry.com/reviews/[review-ar-id]
    }

    struct VoidAnchor {
        AnchorBase base;
        string targetArId;  // the parent AR-ID being condemned
        string reviewArId;  // the REVIEW anchor that preceded this finding
        string findingUrl;  // anchorregistry.com/reviews/[void-ar-id]
        string evidence;    // brief on-chain evidence summary
    }

    struct AffirmedAnchor {
        AnchorBase base;
        string targetArId;  // the REVIEW or VOID AR-ID being affirmed
        string affirmedBy;  // INVESTIGATION | APPEAL
        string findingUrl;  // anchorregistry.com/reviews/[affirmed-ar-id]
    }

    // =========================================================================
    // CATCH-ALL STRUCT — type 18
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

    mapping(string => CodeAnchor)       public codeAnchors;
    mapping(string => ResearchAnchor)   public researchAnchors;
    mapping(string => DataAnchor)       public dataAnchors;
    mapping(string => ModelAnchor)      public modelAnchors;
    mapping(string => AgentAnchor)      public agentAnchors;
    mapping(string => MediaAnchor)      public mediaAnchors;
    mapping(string => TextAnchor)       public textAnchors;
    mapping(string => PostAnchor)       public postAnchors;
    mapping(string => OnChainAnchor)    public onChainAnchors;
    mapping(string => EventAnchor)      public eventAnchors;
    mapping(string => ReceiptAnchor)    public receiptAnchors;
    mapping(string => LegalAnchor)      public legalAnchors;
    mapping(string => EntityAnchor)     public entityAnchors;
    mapping(string => ProofAnchor)      public proofAnchors;
    mapping(string => RetractionAnchor) public retractionAnchors;
    mapping(string => ReviewAnchor)     public reviewAnchors;
    mapping(string => VoidAnchor)       public voidAnchors;
    mapping(string => AffirmedAnchor)   public affirmedAnchors;
    mapping(string => OtherAnchor)      public otherAnchors;

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

    event Retracted(string indexed arId, string indexed targetArId, string replacedBy);
    event Reviewed(string indexed arId, string indexed targetArId, string reviewType, string evidenceUrl);
    event Voided(string indexed arId, string indexed targetArId, string indexed reviewArId, string evidence);
    event Affirmed(string indexed arId, string indexed targetArId, string affirmedBy);

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
        string calldata language,
        string calldata version,
        string calldata url
    ) external onlyOperator {
        _validateBase(arId, base);
        codeAnchors[arId] = CodeAnchor(base, gitHash, license, language, version, url);
        _register(arId, base);
    }

    function registerResearch(
        string calldata arId,
        AnchorBase calldata base,
        string calldata doi,
        string calldata institution,
        string calldata coAuthors,
        string calldata url
    ) external onlyOperator {
        _validateBase(arId, base);
        researchAnchors[arId] = ResearchAnchor(base, doi, institution, coAuthors, url);
        _register(arId, base);
    }

    function registerData(
        string calldata arId,
        AnchorBase calldata base,
        string calldata dataVersion,
        string calldata format,
        string calldata rowCount,
        string calldata schemaUrl,
        string calldata url
    ) external onlyOperator {
        _validateBase(arId, base);
        dataAnchors[arId] = DataAnchor(base, dataVersion, format, rowCount, schemaUrl, url);
        _register(arId, base);
    }

    function registerModel(
        string calldata arId,
        AnchorBase calldata base,
        string calldata modelVersion,
        string calldata architecture,
        string calldata parameters,
        string calldata trainingDataset,
        string calldata url
    ) external onlyOperator {
        _validateBase(arId, base);
        modelAnchors[arId] = ModelAnchor(base, modelVersion, architecture, parameters, trainingDataset, url);
        _register(arId, base);
    }

    function registerAgent(
        string calldata arId,
        AnchorBase calldata base,
        string calldata agentVersion,
        string calldata runtime,
        string calldata capabilities,
        string calldata url
    ) external onlyOperator {
        _validateBase(arId, base);
        agentAnchors[arId] = AgentAnchor(base, agentVersion, runtime, capabilities, url);
        _register(arId, base);
    }

    function registerMedia(
        string calldata arId,
        AnchorBase calldata base,
        string calldata mediaType,
        string calldata format,
        string calldata duration,
        string calldata isrc,
        string calldata url
    ) external onlyOperator {
        _validateBase(arId, base);
        mediaAnchors[arId] = MediaAnchor(base, mediaType, format, duration, isrc, url);
        _register(arId, base);
    }

    function registerText(
        string calldata arId,
        AnchorBase calldata base,
        string calldata isbn,
        string calldata publisher,
        string calldata language,
        string calldata url
    ) external onlyOperator {
        _validateBase(arId, base);
        textAnchors[arId] = TextAnchor(base, isbn, publisher, language, url);
        _register(arId, base);
    }

    function registerPost(
        string calldata arId,
        AnchorBase calldata base,
        string calldata platform,
        string calldata postId,
        string calldata postDate,
        string calldata url
    ) external onlyOperator {
        _validateBase(arId, base);
        postAnchors[arId] = PostAnchor(base, platform, postId, postDate, url);
        _register(arId, base);
    }

    /// @notice Register an ONCHAIN anchor. Supports both contract address
    ///         and transaction hash — provide one or both, same as Etherscan lookup.
    function registerOnChain(
        string calldata arId,
        AnchorBase calldata base,
        string calldata chainId,
        string calldata assetType,
        string calldata contractAddress,
        string calldata txHash,
        string calldata tokenId,
        string calldata blockNumber,
        string calldata url
    ) external onlyOperator {
        _validateBase(arId, base);
        onChainAnchors[arId] = OnChainAnchor(
            base, chainId, assetType, contractAddress, txHash, tokenId, blockNumber, url
        );
        _register(arId, base);
    }

    // =========================================================================
    // REGISTER FUNCTIONS — LIFECYCLE (type 9)
    // =========================================================================

    function registerEvent(
        string calldata arId,
        AnchorBase calldata base,
        string calldata eventType,
        string calldata eventDate,
        string calldata location,
        string calldata organizer,
        string calldata url
    ) external onlyOperator {
        _validateBase(arId, base);
        eventAnchors[arId] = EventAnchor(base, eventType, eventDate, location, organizer, url);
        _register(arId, base);
    }

    // =========================================================================
    // REGISTER FUNCTIONS — TRANSACTION (type 10)
    // =========================================================================

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
    // REGISTER FUNCTIONS — GATED (types 11-13, suppressed at launch)
    // =========================================================================

    function registerLegal(
        string calldata arId,
        AnchorBase calldata base,
        string calldata docType,
        string calldata jurisdiction,
        string calldata parties,
        string calldata effectiveDate,
        string calldata url
    ) external onlyLegalOperator {
        _validateBase(arId, base);
        legalAnchors[arId] = LegalAnchor(base, docType, jurisdiction, parties, effectiveDate, url);
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
        string calldata circuitId,
        string calldata vkeyHash,
        string calldata auditFirm,
        string calldata auditScope,
        string calldata verifierUrl,
        string calldata reportUrl,
        string calldata proofHash
    ) external onlyProofOperator {
        _validateBase(arId, base);
        proofAnchors[arId] = ProofAnchor(
            base, proofType, proofSystem, circuitId, vkeyHash,
            auditFirm, auditScope, verifierUrl, reportUrl, proofHash
        );
        _register(arId, base);
    }

    // =========================================================================
    // REGISTER FUNCTIONS — SELF-SERVICE (type 14)
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
    // REGISTER FUNCTIONS — REVIEW SYSTEM (types 15-17)
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
    // REGISTER FUNCTIONS — CATCH-ALL (type 18)
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
