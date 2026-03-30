// SPDX-License-Identifier: BUSL-1.1
// Change Date:    March 12, 2028
// Change License: Apache-2.0
// Licensor:       Ian Moore (icmoore)

pragma solidity ^0.8.24;

/// @title  AnchorTypes
/// @notice Shared type definitions, structs, events, and errors for AnchorRegistry.
/// @dev    This file produces no bytecode — it is purely for imports and ABI reference.

// =========================================================================
// ARTIFACT TYPES
// =========================================================================

enum ArtifactType {
    // ── CONTENT (0-11) ────────────────────────────────────────────────
    CODE,        // 0
    RESEARCH,    // 1
    DATA,        // 2
    MODEL,       // 3
    AGENT,       // 4
    MEDIA,       // 5
    TEXT,        // 6
    POST,        // 7
    ONCHAIN,     // 8
    REPORT,      // 9
    NOTE,        // 10
    WEBSITE,     // 11

    // ── LIFECYCLE (12) ────────────────────────────────────────────────
    EVENT,       // 12

    // ── TRANSACTION (13) ──────────────────────────────────────────────
    RECEIPT,     // 13

    // ── GATED (14-16) ─────────────────────────────────────────────────
    LEGAL,       // 14
    ENTITY,      // 15
    PROOF,       // 16

    // ── SELF-SERVICE (17) ─────────────────────────────────────────────
    RETRACTION,  // 17

    // ── REVIEW (18-20) ────────────────────────────────────────────────
    REVIEW,      // 18
    VOID,        // 19
    AFFIRMED,    // 20

    // ── BILLING (21) ──────────────────────────────────────────────────
    ACCOUNT,     // 21

    // ── CATCH-ALL (22) ────────────────────────────────────────────────
    OTHER        // 22
}

// =========================================================================
// BASE STRUCT
// =========================================================================

struct AnchorBase {
    ArtifactType artifactType;
    string manifestHash;  // SHA256 of full manifest (all fields including off-chain)
    string parentArId;    // AR-ID of parent anchor, empty if root
    string descriptor;    // human-readable e.g. ICMOORE-2026-UNISWAPPY
    string title;         // artifact title e.g. "UniswapPy v1.0"
    string author;        // artifact author e.g. "Ian Moore" or "anonymous"
    string treeId;        // cryptographic tree identity: sha256(anchorKey + rootArId)
}

// =========================================================================
// CONTENT STRUCTS — types 0-11 (kept for ABI reference / off-chain decoding)
// =========================================================================

/// @notice CODE — repos, packages, commits, scripts.
struct CodeAnchor {
    AnchorBase base;
    string gitHash;
    string license;
    string language;
    string version;
    string url;
}

/// @notice RESEARCH — papers, whitepapers, preprints, theses.
struct ResearchAnchor {
    AnchorBase base;
    string doi;
    string institution;
    string coAuthors;
    string url;
}

/// @notice DATA — datasets, benchmarks, databases.
struct DataAnchor {
    AnchorBase base;
    string dataVersion;
    string format;
    string rowCount;
    string schemaUrl;
    string url;
}

/// @notice MODEL — AI models, weights, checkpoints.
struct ModelAnchor {
    AnchorBase base;
    string modelVersion;
    string architecture;
    string parameters;
    string trainingDataset;
    string url;
}

/// @notice AGENT — AI agents, bots, assistants.
struct AgentAnchor {
    AnchorBase base;
    string agentVersion;
    string runtime;
    string capabilities;
    string url;
}

/// @notice MEDIA — video, audio, images, photography.
struct MediaAnchor {
    AnchorBase base;
    string mediaType;
    string platform;   // e.g. "YouTube", "SoundCloud", "IPFS"
    string format;
    string duration;
    string isrc;
    string url;
}

/// @notice TEXT — blogs, articles, books, essays.
struct TextAnchor {
    AnchorBase base;
    string textType;   // e.g. "BLOG", "BOOK", "ESSAY", "ARTICLE", "WHITEPAPER"
    string isbn;
    string publisher;
    string language;
    string url;
}

/// @notice POST — tweets, reddit posts, social content.
struct PostAnchor {
    AnchorBase base;
    string platform;
    string postId;
    string postDate;
    string url;
}

