// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract NFTMarketplace is ERC721URIStorage, ReentrancyGuard, Ownable, Pausable, EIP712 {
    using Counters for Counters.Counter;
    using ECDSA for bytes32;

    // ========== Counters ==========
    Counters.Counter private _tokenIds;
    Counters.Counter private _itemsSold;
    Counters.Counter private _collectionIds;
    Counters.Counter private _bundleIds;
    Counters.Counter private _subscriptionIds;
    Counters.Counter private _lotteryIds;
    Counters.Counter private _affiliateIds;
    Counters.Counter private _dropIds;
    Counters.Counter private _stakingPoolIds;
    Counters.Counter private _proposalIds;
    Counters.Counter private _bridgeRequestIds;
    Counters.Counter private _rentalIds;
    Counters.Counter private _loanIds;
    Counters.Counter private _escrowIds;
    Counters.Counter private _analyticsIds;
    Counters.Counter private _socialIds;
    Counters.Counter private _gamificationIds;
    Counters.Counter private _metaverseIds;
    Counters.Counter private _daoIds;
    Counters.Counter private _musicIds;
    Counters.Counter private _carbonIds;

    // ========== Constants ==========
    uint256 public listingPrice = 0.025 ether;
    uint256 public royaltyPercentage = 250; // 2.5%
    uint256 public platformFee = 250; // 2.5%
    uint256 public minStakeAmount = 1 ether;
    uint256 public stakingRewardRate = 500; // 5% annually
    uint256 public constant SECONDS_PER_YEAR = 365 * 24 * 60 * 60;
    uint256 public constant MAX_ROYALTY = 1000; // 10% max royalty
    uint256 public constant MAX_BUNDLE_SIZE = 50;
    uint256 public constant LAZY_MINT_EXPIRY = 30 days;

    // NEW: Additional constants
    uint256 public constant METAVERSE_ENTRY_FEE = 0.01 ether;
    uint256 public constant DAO_PROPOSAL_DEPOSIT = 0.1 ether;
    uint256 public constant CARBON_OFFSET_RATE = 100; // 1% for carbon offsetting
    uint256 public constant VR_SESSION_DURATION = 3600; // 1 hour in seconds

    // ========== EIP-712 Type Hashes ==========
    bytes32 private constant _LAZY_MINT_TYPEHASH = 
        keccak256("LazyMintVoucher(uint256 tokenId,uint256 price,string uri,address creator,uint256 nonce,uint256 expiry)");
    
    bytes32 private constant _BID_TYPEHASH = 
        keccak256("SealedBid(uint256 tokenId,uint256 amount,uint256 nonce,uint256 expiry)");

    bytes32 private constant _METAVERSE_TYPEHASH =
        keccak256("MetaverseAccess(address user,uint256 tokenId,uint256 duration,uint256 nonce,uint256 expiry)");

    constructor() ERC721("NFT Marketplace", "NFTM") Ownable(msg.sender) EIP712("NFTMarketplace", "1") {
        // Initialize valid categories
        validCategories["Art"] = true;
        validCategories["Music"] = true;
        validCategories["Photography"] = true;
        validCategories["Gaming"] = true;
        validCategories["Sports"] = true;
        validCategories["Collectibles"] = true;
        validCategories["Utility"] = true;
        validCategories["Metaverse"] = true;
        validCategories["DeFi"] = true;
        validCategories["Memes"] = true;
        validCategories["AI"] = true;
        validCategories["Sustainability"] = true;
        validCategories["Education"] = true;
        validCategories["Health"] = true;
    }

    // ========== Modifiers ==========
    modifier onlyValidCategory(string memory category) {
        require(validCategories[category], "Invalid category");
        _;
    }

    modifier onlyTokenOwner(uint256 tokenId) {
        require(ownerOf(tokenId) == msg.sender || tokenApprovals[tokenId][msg.sender], "Not token owner or approved");
        _;
    }

    modifier onlyVerifiedCreator() {
        require(verifiedCreators[msg.sender], "Not verified creator");
        _;
    }

    modifier notBanned() {
        require(!bannedUsers[msg.sender], "User is banned");
        _;
    }

    modifier validTokenId(uint256 tokenId) {
        require(_exists(tokenId), "Token does not exist");
        _;
    }

    modifier onlyAnalyst() {
        require(marketAnalysts[msg.sender], "Not authorized analyst");
        _;
    }

    modifier rateLimited(address user) {
        require(block.timestamp >= lastActionTime[user] + actionCooldown, "Action rate limited");
        lastActionTime[user] = block.timestamp;
        _;
    }

    modifier onlyDAOMember() {
        require(daoMembers[msg.sender].isActive, "Not DAO member");
        _;
    }

    modifier onlyMetaverseEnabled(uint256 tokenId) {
        require(idToMarketItem[tokenId].isMetaverseEnabled, "Token not metaverse enabled");
        _;
    }

    // ========== NEW: Advanced Structs ==========
    
    // Metaverse Integration
    struct MetaverseItem {
        uint256 metaverseId;
        uint256 tokenId;
        string worldId;
        Vector3 position;
        Vector3 rotation;
        Vector3 scale;
        bool isInteractive;
        string[] animations;
        mapping(address => uint256) accessHistory;
        MetaverseProperties properties;
        VRCompatibility vrCompat;
        uint256 lastInteraction;
        bool isPublic;
        uint256 visitCount;
        mapping(address => bool) authorizedUsers;
    }

    struct Vector3 {
        int256 x;
        int256 y;
        int256 z;
    }

    struct MetaverseProperties {
        bool hasPhysics;
        bool hasSound;
        bool hasLighting;
        uint256 polygonCount;
        string[] supportedPlatforms;
        uint256 fileSize;
        string compressionType;
    }

    struct VRCompatibility {
        bool oculusSupport;
        bool htcViveSupport;
        bool psvr2Support;
        bool webXRSupport;
        uint256 minFrameRate;
        uint256 recommendedRAM;
    }

    // DAO Governance
    struct DAOGovernance {
        uint256 daoId;
        string name;
        string description;
        address treasuryAddress;
        uint256 totalMembers;
        uint256 activeProposals;
        uint256 totalProposals;
        mapping(address => DAOMember) members;
        mapping(uint256 => DAOProposal) proposals;
        DAOSettings settings;
        mapping(address => uint256) memberRewards;
        uint256 totalTreasuryValue;
        bool isActive;
    }

    struct DAOMember {
        address memberAddress;
        uint256 joinedAt;
        uint256 votingPower;
        uint256 contributionScore;
        uint256 proposalsCreated;
        uint256 votesParticipated;
        bool isActive;
        DAOMemberTier tier;
        uint256 reputationScore;
        mapping(uint256 => bool) proposalVotes;
    }

    enum DAOMemberTier { Bronze, Silver, Gold, Platinum, Diamond }

    struct DAOProposal {
        uint256 proposalId;
        string title;
        string description;
        address proposer;
        uint256 createdAt;
        uint256 votingStart;
        uint256 votingEnd;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool executed;
        bool cancelled;
        ProposalType proposalType;
        bytes executionData;
        uint256 requiredQuorum;
        mapping(address => Vote) votes;
        uint256 totalVoters;
    }

    struct Vote {
        bool hasVoted;
        bool support;
        uint256 weight;
        string comment;
    }

    // Music NFTs with Advanced Features
    struct MusicNFT {
        uint256 musicId;
        uint256 tokenId;
        string trackName;
        string artist;
        string album;
        uint256 duration; // in seconds
        string genre;
        uint256 bpm;
        string key;
        AudioProperties audio;
        RoyaltyDistribution royalties;
        mapping(address => uint256) streamCount;
        uint256 totalStreams;
        bool isRemixable;
        uint256[] remixTokenIds;
        mapping(address => bool) collaborators;
        LicensingTerms licensing;
    }

    struct AudioProperties {
        uint256 sampleRate;
        uint256 bitRate;
        string format;
        uint256 fileSize;
        bool isLossless;
        string codec;
    }

    struct RoyaltyDistribution {
        mapping(address => uint256) stakeholders; // address => percentage (basis points)
        uint256 totalPercentage;
        bool autoDistribute;
        uint256 lastDistribution;
    }

    struct LicensingTerms {
        bool allowCommercialUse;
        bool allowRemixing;
        bool allowSampling;
        uint256 licensePrice;
        string[] restrictions;
        uint256 exclusivityPeriod;
    }

    // Carbon Offset & Sustainability
    struct CarbonOffset {
        uint256 carbonId;
        uint256 tokenId;
        uint256 carbonFootprint; // in grams of CO2
        uint256 offsetAmount;
        string offsetProvider;
        string offsetProject;
        bool isVerified;
        uint256 offsetCertificateId;
        uint256 offsetDate;
        mapping(address => uint256) userContributions;
        uint256 totalOffsetCost;
        bool isFullyOffset;
    }

    struct SustainabilityMetrics {
        uint256 totalCarbonOffset;
        uint256 renewableEnergyUsed; // percentage
        uint256 ecoFriendlyMaterials; // percentage for physical items
        bool isEcoFriendly;
        string[] sustainabilityTags;
        uint256 environmentalImpactScore;
    }

    // AI-Generated Content
    struct AIGeneratedNFT {
        uint256 tokenId;
        string aiModel;
        string prompt;
        string negativePrompt;
        uint256 seed;
        uint256 steps;
        string sampler;
        uint256 cfgScale;
        mapping(string => string) parameters;
        bool isAIGenerated;
        string generationTimestamp;
        uint256 computeUnitsUsed;
        address aiProvider;
    }

    // Cross-Chain Bridge Enhanced
    struct CrossChainBridge {
        uint256 bridgeId;
        uint256 tokenId;
        address sourceOwner;
        uint256 sourceChain;
        uint256 targetChain;
        address targetAddress;
        BridgeStatus status;
        uint256 bridgeFee;
        uint256 estimatedTime;
        bytes32 sourceTxHash;
        bytes32 targetTxHash;
        uint256 timestamp;
        bool requiresValidation;
        mapping(address => bool) validators;
        uint256 validationCount;
        uint256 requiredValidations;
    }

    // Enhanced Analytics with ML Predictions
    struct MLPredictions {
        uint256 tokenId;
        uint256 predictedPrice30d;
        uint256 predictedPrice90d;
        uint256 priceConfidence; // 0-100
        uint256 liquidityScore;
        uint256 volatilityIndex;
        string[] trendingFactors;
        uint256 lastPredictionUpdate;
        bool isPredictionAccurate;
        uint256 historicalAccuracy;
    }

    // Real Estate NFTs
    struct RealEstateNFT {
        uint256 tokenId;
        string propertyAddress;
        uint256 propertyValue;
        uint256 squareFootage;
        string propertyType;
        bool isVirtual;
        GeoLocation location;
        PropertyDetails details;
        mapping(address => uint256) fractionalOwnership;
        uint256 rentalYield;
        bool isRentable;
        mapping(uint256 => RentalPeriod) rentalHistory;
        uint256 rentalPeriodCount;
    }

    struct GeoLocation {
        string latitude;
        string longitude;
        string country;
        string city;
        string state;
        string zipCode;
    }

    struct PropertyDetails {
        uint256 bedrooms;
        uint256 bathrooms;
        uint256 yearBuilt;
        string[] amenities;
        bool hasParking;
        string[] nearbyLandmarks;
        uint256 propertyTax;
        string zoning;
    }

    struct RentalPeriod {
        address tenant;
        uint256 startDate;
        uint256 endDate;
        uint256 monthlyRent;
        bool isActive;
    }

    // All previous structs from original code (abbreviated for space)
    struct Collection { 
        uint256 collectionId; 
        string name; 
        string description; 
        string coverImage; 
        address creator; 
        uint256 createdAt; 
        bool verified; 
        uint256[] tokenIds;
        uint256 floorPrice;
        uint256 totalVolume;
        bool isExclusive;
        uint256 royaltyPercentage;
        bool isWhitelisted;
        uint256 maxSupply;
        uint256 currentSupply;
        bytes32 merkleRoot;
        bool isRevealed;
        string preRevealURI;
        mapping(address => bool) collaborators;
        mapping(address => uint256) collaboratorShares;
        uint256 socialScore;
        CollectionAnalytics analytics;
    }

    struct CollectionAnalytics {
        uint256 totalViews;
        uint256 uniqueVisitors;
        uint256 averageHoldTime;
        uint256 flipRate;
        uint256 communityEngagement;
        mapping(uint256 => uint256) dailyVolume;
        mapping(address => uint256) topHolders;
    }

    struct MarketItem { 
        uint256 tokenId; 
        address payable seller; 
        address payable owner; 
        address payable creator; 
        uint256 price; 
        uint256 createdAt; 
        uint256 expiresAt; 
        bool sold; 
        bool isAuction; 
        string category; 
        uint256 collectionId; 
        uint256 views; 
        uint256 likes;
        bool isExclusive;
        uint256 unlockableContentHash;
        address[] collaborators;
        uint256[] collaboratorShares;
        bool isLazyMinted;
        uint256 editionNumber;
        uint256 totalEditions;
        bool acceptsOffers;
        uint256 minOffer;
        PaymentMethod[] acceptedPayments;
        TokenMetrics metrics;
        SocialData socialData;
        LegalData legalData;
        // NEW: Enhanced properties
        bool isMetaverseEnabled;
        bool isAIGenerated;
        bool hasCarbonOffset;
        bool isMusicNFT;
        bool isRealEstate;
        bool isFractional;
        uint256 utilityScore;
    }

    struct TokenMetrics {
        uint256 priceHistory;
        uint256 volumeTraded;
        uint256 numberOfSales;
        uint256 averageHoldTime;
        uint256 rarityScore;
        uint256 liquidityScore;
        mapping(uint256 => uint256) dailyPrices;
    }

    struct SocialData {
        uint256 shares;
        uint256 comments;
        uint256 reactions;
        mapping(address => bool) liked;
        mapping(address => string) comments;
        address[] commenters;
        uint256 trendingScore;
    }

    struct LegalData {
        string termsOfUse;
        string licenseType;
        bool isCommercialUse;
        string[] restrictions;
        address legalEntity;
        string jurisdiction;
        bool hasPhysicalRights;
    }

    // ========== Enhanced Mappings ==========
    mapping(uint256 => MarketItem) private idToMarketItem;
    mapping(uint256 => Collection) private idToCollection;
    
    // NEW: Advanced feature mappings
    mapping(uint256 => MetaverseItem) private idToMetaverseItem;
    mapping(uint256 => DAOGovernance) private idToDAO;
    mapping(uint256 => MusicNFT) private idToMusicNFT;
    mapping(uint256 => CarbonOffset) private idToCarbonOffset;
    mapping(uint256 => AIGeneratedNFT) private idToAIGeneratedNFT;
    mapping(uint256 => CrossChainBridge) private idToCrossChainBridge;
    mapping(uint256 => MLPredictions) private idToMLPredictions;
    mapping(uint256 => RealEstateNFT) private idToRealEstateNFT;

    // User and system mappings
    mapping(address => bool) private verifiedCreators;
    mapping(string => bool) private validCategories;
    mapping(address => uint256) private creatorEarnings;
    mapping(address => bool) private bannedUsers;
    mapping(address => uint256) private userNonce;
    mapping(address => address) private referrals;
    mapping(address => uint256[]) private userCollections;
    mapping(address => bool) private marketAnalysts;
    mapping(address => uint256) private lastActionTime;
    mapping(uint256 => mapping(address => bool)) private tokenApprovals;
    mapping(address => uint256) private votingPower;

    // NEW: Enhanced mappings
    mapping(address => DAOMember) private daoMembers;
    mapping(address => uint256[]) private userMetaverseItems;
    mapping(string => bool) private supportedMetaversePlatforms;
    mapping(address => uint256) private carbonContributions;
    mapping(address => bool) private aiProviders;
    mapping(uint256 => mapping(address => uint256)) private fractionalShares;
    mapping(address => uint256[]) private userRealEstate;

    // Configuration
    uint256 public actionCooldown = 1 seconds;
    bool public aiRecommendationsEnabled = true;
    bool public socialTradingEnabled = true;
    bool public gamificationEnabled = true;
    bool public metaverseEnabled = true;
    bool public daoEnabled = true;
    bool public carbonOffsetEnabled = true;
    bool public crossChainEnabled = true;

    enum PaymentMethod { ETH, ERC20, Crypto, Fiat }
    enum ProposalType { FeeChange, CategoryAdd, FeatureToggle, Emergency, ParameterChange }
    enum BridgeStatus { Pending, Processing, Completed, Failed, Cancelled }

    // ========== NEW: Enhanced Events ==========
    event MetaverseItemCreated(uint256 indexed metaverseId, uint256 indexed tokenId, string worldId);
    event MetaverseAccessed(uint256 indexed tokenId, address indexed user, uint256 duration);
    event DAOCreated(uint256 indexed daoId, string name, address creator);
    event DAOMemberJoined(uint256 indexed daoId, address indexed member, DAOMemberTier tier);
    event DAOProposalCreated(uint256 indexed daoId, uint256 indexed proposalId, string title);
    event DAOVoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event MusicNFTCreated(uint256 indexed musicId, uint256 indexed tokenId, string trackName, string artist);
    event MusicStreamed(uint256 indexed tokenId, address indexed listener, uint256 streamCount);
    event CarbonOffsetPurchased(uint256 indexed carbonId, uint256 indexed tokenId, uint256 offsetAmount);
    event AIContentGenerated(uint256 indexed tokenId, string aiModel, address indexed creator);
    event CrossChainBridgeInitiated(uint256 indexed bridgeId, uint256 indexed tokenId, uint256 targetChain);
    event PredictionUpdated(uint256 indexed tokenId, uint256 predictedPrice, uint256 confidence);
    event RealEstateTokenized(uint256 indexed tokenId, string propertyAddress, uint256 propertyValue);
    event FractionalSharesCreated(uint256 indexed tokenId, uint256 totalShares, uint256 sharePrice);
    event RentalAgreementCreated(uint256 indexed tokenId, address indexed tenant, uint256 monthlyRent);

    // Original events
    event MarketItemCreated(uint256 indexed tokenId, address seller, address owner, uint256 price, bool sold, string category);
    event MarketItemSold(uint256 indexed tokenId, address seller, address buyer, uint256 price, address indexed referrer);

    // ========== NEW: Metaverse Integration Functions ==========
    
    function createMetaverseItem(
        uint256 tokenId,
        string memory worldId,
        Vector3 memory position,
        Vector3 memory rotation,
        Vector3 memory scale,
        bool isInteractive,
        string[] memory animations
    ) external onlyTokenOwner(tokenId) whenNotPaused {
        require(metaverseEnabled, "Metaverse features disabled");
        require(idToMarketItem[tokenId].isMetaverseEnabled, "Token not metaverse enabled");
        
        _metaverseIds.increment();
        uint256 metaverseId = _metaverseIds.current();
        
        MetaverseItem storage item = idToMetaverseItem[metaverseId];
        item.metaverseId = metaverseId;
        item.tokenId = tokenId;
        item.worldId = worldId;
        item.position = position;
        item.rotation = rotation;
        item.scale = scale;
        item.isInteractive = isInteractive;
        item.animations = animations;
        item.lastInteraction = block.timestamp;
        item.isPublic = true;
        
        userMetaverseItems[msg.sender].push(metaverseId);
        
        emit MetaverseItemCreated(metaverseId, tokenId, worldId);
    }
    
    function accessMetaverseItem(uint256 metaverseId, uint256 duration) external payable nonReentrant {
        require(metaverseEnabled, "Metaverse features disabled");
        require(msg.value >= METAVERSE_ENTRY_FEE * duration, "Insufficient entry fee");
        
        MetaverseItem storage item = idToMetaverseItem[metaverseId];
        require(item.isPublic || item.authorizedUsers[msg.sender], "Access denied");
        
        item.accessHistory[msg.sender] += duration;
        item.visitCount++;
        item.lastInteraction = block.timestamp;
        
        // Pay fees to token owner
        address tokenOwner = ownerOf(item.tokenId);
        payable(tokenOwner).transfer(msg.value * 70 / 100); // 70% to owner
        // 30% to platform
        
        emit MetaverseAccessed(item.tokenId, msg.sender, duration);
    }

    // ========== NEW: DAO Governance Functions ==========
    
    function createDAO(
        string memory name,
        string memory description,
        address treasuryAddress
    ) external payable nonReentrant returns (uint256) {
        require(daoEnabled, "DAO features disabled");
        require(msg.value >= DAO_PROPOSAL_DEPOSIT, "Insufficient deposit");
        
        _daoIds.increment();
        uint256 daoId = _daoIds.current();
        
        DAOGovernance storage dao = idToDAO[daoId];
        dao.daoId = daoId;
        dao.name = name;
        dao.description = description;
        dao.treasuryAddress = treasuryAddress;
        dao.totalMembers = 1;
        dao.isActive = true;
        
        // Add creator as first member
        DAOMember storage member = dao.members[msg.sender];
        member.memberAddress = msg.sender;
        member.joinedAt = block.timestamp;
        member.votingPower = 1000; // Initial voting power
        member.isActive = true;
        member.tier = DAOMemberTier.Gold;
        member.reputationScore = 100;
        
        daoMembers[msg.sender] = member;
        
        emit DAOCreated(daoId, name, msg.sender);
        return daoId;
    }
    
    function joinDAO(uint256 daoId) external nonReentrant {
        require(daoEnabled, "DAO features disabled");
        DAOGovernance storage dao = idToDAO[daoId];
        require(dao.isActive, "DAO not active");
        require(!dao.members[msg.sender].isActive, "Already a member");
        
        DAOMember storage member = dao.members[msg.sender];
        member.memberAddress = msg.sender;
        member.joinedAt = block.timestamp;
        member.votingPower = 100; // Base voting power
        member.isActive = true;
        member.tier = DAOMemberTier.Bronze;
        member.reputationScore = 10;
        
        dao.totalMembers++;
        daoMembers[msg.sender] = member;
        
        emit DAOMemberJoined(daoId, msg.sender, DAOMemberTier.Bronze);
    }
    
    function createDAOProposal(
        uint256 daoId,
        string memory title,
        string memory description,
        ProposalType proposalType,
        bytes memory executionData
    ) external onlyDAOMember returns (uint256) {
        DAOGovernance storage dao = idToDAO[daoId];
        require(dao.isActive, "DAO not active");
        require(dao.members[msg.sender].isActive, "Not DAO member");
        
        _proposalIds.increment();
        uint256 proposalId = _proposalIds.current();
        
        DAOProposal storage proposal = dao.proposals[proposalId];
        proposal.proposalId = proposalId;
        proposal.title = title;
        proposal.description = description;
        proposal.proposer = msg.sender;
        proposal.createdAt = block.timestamp;
        proposal.votingStart = block.timestamp + 1 days;
        proposal.votingEnd = block.timestamp + 8 days;
        proposal.proposalType = proposalType;
        proposal.executionData = executionData;
        proposal.requiredQuorum = (dao.totalMembers * 51) / 100; // 51% quorum
        
        dao.activeProposals++;
        dao.totalProposals++;
        dao.members[msg.sender].proposalsCreated++;
        
        emit DAOProposalCreated(daoId, proposalId, title);
        return proposalId;
    }

    // ========== NEW: Music NFT Functions ==========
    
    function createMusicNFT(
        string memory uri,
        string memory trackName,
        string memory artist,
        string memory album,
        uint256 duration,
        string memory genre,
        uint256 bpm,
        string memory key,
        AudioProperties memory audioProps,
        bool isRemixable
    ) external onlyVerifiedCreator returns (uint256) {
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        
        _mint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, uri);
        
        _musicIds.increment();
        uint256 musicId = _musicIds.current();
        
        MusicNFT storage musicNFT = idToMusicNFT[musicId];
        musicNFT.musicId = musicId;
        musicNFT.tokenId = newTokenId;
        musicNFT.trackName = trackName;
        musicNFT.artist = artist;
        musicNFT.album = album;
        musicNFT.duration = duration;
        musicNFT.genre = genre;
        musicNFT.bpm = bpm;
        musicNFT.key = key;
        musicNFT.audio = audioProps;
        musicNFT.isRemixable = isRemixable;
        
        // Set default royalty distribution (100% to creator initially)
        musicNFT.royalties.stakeholders[msg.sender] = 10000; // 100% in basis points
        musicNFT.royalties.totalPercentage = 10000;
        musicNFT.royalties.autoDistribute = true;
        
        // Mark as music NFT
        idToMarketItem[newTokenId].isMusicNFT = true;
        idToMarketItem[newTokenId].creator = payable(msg.sender);
        
        emit MusicNFTCreated(musicId, newTokenId, trackName, artist);
        return newTokenId;
    }
    
    function streamMusic(uint256 tokenId) external nonReentrant rateLimited(msg.sender) {
        require(idToMarketItem[tokenId].isMusicNFT, "Not a music NFT");
        
        // Find music NFT ID
        uint256 musicId = 0;
        for (uint256 i = 1; i <= _musicIds.current(); i++) {
            if (idToMusicNFT[i].tokenId == tokenId) {
                musicId = i;
                break;
            }
        }
        require(musicId > 0, "Music NFT not found");
        
        MusicNFT
