// SPDX-License-Identifier: BUSL-1.1
// Change Date: March 12, 2028
// Change License: Apache-2.0
// Licensor: Ian Moore (icmoore)

pragma solidity ^0.8.24;

/// @title AnchorRegistry
/// @notice On-chain registry of artifact provenance anchors
/// @dev Immutable record of what existed, when, and who registered it

contract AnchorRegistry {

    // -------------------------------------------------------------------------
    // Access Control Storage
    // -------------------------------------------------------------------------

    address public owner;
    address public recoveryAddress;
    mapping(address => bool) public operators;

    uint256 public constant RECOVERY_DELAY   = 7 days;
    uint256 public constant RECOVERY_LOCKOUT = 7 days;
    uint256 public recoveryInitiatedAt;
    uint256 public recoveryLockoutUntil;
    address public pendingOwner;

    // -------------------------------------------------------------------------
    // Access Control Events
    // -------------------------------------------------------------------------

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OperatorAdded(address indexed operator);
    event OperatorRemoved(address indexed operator);
    event RecoveryInitiated(address indexed recoveryAddress, address indexed pendingOwner);
    event RecoveryExecuted(address indexed newOwner);
    event RecoveryCancelled();
    event RecoveryAddressUpdated(address indexed newRecoveryAddress);

    // -------------------------------------------------------------------------
    // Access Control Errors
    // -------------------------------------------------------------------------

    error NotOwner();
    error NotOperator();
    error NotRecoveryAddress();
    error RecoveryNotInitiated();
    error RecoveryDelayNotMet();
    error RecoveryLockedOut();
    error ZeroAddress();

    // -------------------------------------------------------------------------
    // Access Control Modifiers
    // -------------------------------------------------------------------------

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperator() {
        if (!operators[msg.sender]) revert NotOperator();
        _;
    }

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    constructor(address _recoveryAddress) {
        if (_recoveryAddress == address(0)) revert ZeroAddress();
        owner           = msg.sender;
        recoveryAddress = _recoveryAddress;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    // -------------------------------------------------------------------------
    // Governance Functions
    // -------------------------------------------------------------------------

    function addOperator(address op) external onlyOwner {
        if (op == address(0)) revert ZeroAddress();
        operators[op] = true;
        emit OperatorAdded(op);
    }

    function removeOperator(address op) external onlyOwner {
        operators[op] = false;
        emit OperatorRemoved(op);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // -------------------------------------------------------------------------
    // Recovery Functions
    // -------------------------------------------------------------------------

    function initiateRecovery(address _pendingOwner) external {
        if (msg.sender != recoveryAddress)          revert NotRecoveryAddress();
        if (_pendingOwner == address(0))            revert ZeroAddress();
        if (block.timestamp < recoveryLockoutUntil) revert RecoveryLockedOut();
        pendingOwner        = _pendingOwner;
        recoveryInitiatedAt = block.timestamp;
        emit RecoveryInitiated(recoveryAddress, _pendingOwner);
    }

    function executeRecovery() external {
        if (msg.sender != recoveryAddress)                          revert NotRecoveryAddress();
        if (recoveryInitiatedAt == 0)                               revert RecoveryNotInitiated();
        if (block.timestamp < recoveryInitiatedAt + RECOVERY_DELAY) revert RecoveryDelayNotMet();
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

    // -------------------------------------------------------------------------
    // Artifact Types
    // -------------------------------------------------------------------------

    enum ArtifactType {
        CODE,       // repos, packages, commits, scripts
        RESEARCH,   // papers, whitepapers, preprints, theses
        DATA,       // training data, benchmarks, databases
        MODEL,      // AI models, weights, checkpoints
        AGENT,      // AI agents, bots, assistants
        MEDIA,      // video, audio, images, photography
        TEXT,       // blogs, articles, books, essays
        POST,       // tweets, reddit, social
        LEGAL,      // contracts, filings, disclosures, patents
        PROOF,      // ZK proofs, cryptographic proofs
        OTHER       // catch all
    }

    // -------------------------------------------------------------------------
    // Base Struct
    // -------------------------------------------------------------------------

    struct AnchorBase {
        ArtifactType artifactType;
        string manifestHash;    // SHA256 of SPDX or DAPX manifest
        string parentHash;      // AR-ID of parent anchor, empty if root
        string descriptor;      // human readable e.g. ICMOORE-2026-UNISWAPPY
    }

    // -------------------------------------------------------------------------
    // Child Structs
    // -------------------------------------------------------------------------

    struct CodeAnchor     { AnchorBase base; string gitHash;      string license; string url; }
    struct ResearchAnchor { AnchorBase base; string doi;          string url; }
    struct DataAnchor     { AnchorBase base; string dataVersion; string url; }
    struct ModelAnchor    { AnchorBase base; string modelVersion; string url; }
    struct AgentAnchor    { AnchorBase base; string agentVersion;  string url; }
    struct MediaAnchor    { AnchorBase base; string mediaType;    string url; }
    struct TextAnchor     { AnchorBase base; string url; }
    struct PostAnchor     { AnchorBase base; string platform;     string url; }
    struct LegalAnchor    { AnchorBase base; string docType;       string url; }
    struct ProofAnchor    { AnchorBase base; string proofType; }
    struct OtherAnchor    { AnchorBase base; string kind; string platform; string url; string value; }

    // -------------------------------------------------------------------------
    // Storage
    // -------------------------------------------------------------------------

    mapping(string => CodeAnchor)     public codeAnchors;
    mapping(string => ResearchAnchor) public researchAnchors;
    mapping(string => DataAnchor)     public dataAnchors;
    mapping(string => ModelAnchor)    public modelAnchors;
    mapping(string => AgentAnchor)    public agentAnchors;
    mapping(string => MediaAnchor)    public mediaAnchors;
    mapping(string => TextAnchor)     public textAnchors;
    mapping(string => PostAnchor)     public postAnchors;
    mapping(string => LegalAnchor)    public legalAnchors;
    mapping(string => ProofAnchor)    public proofAnchors;
    mapping(string => OtherAnchor)    public otherAnchors;

    // track registered AR-IDs to prevent collisions
    mapping(string => bool) public registered;

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    event Anchored(
        string  indexed arId,
        address indexed registrant,
        ArtifactType    artifactType,
        string          descriptor,
        string          manifestHash,
        string          parentHash
    );

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error AlreadyRegistered(string arId);
    error EmptyManifestHash();
    error EmptyArId();
    error InvalidParent(string parentHash);

    // -------------------------------------------------------------------------
    // Internal
    // -------------------------------------------------------------------------

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

    // -------------------------------------------------------------------------
    // Register Functions
    // -------------------------------------------------------------------------

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

    function registerLegal(
        string calldata arId,
        AnchorBase calldata base,
        string calldata docType,
        string calldata url
    ) external onlyOperator {
        _validateBase(arId, base);
        legalAnchors[arId] = LegalAnchor(base, docType, url);
        _register(arId, base);
    }

    function registerProof(
        string calldata arId,
        AnchorBase calldata base,
        string calldata proofType
    ) external onlyOperator {
        _validateBase(arId, base);
        proofAnchors[arId] = ProofAnchor(base, proofType);
        _register(arId, base);
    }

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
