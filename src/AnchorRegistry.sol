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
///         All artifact metadata is passed as calldata and emitted in the
///         Anchored event. Only the AR-ID registration flag is stored on-chain.
///         Off-chain indexers (Supabase) read events for full artifact data.
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
    // REGISTRY STORAGE
    // =========================================================================

    mapping(string => bool) public registered;

    // =========================================================================
    // EVENTS
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

    /// @notice Emitted on every successful registration.
    ///         artifactType: uint8 mapping to ArtifactType enum (0-17)
    ///         manifestHash: SHA256 of full manifest
    ///         parentHash: AR-ID of parent anchor, empty if root
    ///         descriptor: human-readable label
    event Anchored(
        string  indexed arId,
        address indexed registrant,
        uint8           artifactType,
        string          descriptor,
        string          manifestHash,
        string          parentHash
    );

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
    error AlreadyRegistered(string arId);
    error EmptyManifestHash();
    error EmptyArId();
    error InvalidParent(string parentHash);

    // =========================================================================
    // MODIFIERS
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
    // GOVERNANCE
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
    // RECOVERY
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
    // INTERNAL
    // =========================================================================

    function _register(
        string calldata arId,
        string calldata manifestHash,
        string calldata parentHash,
        string calldata descriptor,
        uint8           artifactType
    ) internal {
        if (bytes(arId).length == 0)          revert EmptyArId();
        if (bytes(manifestHash).length == 0)  revert EmptyManifestHash();
        if (registered[arId])                 revert AlreadyRegistered(arId);
        if (bytes(parentHash).length > 0 && !registered[parentHash])
                                              revert InvalidParent(parentHash);
        registered[arId] = true;
        emit Anchored(arId, msg.sender, artifactType, descriptor, manifestHash, parentHash);
    }

    // =========================================================================
    // REGISTER — CONTENT (types 0-8) + TRANSACTION (9) + OTHER (17)
    // =========================================================================

    /// @notice Register any operator-gated artifact type (0-9, 13-17).
    ///         artifactType must be 0-9 or 13-17.
    ///         All metadata is in calldata — emitted in Anchored event only.
    function register(
        string calldata arId,
        string calldata manifestHash,
        string calldata parentHash,
        string calldata descriptor,
        uint8           artifactType
    ) external onlyOperator {
        require(artifactType <= 9 || (artifactType >= 13 && artifactType <= 17), "invalid type");
        _register(arId, manifestHash, parentHash, descriptor, artifactType);
    }

    // =========================================================================
    // REGISTER — GATED (types 10-12)
    // =========================================================================

    function registerLegal(
        string calldata arId,
        string calldata manifestHash,
        string calldata parentHash,
        string calldata descriptor
    ) external onlyLegalOperator {
        _register(arId, manifestHash, parentHash, descriptor, 10);
    }

    function registerEntity(
        string calldata arId,
        string calldata manifestHash,
        string calldata parentHash,
        string calldata descriptor
    ) external onlyEntityOperator {
        _register(arId, manifestHash, parentHash, descriptor, 11);
    }

    function registerProof(
        string calldata arId,
        string calldata manifestHash,
        string calldata parentHash,
        string calldata descriptor
    ) external onlyProofOperator {
        _register(arId, manifestHash, parentHash, descriptor, 12);
    }
}
