// SPDX-License-Identifier: BUSL-1.1
// Change Date:    March 12, 2028
// Change License: Apache-2.0
// Licensor:       Ian Moore (icmoore) @ anchorregistry.com

pragma solidity ^0.8.24;

import "./AnchorTypes.sol";

/// @title  AnchorRegistry
/// @notice On-chain registry of artifact provenance anchors.
///         Immutable record of what existed, when, and who registered it.
/// @dev    Deployed once on Base (Ethereum L2). Cannot be modified post-deployment.
///
///         Twenty-four artifact types in eight logical groups:
///
///         CONTENT (0-11):      CODE, RESEARCH, DATA, MODEL, AGENT, MEDIA, TEXT, POST, ONCHAIN, REPORT, NOTE, WEBSITE
///         LIFECYCLE (12):      EVENT
///         TRANSACTION (13):    RECEIPT
///         GATED (14-16):       LEGAL, ENTITY, PROOF
///         SELF-SERVICE (17-18): SEAL, RETRACTION
///         REVIEW (19-21):      REVIEW, VOID, AFFIRMED
///         BILLING (22):        ACCOUNT
///         CATCH-ALL (23):      OTHER
///
///         Four register entry points:
///         registerContent(arId, base, extra)   — types 0-13, 22, 23 (onlyOperator)
///         registerGated(arId, base, extra)     — types 14-16 (onlyLegal/Entity/ProofOperator)
///         registerTargeted(arId, base, targetArId, extra) — types 18-21 (onlyOperator)
///         registerSeal(arId, newTreeRoot, reason, tokenCommitment) — type 17 (onlyOperator, client authority)

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

    string public constant AR_TREE_ID = "ar-operator-v1";

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
    // ANCHOR EVENTS
    // =========================================================================

    event Anchored(
        string  indexed arId,
        address indexed registrant,
        ArtifactType    artifactType,
        string          arIdPlain,
        string          descriptor,
        string          title,
        string          author,
        string          manifestHash,
        string          parentArId,
        string  indexed treeId,
        string          treeIdPlain,
        bytes32         tokenCommitment
    );

    event Sealed(
        string indexed arId,
        string  newTreeRoot,
        string  reason,
        uint256 sealedAtBlock,
        bytes32 tokenCommitment
    );

    event Retracted(string indexed arId, string indexed targetArId, string replacedBy);
    event Reviewed(string indexed arId, string indexed targetArId, string reviewType, string evidenceUrl);
    event Voided(string indexed arId, string indexed targetArId, string indexed reviewArId, string evidence);
    event Affirmed(string indexed arId, string indexed targetArId, string affirmedBy);

    // =========================================================================
    // ERRORS
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
    error InsufficientCapacity();
    error AlreadyRegistered(string arId);
    error EmptyManifestHash();
    error EmptyArId();
    error InvalidParent(string parentArId);
    error EmptyTargetArId();
    error InvalidTarget(string targetArId);
    error InvalidArtifactType();
    error MissingTokenCommitment();
    error TreeSealed();
    error AlreadySealed();
    error AnchorVoided();
    error AnchorUnderReview();
    error NotTreeRoot();

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

    modifier notSealed(string calldata parentArId) {
        if (bytes(parentArId).length > 0) {
            if (isSealed[treeRoot[parentArId]]) revert TreeSealed();
        }
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
    // STORAGE
    // =========================================================================

    mapping(string => bytes)        private _anchorData;
    mapping(string => ArtifactType) public  anchorTypes;
    mapping(string => bool)         public  registered;
    mapping(string => bytes32)      public  tokenCommitments;  // arId → SHA256(ownershipToken + childArId)
    mapping(string => bool)         public  isSealed;            // arId → true if tree root is sealed
    mapping(string => string)       public  sealContinuation;  // arId → newTreeRoot (optional continuation pointer)
    mapping(string => string)       public  treeRoot;          // arId → root arId of its tree
    mapping(string => bool)         public  voided;            // arId → true if anchor has been VOIDed
    mapping(string => bool)         public  reviewed;          // arId → true if anchor is under REVIEW

    // =========================================================================
    // GETTER
    // =========================================================================

    function getAnchorData(string calldata arId) external view returns (bytes memory) {
        return _anchorData[arId];
    }

    // =========================================================================
    // INTERNAL
    // =========================================================================

    function _validateBase(string calldata arId, AnchorBase calldata base) internal view {
        if (bytes(arId).length == 0)              revert EmptyArId();
        if (bytes(base.manifestHash).length == 0) revert EmptyManifestHash();
        if (registered[arId])                     revert AlreadyRegistered(arId);
        if (bytes(base.parentArId).length > 0 && !registered[base.parentArId])
                                                  revert InvalidParent(base.parentArId);
    }

    function _register(string calldata arId, AnchorBase calldata base, bytes32 tokenCommitment) internal {
        registered[arId] = true;
        anchorTypes[arId] = base.artifactType;
        tokenCommitments[arId] = tokenCommitment;
        if (bytes(base.parentArId).length == 0) {
            treeRoot[arId] = arId;
        } else {
            treeRoot[arId] = treeRoot[base.parentArId];
        }
        emit Anchored(arId, msg.sender, base.artifactType, arId, base.descriptor, base.title, base.author, base.manifestHash, base.parentArId, base.treeId, base.treeId, tokenCommitment);
    }

    function _validateTarget(string calldata targetArId) internal view {
        if (bytes(targetArId).length == 0) revert EmptyTargetArId();
        if (!registered[targetArId])        revert InvalidTarget(targetArId);
    }

    function _validateTargetMem(string memory targetArId) internal view {
        if (bytes(targetArId).length == 0) revert EmptyTargetArId();
        if (!registered[targetArId])        revert InvalidTarget(targetArId);
    }

    // =========================================================================
    // REGISTER — CONTENT (types 0-13, 22, 23)
    // =========================================================================

    /// @notice Register any content, lifecycle, transaction, billing, or catch-all anchor.
    /// @param arId   Unique AR-ID for this anchor.
    /// @param base   AnchorBase with artifactType, manifestHash, parentArId, etc.
    /// @param extra  ABI-encoded type-specific fields (e.g. abi.encode(gitHash, license, language, version, url) for CODE).
    function registerContent(
        string calldata arId,
        AnchorBase calldata base,
        bytes calldata extra,
        bytes32 tokenCommitment
    ) external onlyOperator notSealed(base.parentArId) {
        if (tokenCommitment == bytes32(0)) revert MissingTokenCommitment();
        ArtifactType t = base.artifactType;
        if (t > ArtifactType.RECEIPT && t != ArtifactType.ACCOUNT && t != ArtifactType.OTHER)
            revert InvalidArtifactType();

        if (t == ArtifactType.ACCOUNT) {
            uint256 capacity = abi.decode(extra, (uint256));
            if (capacity < 10) revert InsufficientCapacity();
        }

        _validateBase(arId, base);
        _anchorData[arId] = extra;
        _register(arId, base, tokenCommitment);
    }

    // =========================================================================
    // REGISTER — GATED (types 14-16)
    // =========================================================================

    /// @notice Register a gated anchor (LEGAL, ENTITY, or PROOF).
    /// @param arId   Unique AR-ID for this anchor.
    /// @param base   AnchorBase with artifactType set to LEGAL, ENTITY, or PROOF.
    /// @param extra  ABI-encoded type-specific fields.
    function registerGated(
        string calldata arId,
        AnchorBase calldata base,
        bytes calldata extra,
        bytes32 tokenCommitment
    ) external notSealed(base.parentArId) {
        if (tokenCommitment == bytes32(0)) revert MissingTokenCommitment();
        ArtifactType t = base.artifactType;
        if (t == ArtifactType.LEGAL) {
            if (!legalOperators[msg.sender]) revert NotLegalOperator();
        } else if (t == ArtifactType.ENTITY) {
            if (!entityOperators[msg.sender]) revert NotEntityOperator();
        } else if (t == ArtifactType.PROOF) {
            if (!proofOperators[msg.sender]) revert NotProofOperator();
        } else {
            revert InvalidArtifactType();
        }

        _validateBase(arId, base);
        _anchorData[arId] = extra;
        _register(arId, base, tokenCommitment);
    }

    // =========================================================================
    // REGISTER — TARGETED (types 18-21)
    // =========================================================================

    /// @notice Register a targeted anchor (RETRACTION, REVIEW, VOID, or AFFIRMED).
    /// @param arId            Unique AR-ID for this anchor.
    /// @param base            AnchorBase with artifactType set to RETRACTION, REVIEW, VOID, or AFFIRMED.
    /// @param targetArId      The AR-ID being targeted (must exist).
    /// @param extra           ABI-encoded type-specific fields.
    /// @param tokenCommitment SHA256(ownershipToken + arId) for RETRACTION (user-initiated).
    ///                        Must be bytes32(0) for REVIEW, VOID, AFFIRMED (AR governance).
    function registerTargeted(
        string calldata arId,
        AnchorBase calldata base,
        string calldata targetArId,
        bytes calldata extra,
        bytes32 tokenCommitment
    ) external onlyOperator {
        ArtifactType t = base.artifactType;
        if (t < ArtifactType.RETRACTION || t > ArtifactType.AFFIRMED)
            revert InvalidArtifactType();

        _validateBase(arId, base);
        _validateTarget(targetArId);

        if (t == ArtifactType.RETRACTION) {
            // SEAL blocks new retractions — client cannot retract within a sealed tree
            if (bytes(base.parentArId).length > 0 && isSealed[treeRoot[base.parentArId]]) revert TreeSealed();
            if (tokenCommitment == bytes32(0)) revert MissingTokenCommitment();
            (string memory reason, string memory replacedBy) = abi.decode(extra, (string, string));
            _anchorData[arId] = extra;
            _register(arId, base, tokenCommitment);
            emit Retracted(arId, targetArId, replacedBy);
            // silence unused variable warning
            bytes(reason).length;
        } else if (t == ArtifactType.REVIEW) {
            (string memory reviewType, string memory evidenceUrl) = abi.decode(extra, (string, string));
            _anchorData[arId] = extra;
            _register(arId, base, bytes32(0));
            reviewed[targetArId] = true;
            emit Reviewed(arId, targetArId, reviewType, evidenceUrl);
        } else if (t == ArtifactType.VOID) {
            (string memory reviewArId, string memory findingUrl, string memory evidence) = abi.decode(extra, (string, string, string));
            _validateTargetMem(reviewArId);
            _anchorData[arId] = extra;
            _register(arId, base, bytes32(0));
            voided[targetArId] = true;
            emit Voided(arId, targetArId, reviewArId, evidence);
            // silence unused variable warning
            bytes(findingUrl).length;
        } else {
            // AFFIRMED
            (string memory affirmedBy, string memory findingUrl) = abi.decode(extra, (string, string));
            _anchorData[arId] = extra;
            _register(arId, base, bytes32(0));
            emit Affirmed(arId, targetArId, affirmedBy);
            // silence unused variable warning
            bytes(findingUrl).length;
        }
    }

    // =========================================================================
    // SEAL (type 17) — client authority only
    // =========================================================================

    /// @notice Seal a provenance tree — authentic and complete.
    ///         No new anchors may be appended after sealing.
    ///         AR governance (VOID, REVIEW, AFFIRMED) can still target anchors within sealed trees.
    ///         SEAL is permanent and cannot be reversed by anyone including AnchorRegistry.
    /// @param arId             The root AR-ID of the tree to seal (must be a tree root).
    /// @param newTreeRoot      Optional continuation pointer to a new tree root.
    /// @param reason           Human-readable reason for sealing.
    /// @param tokenCommitment  H(K ∥ C_seal) — must be non-zero (client-initiated action).
    function registerSeal(
        string calldata arId,
        string calldata newTreeRoot,
        string calldata reason,
        bytes32 tokenCommitment
    ) external onlyOperator {
        if (!registered[arId])                                          revert InvalidTarget(arId);
        if (isSealed[arId])                                               revert AlreadySealed();
        if (voided[arId])                                               revert AnchorVoided();
        if (reviewed[arId])                                             revert AnchorUnderReview();
        if (tokenCommitment == bytes32(0))                              revert MissingTokenCommitment();
        if (keccak256(bytes(treeRoot[arId])) != keccak256(bytes(arId))) revert NotTreeRoot();

        isSealed[arId] = true;
        sealContinuation[arId] = newTreeRoot;

        emit Sealed(arId, newTreeRoot, reason, block.number, tokenCommitment);
    }
}
