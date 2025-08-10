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
    Counters.Counter private _aiPricingIds;
    // NEW COUNTERS
    Counters.Counter private _virtualGalleryIds;
    Counters.Counter private _aiArtIds;
    Counters.Counter private _subscriptionTierIds;
    Counters.Counter private _loyaltyProgramIds;
    Counters.Counter private _crossChainIds;
    Counters.Counter private _gameAssetIds;

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

    // Previous constants
    uint256 public constant METAVERSE_ENTRY_FEE = 0.01 ether;
    uint256 public constant DAO_PROPOSAL_DEPOSIT = 0.1 ether;
    uint256 public constant CARBON_OFFSET_RATE = 100; // 1% for carbon offsetting
    uint256 public constant VR_SESSION_DURATION = 3600; // 1 hour in seconds

    // Dynamic Pricing AI Constants
    uint256 public constant AI_PRICING_UPDATE_INTERVAL = 1 hours;
    uint256 public constant MIN_PRICE_CHANGE_THRESHOLD = 50; // 0.5% minimum change
    uint256 public constant MAX_PRICE_CHANGE_PER_UPDATE = 2000; // 20% maximum change per update
    uint256 public constant PRICING_CONFIDENCE_THRESHOLD = 7000; // 70% confidence minimum
    uint256 public constant MARKET_VOLATILITY_THRESHOLD = 1500; // 15% volatility threshold

    // NEW CONSTANTS
    uint256 public constant VIRTUAL_GALLERY_FEE = 0.005 ether;
    uint256 public constant AI_GENERATION_FEE = 0.02 ether;
    uint256 public constant PREMIUM_SUBSCRIPTION_FEE = 0.1 ether;
    uint256 public constant CROSS_CHAIN_FEE = 0.01 ether;
    uint256 public constant MAX_AI_GENERATIONS_PER_DAY = 10;
    uint256 public constant LOYALTY_TIER_UPGRADE_THRESHOLD = 1000; // Points needed
    uint256 public constant SUBSCRIPTION_DURATION = 30 days;

    // ========== EIP-712 Type Hashes ==========
    bytes32 private constant _LAZY_MINT_TYPEHASH = 
        keccak256("LazyMintVoucher(uint256 tokenId,uint256 price,string uri,address creator,uint256 nonce,uint256 expiry)");
    
    bytes32 private constant _BID_TYPEHASH = 
        keccak256("SealedBid(uint256 tokenId,uint256 amount,uint256 nonce,uint256 expiry)");

    bytes32 private constant _METAVERSE_TYPEHASH =
        keccak256("MetaverseAccess(address user,uint256 tokenId,uint256 duration,uint256 nonce,uint256 expiry)");

    bytes32 private constant _AI_PRICING_TYPEHASH =
        keccak256("AIPricingUpdate(uint256 tokenId,uint256 newPrice,uint256 confidence,uint256 timestamp,uint256 nonce)");

    // NEW TYPE HASHES
    bytes32 private constant _CROSS_CHAIN_TYPEHASH =
        keccak256("CrossChainTransfer(uint256 tokenId,uint256 targetChain,address targetAddress,uint256 nonce,uint256 expiry)");

    bytes32 private constant _AI_GENERATION_TYPEHASH =
        keccak256("AIGeneration(address user,string prompt,string style,uint256 nonce,uint256 expiry)");

    constructor() ERC721("NFT Marketplace", "NFTM") EIP712("NFTMarketplace", "1") {
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
        validCategories["VirtualGallery"] = true; // NEW
        validCategories["GameAsset"] = true; // NEW

        // Initialize AI Pricing Oracle
        aiPricingOracle = msg.sender;
        authorizedAIOracles[msg.sender] = true;
        globalPricingEnabled = true;
        marketSentimentWeight = 3000; // 30%
        rarityWeight = 2500; // 25%
        volumeWeight = 2000; // 20%
        socialWeight = 1500; // 15%
        utilityWeight = 1000; // 10%
        lastGlobalMarketUpdate = block.timestamp;

        // NEW: Initialize default loyalty program
        _createDefaultLoyaltyProgram();
        
        // NEW: Initialize supported chains
        supportedChains[1] = true; // Ethereum
        supportedChains[137] = true; // Polygon
        supportedChains[56] = true; // BSC
        supportedChains[43114] = true; // Avalanche
        
        // NEW: Initialize AI art styles
        supportedAIStyles["Realistic"] = true;
        supportedAIStyles["Abstract"] = true;
        supportedAIStyles["Impressionist"] = true;
        supportedAIStyles["Cyberpunk"] = true;
        supportedAIStyles["Fantasy"] = true;
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

    modifier onlyAIPricingOracle() {
        require(msg.sender == aiPricingOracle || msg.sender == owner() || authorizedAIOracles[msg.sender], "Not authorized for AI pricing");
        _;
    }

    modifier validPricingUpdate(uint256 tokenId, uint256 newPrice, uint256 confidence) {
        require(confidence >= PRICING_CONFIDENCE_THRESHOLD, "Confidence too low");
        require(newPrice > 0, "Price must be positive");
        
        DynamicPricing storage pricing = idToDynamicPricing[tokenId];
        if (pricing.isActive) {
            uint256 currentPrice = pricing.currentAIPrice;
            uint256 maxChange = (currentPrice * MAX_PRICE_CHANGE_PER_UPDATE) / 10000;
            if (currentPrice > 0) {
                require(
                    newPrice <= currentPrice + maxChange && newPrice >= currentPrice - maxChange,
                    "Price change exceeds maximum threshold"
                );
            }
        }
        _;
    }

    // NEW MODIFIERS
    modifier onlyPremiumSubscriber() {
        require(userSubscriptions[msg.sender].isActive && userSubscriptions[msg.sender].tier >= SubscriptionTier.Premium, "Premium subscription required");
        _;
    }

    modifier onlyGalleryOwner(uint256 galleryId) {
        require(idToVirtualGallery[galleryId].owner == msg.sender, "Not gallery owner");
        _;
    }

    modifier validAIGenerationRequest(string memory prompt, string memory style) {
        require(bytes(prompt).length > 0 && bytes(prompt).length <= 1000, "Invalid prompt length");
        require(supportedAIStyles[style], "Unsupported AI style");
        require(userAIGenerations[msg.sender][today()] < MAX_AI_GENERATIONS_PER_DAY, "Daily AI generation limit exceeded");
        _;
    }

    modifier onlySupportedChain(uint256 chainId) {
        require(supportedChains[chainId], "Unsupported chain");
        _;
    }

    // ========== NEW STRUCTS ==========

    struct VirtualGallery {
        uint256 galleryId;
        string name;
        string description;
        address owner;
        uint256 createdAt;
        uint256[] exhibitedTokenIds;
        GalleryTheme theme;
        GallerySettings settings;
        mapping(address => bool) curators;
        mapping(address => uint256) visitHistory;
        uint256 totalVisits;
        uint256 entryFee;
        bool isPublic;
        string metaverseLocation;
        VRExperience vrExperience;
        mapping(uint256 => ExhibitInfo) exhibits;
        uint256 maxCapacity;
        bool isLive; // For live events
        uint256 nextEventTime;
        mapping(address => bool) vipAccess;
    }

    struct GalleryTheme {
        string backgroundColor;
        string wallTexture;
        string floorTexture;
        string lightingMode;
        string musicPlaylist;
        bool enableParticleEffects;
        string customShaders;
    }

    struct GallerySettings {
        bool allowComments;
        bool allowLikes;
        bool allowSharing;
        bool enableAnalytics;
        bool moderateContent;
        uint256 maxVisitorsPerSession;
        bool requireRegistration;
        string[] bannedWords;
    }

    struct ExhibitInfo {
        uint256 tokenId;
        Vector3 position;
        Vector3 scale;
        string description;
        string audioGuide;
        bool isInteractive;
        mapping(address => string) visitorComments;
        uint256 viewCount;
        uint256 interactionCount;
    }

    struct VRExperience {
        bool isVREnabled;
        string vrWorldId;
        Vector3 spawnPoint;
        string[] availableAvatars;
        bool enableVoiceChat;
        bool enableHandTracking;
        string vrPlatform;
        uint256 maxVRUsers;
    }

    struct AIArtGeneration {
        uint256 aiArtId;
        address requester;
        string prompt;
        string style;
        string negativePrompt;
        uint256 seed;
        uint256 steps;
        string model;
        uint256 requestedAt;
        uint256 completedAt;
        string resultURI;
        bool isCompleted;
        bool isMinted;
        uint256 generationCost;
        AIParameters parameters;
        mapping(address => bool) collaborativeVotes;
        uint256 qualityScore;
        bool isPublic;
    }

    struct AIParameters {
        uint256 width;
        uint256 height;
        uint256 cfgScale;
        string sampler;
        bool enableUpscaling;
        uint256 upscaleFactor;
        bool enableFaceRestore;
        string additionalPrompts;
        bool enableStyleTransfer;
        string referenceImageURI;
    }

    struct SubscriptionTier {
        uint256 tierId;
        string name;
        uint256 monthlyFee;
        uint256 discountPercentage;
        uint256 maxListings;
        uint256 maxAIGenerations;
        bool enablePrioritySupport;
        bool enableAnalytics;
        bool enableCustomGalleries;
        bool enableCrossChain;
        bool enableBulkOperations;
        string[] additionalFeatures;
        uint256 loyaltyMultiplier;
    }

    struct UserSubscription {
        uint256 tierId;
        SubscriptionTier tier;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        bool autoRenew;
        uint256 totalSpent;
        mapping(string => bool) usedFeatures;
        uint256 featureUsageCount;
    }

    struct LoyaltyProgram {
        uint256 programId;
        string name;
        mapping(address => LoyaltyMember) members;
        LoyaltyTier[] tiers;
        mapping(string => LoyaltyReward) rewards;
        bool isActive;
        uint256 totalMembers;
        uint256 pointsToEtherRate;
    }

    struct LoyaltyMember {
        address memberAddress;
        uint256 totalPoints;
        uint256 currentTier;
        uint256 joinedAt;
        uint256 lastActivityAt;
        mapping(string => uint256) earnedRewards;
        uint256 lifetimeSpent;
        uint256 referralCount;
        bool isActive;
    }

    struct LoyaltyTier {
        string name;
        uint256 pointsRequired;
        uint256 discountPercentage;
        string[] benefits;
        string badgeURI;
        uint256 monthlyTokenAllowance;
    }

    struct LoyaltyReward {
        string name;
        uint256 pointsCost;
        string description;
        bool isActive;
        uint256 maxClaims;
        uint256 claimedCount;
        string rewardType; // "DISCOUNT", "NFT", "ACCESS", "PHYSICAL"
        bytes rewardData;
    }

    struct CrossChainBridge {
        uint256 bridgeId;
        uint256 tokenId;
        uint256 sourceChain;
        uint256 targetChain;
        address sourceOwner;
        address targetAddress;
        uint256 bridgeFee;
        BridgeStatus status;
        uint256 requestedAt;
        uint256 processedAt;
        string txHashSource;
        string txHashTarget;
        bytes32 merkleProof;
        bool isEmergencyWithdrawable;
    }

    enum BridgeStatus { Pending, InProgress, Completed, Failed, Cancelled }

    struct GameAssetIntegration {
        uint256 assetId;
        uint256 tokenId;
        string gameId;
        string assetType;
        mapping(string => uint256) gameStats;
        mapping(string => bool) gameFeatures;
        uint256 powerLevel;
        uint256 rarity;
        bool isTransferable;
        bool isUpgradeable;
        uint256 experiencePoints;
        mapping(address => uint256) playerUsage;
        string[] compatibleGames;
        bytes gameData;
    }

    // ========== EXISTING STRUCTS (Condensed) ==========
    
    struct Vector3 {
        int256 x;
        int256 y;
        int256 z;
    }

    struct DynamicPricing {
        uint256 aiPricingId;
        uint256 tokenId;
        uint256 basePrice;
        uint256 currentAIPrice;
        uint256 lastUpdateTime;
        uint256 priceConfidence;
        bool isActive;
        bool ownerOptedIn;
        PricingStrategy strategy;
        MarketFactors factors;
        PriceHistory[] priceHistory;
        uint256 totalUpdates;
        uint256 accuracyScore;
        mapping(address => bool) authorizedUpdaters;
        AutoPricingRules rules;
    }

    struct PricingStrategy {
        PricingType pricingType;
        uint256 targetVolatility;
        uint256 responsiveness;
        uint256 trendFollowing;
        bool enableFloorProtection;
        uint256 floorPriceMultiplier;
        bool enableCeilingCap;
        uint256 ceilingPriceMultiplier;
    }

    struct MarketFactors {
        int256 marketSentiment;
        uint256 collectionFloorPrice;
        uint256 collectionVolume24h;
        uint256 rarityRank;
        uint256 utilityScore;
        uint256 socialEngagement;
        uint256 liquidityScore;
        uint256 marketCapTrend;
        uint256 competitorPricing;
        uint256 seasonalityFactor;
        uint256 newsPressureScore;
        uint256 whaleActivityScore;
    }

    struct PriceHistory {
        uint256 timestamp;
        uint256 price;
        uint256 confidence;
        string reason;
        uint256 marketVolume;
        uint256 gasPrice;
    }

    struct AutoPricingRules {
        bool enableAutoUpdate;
        uint256 updateFrequency;
        uint256 minConfidenceLevel;
        uint256 maxPriceIncrease;
        uint256 maxPriceDecrease;
        bool pauseOnHighVolatility;
        uint256 volatilityThreshold;
        bool enableEmergencyStop;
        address[] emergencyStoppers;
        uint256 minLiquidityRequirement;
    }

    struct AIMarketAnalysis {
        uint256 analysisId;
        uint256 timestamp;
        uint256 overallMarketSentiment;
        uint256 nftMarketTrend;
        uint256 categoryTrend;
        uint256 collectionTrend;
        uint256 predictedVolatility;
        uint256 recommendedStrategy;
        mapping(string => uint256) categoryScores;
        mapping(address => uint256) topCollections;
        MarketPredictions predictions;
        TrendingFactors trending;
    }

    struct MarketPredictions {
        uint256 price1h;
        uint256 price24h;
        uint256 price7d;
        uint256 price30d;
        uint256 confidence1h;
        uint256 confidence24h;
        uint256 confidence7d;
        uint256 confidence30d;
        string[] bullishFactors;
        string[] bearishFactors;
    }

    struct TrendingFactors {
        string[] positiveFactors;
        string[] negativeFactors;
        uint256[] factorWeights;
        uint256 trendStrength;
        bool isBreakoutPattern;
    }

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
        bool isMetaverseEnabled;
        bool isAIGenerated;
        bool hasCarbonOffset;
        bool isMusicNFT;
        bool isRealEstate;
        bool isFractional;
        uint256 utilityScore;
        bool hasDynamicPricing;
        uint256 aiPricingId;
        // NEW FIELDS
        bool isGameAsset;
        uint256 gameAssetId;
        bool isInVirtualGallery;
        uint256[] galleryIds;
        bool crossChainEnabled;
        uint256[] supportedChainIds;
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

    enum PricingType { Conservative, Balanced, Aggressive, Momentum, Contrarian, ValueBased, Technical }
    enum DAOMemberTier { Bronze, Silver, Gold, Platinum, Diamond }
    enum PaymentMethod { ETH, ERC20, Crypto, Fiat }
    enum ProposalType { FeeChange, CategoryAdd, FeatureToggle, Emergency, ParameterChange }

    // ========== MAPPINGS ==========
    mapping(uint256 => MarketItem) private idToMarketItem;
    mapping(uint256 => Collection) private idToCollection;
    mapping(uint256 => DynamicPricing) private idToDynamicPricing;
    mapping(uint256 => AIMarketAnalysis) private idToMarketAnalysis;

    // NEW MAPPINGS
    mapping(uint256 => VirtualGallery) private idToVirtualGallery;
    mapping(uint256 => AIArtGeneration) private idToAIArtGeneration;
    mapping(address => UserSubscription) private userSubscriptions;
    mapping(uint256 => SubscriptionTier) private subscriptionTiers;
    mapping(uint256 => LoyaltyProgram) private loyaltyPrograms;
    mapping(uint256 => CrossChainBridge) private idToCrossChainBridge;
    mapping(uint256 => GameAssetIntegration) private idToGameAsset;
    
    mapping(address => bool) private authorizedAIOracles;
    mapping(uint256 => mapping(uint256 => uint256)) private tokenPriceByHour;
    mapping(string => uint256) private categoryMarketTrends;
    mapping(address => uint256) private collectionMarketScores;
    
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
    mapping(address => DAOMember) private daoMembers;
    mapping(address => uint256) private carbonContributions;

    // NEW SPECIFIC MAPPINGS
    mapping(address => uint256[]) private userVirtualGalleries;
    mapping(address => mapping(uint256 => uint256)) private userAIGenerations; // user => day => count
    mapping(string => bool) private supportedAIStyles;
    mapping(uint256 => bool) private supportedChains;
    mapping(address => uint256[]) private userCrossChainTokens;
    mapping(string => mapping(uint256 => bool)) private gameAssetInGame;
    mapping(address => mapping(string => uint256)) private playerGameStats;

    // Configuration
    address public aiPricingOracle;
    bool public globalPricingEnabled;
    uint256 public marketSentimentWeight;
    uint256 public rarityWeight;
    uint256 public volumeWeight;
    uint256 public socialWeight;
    uint256 public utilityWeight;
    uint256 public lastGlobalMarketUpdate;
    uint256 public actionCooldown = 1 seconds;
    bool public aiRecommendationsEnabled = true;
    bool public socialTradingEnabled = true;
    bool public gamificationEnabled = true;
    bool public metaverseEnabled = true;
    bool public daoEnabled = true;
    bool public carbonOffsetEnabled = true;
    bool public crossChainEnabled = true;

    // NEW CONFIGURATION
    bool public virtualGalleriesEnabled = true;
    bool public aiArtGenerationEnabled = true;
    bool public loyaltyProgramEnabled = true;
    bool public gameAssetIntegrationEnabled = true;
    uint256 public defaultLoyaltyProgramId = 1;

    uint256 private platformFeeBalance;

    // ========== EVENTS ==========
    
    // Dynamic Pricing AI Events
    event DynamicPricingEnabled(uint256 indexed tokenId, uint256 basePrice, PricingType strategy);
    event AIPriceUpdated(uint256 indexed tokenId, uint256 oldPrice, uint256 newPrice, uint256 confidence, string reason);
    event PricingStrategyChanged(uint256 indexed tokenId, PricingType oldStrategy, PricingType newStrategy);
    event MarketAnalysisUpdated(uint256 indexed analysisId, uint256 overallSentiment, uint256 timestamp);
    event EmergencyPricingStop(uint256 indexed tokenId, address indexed stopper, string reason);
    event PricingOracleUpdated(address indexed oldOracle, address indexed newOracle);
    event AIPricingConfigured(uint256 tokenId, AutoPricingRules rules);

    // Basic marketplace events
    event MarketItemCreated(uint256 indexed tokenId, address seller, address owner, uint256 price, bool sold, string category);
    event MarketItemSold(uint256 indexed tokenId, address seller, address buyer, uint256 price, address indexed referrer);

    // NEW EVENTS
    event VirtualGalleryCreated(uint256 indexed galleryId, string name, address indexed owner);
    event VirtualGalleryVisited(uint256 indexed galleryId, address indexed visitor, uint256 timestamp);
    event TokenExhibited(uint256 indexed galleryId, uint256 indexed tokenId, address indexed curator);
    event AIArtRequested(uint256 indexed aiArtId, address indexed requester, string prompt, string style);
    event AIArtGenerated(uint256 indexed aiArtId, uint256 indexed tokenId, string resultURI);
    event SubscriptionActivated(address indexed user, uint256 indexed tierId, uint256 duration);
    event SubscriptionRenewed(address indexed user, uint256 indexed tierId, uint256 newEndTime);
    event LoyaltyPointsEarned(address indexed user, uint256 points, string action);
    event LoyaltyRewardClaimed(address indexed user, string rewardName, uint256 pointsSpent);
    event CrossChainBridgeInitiated(uint256 indexed bridgeId, uint256 indexed tokenId, uint256 sourceChain, uint256 targetChain);
    event CrossChainBridgeCompleted(uint256 indexed bridgeId, string targetTxHash);
    event GameAssetCreated(uint256 indexed assetId, uint256 indexed tokenId, string gameId, string assetType);
    event GameAssetUsed(uint256
