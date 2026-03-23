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
///         Twenty-two artifact types in eight logical groups:
///
///         CONTENT (0-10):    CODE, RESEARCH, DATA, MODEL, AGENT, MEDIA, TEXT, POST, ONCHAIN, REPORT, NOTE
///         LIFECYCLE (11):    EVENT
///         TRANSACTION (12):  RECEIPT
///         GATED (13-15):     LEGAL, ENTITY, PROOF  
///         SELF-SERVICE (16): RETRACTION
///         REVIEW (17-19):    REVIEW, VOID, AFFIRMED
///         BILLING (20):      ACCOUNT
///         CATCH-ALL (21):    OTHER
///
///         Three register entry points:
///         registerContent(arId, base, extra)   — types 0-12, 20, 21 (onlyOperator)
///         registerGated(arId, base, extra)     — types 13-15 (onlyLegal/Entity/ProofOperator)
///         registerTargeted(arId, base, targetArId, extra) — types 16-19 (onlyOperator)

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
        string          descriptor,
        string          title,
        string          author,
        string          manifestHash,
        string          parentHash,
        string          treeId
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
    error InvalidParent(string parentHash);
    error EmptyTargetArId();
    error InvalidTarget(string targetArId);
    error InvalidArtifactType();

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
        if (bytes(base.parentHash).length > 0 && !registered[base.parentHash])
                                                  revert InvalidParent(base.parentHash);
    }

    function _register(string calldata arId, AnchorBase calldata base) internal {
        registered[arId] = true;
        anchorTypes[arId] = base.artifactType;
        emit Anchored(arId, msg.sender, base.artifactType, base.descriptor, base.title, base.author, base.manifestHash, base.parentHash, base.treeId);
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
    // REGISTER — CONTENT (types 0-12, 20, 21)
    // =========================================================================

    /// @notice Register any content, lifecycle, transaction, billing, or catch-all anchor.
    /// @param arId   Unique AR-ID for this anchor.
    /// @param base   AnchorBase with artifactType, manifestHash, parentHash, etc.
    /// @param extra  ABI-encoded type-specific fields (e.g. abi.encode(gitHash, license, language, version, url) for CODE).
    function registerContent(
        string calldata arId,
        AnchorBase calldata base,
        bytes calldata extra
    ) external onlyOperator {
        ArtifactType t = base.artifactType;
        if (t > ArtifactType.RECEIPT && t != ArtifactType.ACCOUNT && t != ArtifactType.OTHER)
            revert InvalidArtifactType();

        if (t == ArtifactType.ACCOUNT) {
            uint256 capacity = abi.decode(extra, (uint256));
            if (capacity < 10) revert InsufficientCapacity();
        }

        _validateBase(arId, base);
        _anchorData[arId] = extra;
        _register(arId, base);
    }

    // =========================================================================
    // REGISTER — GATED (types 13-15)
    // =========================================================================

    /// @notice Register a gated anchor (LEGAL, ENTITY, or PROOF).
    /// @param arId   Unique AR-ID for this anchor.
    /// @param base   AnchorBase with artifactType set to LEGAL, ENTITY, or PROOF.
    /// @param extra  ABI-encoded type-specific fields.
    function registerGated(
        string calldata arId,
        AnchorBase calldata base,
        bytes calldata extra
    ) external {
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
        _register(arId, base);
    }

    // =========================================================================
    // REGISTER — TARGETED (types 16-19)
    // =========================================================================

    /// @notice Register a targeted anchor (RETRACTION, REVIEW, VOID, or AFFIRMED).
    /// @param arId       Unique AR-ID for this anchor.
    /// @param base       AnchorBase with artifactType set to RETRACTION, REVIEW, VOID, or AFFIRMED.
    /// @param targetArId The AR-ID being targeted (must exist).
    /// @param extra      ABI-encoded type-specific fields.
    function registerTargeted(
        string calldata arId,
        AnchorBase calldata base,
        string calldata targetArId,
        bytes calldata extra
    ) external onlyOperator {
        ArtifactType t = base.artifactType;
        if (t < ArtifactType.RETRACTION || t > ArtifactType.AFFIRMED)
            revert InvalidArtifactType();

        _validateBase(arId, base);
        _validateTarget(targetArId);

        if (t == ArtifactType.RETRACTION) {
            (string memory reason, string memory replacedBy) = abi.decode(extra, (string, string));
            _anchorData[arId] = extra;
            _register(arId, base);
            emit Retracted(arId, targetArId, replacedBy);
            // silence unused variable warning
            bytes(reason).length;
        } else if (t == ArtifactType.REVIEW) {
            (string memory reviewType, string memory evidenceUrl) = abi.decode(extra, (string, string));
            _anchorData[arId] = extra;
            _register(arId, base);
            emit Reviewed(arId, targetArId, reviewType, evidenceUrl);
        } else if (t == ArtifactType.VOID) {
            (string memory reviewArId, string memory findingUrl, string memory evidence) = abi.decode(extra, (string, string, string));
            _validateTargetMem(reviewArId);
            _anchorData[arId] = extra;
            _register(arId, base);
            emit Voided(arId, targetArId, reviewArId, evidence);
            // silence unused variable warning
            bytes(findingUrl).length;
        } else {
            // AFFIRMED
            (string memory affirmedBy, string memory findingUrl) = abi.decode(extra, (string, string));
            _anchorData[arId] = extra;
            _register(arId, base);
            emit Affirmed(arId, targetArId, affirmedBy);
            // silence unused variable warning
            bytes(findingUrl).length;
        }
    }
}