/// @notice ONCHAIN — Ethereum addresses, transactions, contracts, NFTs, token IDs, DAOs, multisigs.
struct OnChainAnchor {
    AnchorBase base;
    string chainId;
    string assetType;
    string contractAddress;
    string txHash;
    string tokenId;
    string blockNumber;
    string url;
}

/// @notice REPORT — consulting, financial, compliance, ESG, technical, audit reports.
struct ReportAnchor {
    AnchorBase base;
    string reportType;
    string client;
    string engagement;
    string version;
    string authors;
    string institution;
    string url;
    string fileManifestHash; // SHA256 of the actual artifact file, empty if no file provided
}

/// @notice NOTE — memos, meeting notes, correspondence, observations, field notes.
struct NoteAnchor {
    AnchorBase base;
    string noteType;
    string date;
    string participants;
    string url;
    string fileManifestHash; // SHA256 of the actual artifact file, empty if no file provided
}

/// @notice WEBSITE — canonical domain presence for a project, creator, or entity.
///         url is the primary identity field. The file hash is a snapshot of the
///         site at registration time (e.g. SHA256 of rendered HTML or sitemap).
struct WebsiteAnchor {
    AnchorBase base;
    string url;          // canonical domain e.g. https://defipy.org
    string platform;     // e.g. "Next.js", "WordPress", "Vercel"
    string description;  // brief description of the site
}

// =========================================================================
// LIFECYCLE STRUCT — type 12
// =========================================================================

/// @notice EVENT — dual-use lifecycle anchor for human events and machine/agent processes.
struct EventAnchor {
    AnchorBase base;
    string executor;
    string eventType;
    string eventDate;
    string location;
    string orchestrator;
    string url;
}

// =========================================================================
// TRANSACTION STRUCT — type 13
// =========================================================================

/// @notice RECEIPT — proof of commercial, medical, financial, government, event, or service transactions.
struct ReceiptAnchor {
    AnchorBase base;
    string receiptType;
    string merchant;
    string amount;
    string currency;
    string orderId;
    string platform;
    string url;
    string fileManifestHash; // SHA256 of the actual artifact file, empty if no file provided
}

// =========================================================================
// GATED STRUCTS — types 14-16 (suppressed at launch)
// =========================================================================

/// @notice LEGAL — contracts, patents, filings, disclosures.
struct LegalAnchor {
    AnchorBase base;
    string docType;
    string jurisdiction;
    string parties;
    string effectiveDate;
    string url;
}

/// @notice ENTITY — persons, companies, institutions, governments, AI systems.
struct EntityAnchor {
    AnchorBase base;
    string entityType;
    string entityDomain;
    string verificationMethod;
    string verificationProof;
    string canonicalUrl;
    string documentHash;
}

/// @notice PROOF — ZK proofs, cryptographic proofs, formal verifications, security audits.
struct ProofAnchor {
    AnchorBase base;
    string proofType;
    string proofSystem;
    string circuitId;
    string vkeyHash;
    string auditFirm;
    string auditScope;
    string verifierUrl;
    string reportUrl;
    string proofHash;
}

// =========================================================================
// SELF-SERVICE STRUCT — type 17
// =========================================================================

struct RetractionAnchor {
    AnchorBase base;
    string targetArId;
    string reason;
    string replacedBy;
}

// =========================================================================
// REVIEW STRUCTS — types 18-20
// =========================================================================

struct ReviewAnchor {
    AnchorBase base;
    string targetArId;
    string reviewType;
    string evidenceUrl;
}

struct VoidAnchor {
    AnchorBase base;
    string targetArId;
    string reviewArId;
    string findingUrl;
    string evidence;
}

struct AffirmedAnchor {
    AnchorBase base;
    string targetArId;
    string affirmedBy;
    string findingUrl;
}

// =========================================================================
// BILLING STRUCT — type 21
// =========================================================================

struct AccountAnchor {
    AnchorBase base;
    uint256 capacity;
}

// =========================================================================
// CATCH-ALL STRUCT — type 22
// =========================================================================

struct OtherAnchor {
    AnchorBase base;
    string kind;
    string platform;
    string url;
    string value;
    string fileManifestHash; // SHA256 of the actual artifact file, empty if no file provided
}
