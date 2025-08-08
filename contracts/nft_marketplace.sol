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
    Counters.Counter private _aiPricingIds; // NEW: Dynamic Pricing AI Counter

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

    // NEW: Dynamic Pricing AI Constants
    uint256 public constant AI_PRICING_UPDATE_INTERVAL = 1 hours;
    uint256 public constant MIN_PRICE_CHANGE_THRESHOLD = 50; // 0.5% minimum change
    uint256 public constant MAX_PRICE_CHANGE_PER_UPDATE = 2000; // 20% maximum change per update
    uint256 public constant PRICING_CONFIDENCE_THRESHOLD = 7000; // 70% confidence minimum
    uint256 public constant MARKET_VOLATILITY_THRESHOLD = 1500; // 15% volatility threshold

    // ========== EIP-712 Type Hashes ==========
    bytes32 private constant _LAZY_MINT_TYPEHASH = 
        keccak256("LazyMintVoucher(uint256 tokenId,uint256 price,string uri,address creator,uint256 nonce,uint256 expiry)");
    
    bytes32 private constant _BID_TYPEHASH = 
        keccak256("SealedBid(uint256 tokenId,uint256 amount,uint256 nonce,uint256 expiry)");

    bytes32 private constant _METAVERSE_TYPEHASH =
        keccak256("MetaverseAccess(address user,uint256 tokenId,uint256 duration,uint256 nonce,uint256 expiry)");

    // NEW: Dynamic Pricing AI Type Hash
    bytes32 private constant _AI_PRICING_TYPEHASH =
        keccak256("AIPricingUpdate(uint256 tokenId,uint256 newPrice,uint256 confidence,uint256 timestamp,uint256 nonce)");

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

        // NEW: Initialize AI Pricing Oracle
        aiPricingOracle = msg.sender; // Initially set to contract owner
        authorizedAIOracles[msg.sender] = true;
        globalPricingEnabled = true;
        marketSentimentWeight = 3000; // 30%
        rarityWeight = 2500; // 25%
        volumeWeight = 2000; // 20%
        socialWeight = 1500; // 15%
        utilityWeight = 1000; // 10%
        lastGlobalMarketUpdate = block.timestamp;
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

    // NEW: AI Pricing Modifiers
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

    // ========== NEW: Dynamic Pricing AI Structs ==========
    
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
        uint256 targetVolatility; // Basis points
        uint256 responsiveness; // How quickly to react to market changes (1-100)
        uint256 trendFollowing; // Percentage to follow market trends (0-100)
        bool enableFloorProtection;
        uint256 floorPriceMultiplier; // Minimum price as % of floor price
        bool enableCeilingCap;
        uint256 ceilingPriceMultiplier; // Maximum price as % of collection ceiling
    }

    struct MarketFactors {
        int256 marketSentiment; // -100 .. 100
        uint256 collectionFloorPrice;
        uint256 collectionVolume24h;
        uint256 rarityRank;
        uint256 utilityScore;
        uint256 socialEngagement;
        uint256 liquidityScore;
        uint256 marketCapTrend;
        uint256 competitorPricing;
        uint256 seasonalityFactor;
        uint256 newsPressureScore; // Impact of news/events
        uint256 whaleActivityScore; // Large holder movements
    }

    struct PriceHistory {
        uint256 timestamp;
        uint256 price;
        uint256 confidence;
        string reason; // Why price changed
        uint256 marketVolume;
        uint256 gasPrice; // Gas price at time of update
    }

    struct AutoPricingRules {
        bool enableAutoUpdate;
        uint256 updateFrequency; // In seconds
        uint256 minConfidenceLevel;
        uint256 maxPriceIncrease; // Per update, in basis points
        uint256 maxPriceDecrease; // Per update, in basis points
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

    enum PricingType { 
        Conservative,    // Slow, steady adjustments
        Balanced,       // Moderate adjustments
        Aggressive,     // Fast market reaction
        Momentum,       // Follow trends strongly
        Contrarian,     // Counter-trend strategy
        ValueBased,     // Fundamental analysis focus
        Technical       // Chart pattern focus
    }

    // ========== Previous Structs (Condensed) ==========
    
    struct Vector3 {
        int256 x;
        int256 y;
        int256 z;
    }

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
        uint256 lastInteraction;
        bool isPublic;
        uint256 visitCount;
        mapping(address => bool) authorizedUsers;
    }

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

    struct MusicNFT {
        uint256 musicId;
        uint256 tokenId;
        string trackName;
        string artist;
        string album;
        uint256 duration;
        string genre;
        uint256 bpm;
        string key;
        uint256 totalStreams;
        bool isRemixable;
        uint256[] remixTokenIds;
        mapping(address => bool) collaborators;
    }

    struct CarbonOffset {
        uint256 carbonId;
        uint256 tokenId;
        uint256 carbonFootprint;
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
        // NEW: Dynamic pricing integration
        bool hasDynamicPricing;
        uint256 aiPricingId;
    }

    enum PaymentMethod { ETH, ERC20, Crypto, Fiat }
    enum ProposalType { FeeChange, CategoryAdd, FeatureToggle, Emergency, ParameterChange }

    // ========== Enhanced Mappings ==========
    mapping(uint256 => MarketItem) private idToMarketItem;
    mapping(uint256 => Collection) private idToCollection;
    mapping(uint256 => MetaverseItem) private idToMetaverseItem;
    mapping(uint256 => DAOGovernance) private idToDAO;
    mapping(uint256 => MusicNFT) private idToMusicNFT;
    mapping(uint256 => CarbonOffset) private idToCarbonOffset;

    // NEW: Dynamic Pricing Mappings
    mapping(uint256 => DynamicPricing) private idToDynamicPricing;
    mapping(uint256 => AIMarketAnalysis) private idToMarketAnalysis;
    mapping(address => bool) private authorizedAIOracles;
    mapping(uint256 => mapping(uint256 => uint256)) private tokenPriceByHour; // tokenId => hour => price
    mapping(string => uint256) private categoryMarketTrends;
    mapping(address => uint256) private collectionMarketScores;

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
    mapping(address => DAOMember) private daoMembers;
    mapping(address => uint256[]) private userMetaverseItems;
    mapping(string => bool) private supportedMetaversePlatforms;
    mapping(address => uint256) private carbonContributions;

    // NEW: Dynamic Pricing Configuration
    address public aiPricingOracle;
    bool public globalPricingEnabled;
    uint256 public marketSentimentWeight;
    uint256 public rarityWeight;
    uint256 public volumeWeight;
    uint256 public socialWeight;
    uint256 public utilityWeight;
    uint256 public lastGlobalMarketUpdate;

    // Configuration
    uint256 public actionCooldown = 1 seconds;
    bool public aiRecommendationsEnabled = true;
    bool public socialTradingEnabled = true;
    bool public gamificationEnabled = true;
    bool public metaverseEnabled = true;
    bool public daoEnabled = true;
    bool public carbonOffsetEnabled = true;
    bool public crossChainEnabled = true;

    // Platform fee balance
    uint256 private platformFeeBalance;

    // ========== NEW: Dynamic Pricing AI Events ==========
    event DynamicPricingEnabled(uint256 indexed tokenId, uint256 basePrice, PricingType strategy);
    event AIPriceUpdated(uint256 indexed tokenId, uint256 oldPrice, uint256 newPrice, uint256 confidence, string reason);
    event PricingStrategyChanged(uint256 indexed tokenId, PricingType oldStrategy, PricingType newStrategy);
    event MarketAnalysisUpdated(uint256 indexed analysisId, uint256 overallSentiment, uint256 timestamp);
    event EmergencyPricingStop(uint256 indexed tokenId, address indexed stopper, string reason);
    event PricingOracleUpdated(address indexed oldOracle, address indexed newOracle);
    event AIPricingConfigured(uint256 tokenId, AutoPricingRules rules);

    // Previous events
    event MetaverseItemCreated(uint256 indexed metaverseId, uint256 indexed tokenId, string worldId);
    event MetaverseAccessed(uint256 indexed tokenId, address indexed user, uint256 duration);
    event DAOCreated(uint256 indexed daoId, string name, address creator);
    event DAOMemberJoined(uint256 indexed daoId, address indexed member, DAOMemberTier tier);
    event DAOProposalCreated(uint256 indexed daoId, uint256 indexed proposalId, string title);
    event DAOVoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event MusicNFTCreated(uint256 indexed musicId, uint256 indexed tokenId, string trackName, string artist);
    event MusicStreamed(uint256 indexed tokenId, address indexed listener, uint256 streamCount);
    event CarbonOffsetPurchased(uint256 indexed carbonId, uint256 indexed tokenId, uint256 offsetAmount);
    event MarketItemCreated(uint256 indexed tokenId, address seller, address owner, uint256 price, bool sold, string category);
    event MarketItemSold(uint256 indexed tokenId, address seller, address buyer, uint256 price, address indexed referrer);

    // ========== NEW: Dynamic Pricing AI Functions ==========
    
    /**
     * @dev Enable dynamic pricing for a token with AI-powered price adjustments
     */
    function enableDynamicPricing(
        uint256 tokenId,
        uint256 basePrice,
        PricingType strategy,
        AutoPricingRules memory rules
    ) external onlyTokenOwner(tokenId) nonReentrant returns (uint256) {
        require(globalPricingEnabled, "Dynamic pricing disabled globally");
        require(!idToDynamicPricing[tokenId].isActive, "Dynamic pricing already enabled");
        require(basePrice > 0, "Base price must be positive");
        
        _aiPricingIds.increment();
        uint256 aiPricingId = _aiPricingIds.current();
        
        DynamicPricing storage pricing = idToDynamicPricing[tokenId];
        pricing.aiPricingId = aiPricingId;
        pricing.tokenId = tokenId;
        pricing.basePrice = basePrice;
        pricing.currentAIPrice = basePrice;
        pricing.lastUpdateTime = block.timestamp;
        pricing.priceConfidence = 5000; // 50% initial confidence
        pricing.isActive = true;
        pricing.ownerOptedIn = true;
        pricing.totalUpdates = 0;
        pricing.accuracyScore = 0;
        pricing.rules = rules;
        
        // Set pricing strategy
        pricing.strategy.pricingType = strategy;
        pricing.strategy.targetVolatility = _getTargetVolatilityForStrategy(strategy);
        pricing.strategy.responsiveness = _getResponsivenessForStrategy(strategy);
        pricing.strategy.trendFollowing = _getTrendFollowingForStrategy(strategy);
        pricing.strategy.enableFloorProtection = true;
        pricing.strategy.floorPriceMultiplier = 8000; // 80% of floor price
        pricing.strategy.enableCeilingCap = true;
        pricing.strategy.ceilingPriceMultiplier = 15000; // 150% of ceiling price
        
        // Initialize market factors
        _initializeMarketFactors(tokenId);
        
        // Update market item
        idToMarketItem[tokenId].hasDynamicPricing = true;
        idToMarketItem[tokenId].aiPricingId = aiPricingId;
        idToMarketItem[tokenId].price = basePrice;
        
        emit DynamicPricingEnabled(tokenId, basePrice, strategy);
        return aiPricingId;
    }
    
    /**
     * @dev Update AI-calculated price for a token
     */
    function updateAIPrice(
        uint256 tokenId,
        uint256 newPrice,
        uint256 confidence,
        string memory reason,
        bytes memory signature
    ) external onlyAIPricingOracle validPricingUpdate(tokenId, newPrice, confidence) nonReentrant {
        DynamicPricing storage pricing = idToDynamicPricing[tokenId];
        require(pricing.isActive, "Dynamic pricing not active");
        require(block.timestamp >= pricing.lastUpdateTime + AI_PRICING_UPDATE_INTERVAL, "Update too frequent");
        
        // Verify signature for price update (EIP-712)
        bytes32 hash = _hashTypedDataV4(keccak256(abi.encode(
            _AI_PRICING_TYPEHASH,
            tokenId,
            newPrice,
            confidence,
            block.timestamp,
            userNonce[msg.sender]++
        )));
        require(hash.recover(signature) == aiPricingOracle, "Invalid signature");
        
        uint256 oldPrice = pricing.currentAIPrice;
        
        // Apply pricing rules and constraints
        uint256 constrainedPrice = _applyPricingConstraints(tokenId, newPrice, confidence);
        
        // Update pricing data
        pricing.currentAIPrice = constrainedPrice;
        pricing.priceConfidence = confidence;
        pricing.lastUpdateTime = block.timestamp;
        pricing.totalUpdates++;
        
        // Add to price history
        pricing.priceHistory.push(PriceHistory({
            timestamp: block.timestamp,
            price: constrainedPrice,
            confidence: confidence,
            reason: reason,
            marketVolume: _getCurrentMarketVolume(),
            gasPrice: tx.gasprice
        }));
        
        // Update market item price
        idToMarketItem[tokenId].price = constrainedPrice;
        
        // Store hourly price data for analysis
        uint256 currentHour = block.timestamp / 3600;
        tokenPriceByHour[tokenId][currentHour] = constrainedPrice;
        
        // Update accuracy score if enough history
        if (pricing.totalUpdates > 10) {
            _updateAccuracyScore(tokenId);
        }
        
        emit AIPriceUpdated(tokenId, oldPrice, constrainedPrice, confidence, reason);
    }
    
    /**
     * @dev Perform comprehensive market analysis and update global trends
     */
    function performMarketAnalysis() external onlyAIPricingOracle returns (uint256) {
        require(block.timestamp >= lastGlobalMarketUpdate + 1 hours, "Analysis too frequent");
        
        _analyticsIds.increment();
        uint256 analysisId = _analyticsIds.current();
        
        AIMarketAnalysis storage analysis = idToMarketAnalysis[analysisId];
        analysis.analysisId = analysisId;
        analysis.timestamp = block.timestamp;
        
        // Calculate overall market sentiment
        analysis.overallMarketSentiment = _calculateOverallMarketSentiment();
        analysis.nftMarketTrend = _calculateNFTMarketTrend();
        analysis.predictedVolatility = _calculatePredictedVolatility();
        
        // Update category trends
        _updateCategoryTrends(analysisId);
        
        // Update collection trends
        _updateCollectionTrends(analysisId);
        
        // Generate market predictions
        _generateMarketPredictions(analysisId);
        
        lastGlobalMarketUpdate = block.timestamp;
        
        emit MarketAnalysisUpdated(analysisId, analysis.overallMarketSentiment, block.timestamp);
        return analysisId;
    }
    
    /**
     * @dev Change pricing strategy for a token
     */
    function changePricingStrategy(
        uint256 tokenId,
        PricingType newStrategy
    ) external onlyTokenOwner(tokenId) {
        DynamicPricing storage pricing = idToDynamicPricing[tokenId];
        require(pricing.isActive, "Dynamic pricing not active");
        
        PricingType oldStrategy = pricing.strategy.pricingType;
        pricing.strategy.pricingType = newStrategy;
        pricing.strategy.targetVolatility = _getTargetVolatilityForStrategy(newStrategy);
        pricing.strategy.responsiveness = _getResponsivenessForStrategy(newStrategy);
        pricing.strategy.trendFollowing = _getTrendFollowingForStrategy(newStrategy);
        
        emit PricingStrategyChanged(tokenId, oldStrategy, newStrategy);
    }
    
    /**
     * @dev Emergency stop for dynamic pricing
     */
    function emergencyStopPricing(uint256 tokenId, string memory reason) external nonReentrant {
        DynamicPricing storage pricing = idToDynamicPricing[tokenId];
        require(pricing.isActive, "Dynamic pricing not active");
        
        bool canStop = false;
        
        // Check if caller is authorized
        if (msg.sender == ownerOf(tokenId) || msg.sender == owner() || msg.sender == aiPricingOracle || authorizedAIOracles[msg.sender]) {
            canStop = true;
        } else {
            // Check if caller is in emergency stoppers list
            for (uint256 i = 0; i < pricing.rules.emergencyStoppers.length; i++) {
                if (pricing.rules.emergencyStoppers[i] == msg.sender) {
                    canStop = true;
                    break;
                }
            }
        }
        
        require(canStop, "Not authorized for emergency stop");
        
        pricing.isActive = false;
        // Optionally freeze current price on market item
        idToMarketItem[tokenId].hasDynamicPricing = false;
        
        emit EmergencyPricingStop(tokenId, msg.sender, reason);
    }

    // ========== NEW ADMIN / ORACLE MANAGEMENT ==========
    function setAIPricingOracle(address newOracle) external onlyOwner {
        require(newOracle != address(0), "Zero address");
        address old = aiPricingOracle;
        aiPricingOracle = newOracle;
        authorizedAIOracles[newOracle] = true;
        emit PricingOracleUpdated(old, newOracle);
    }

    function authorizeAIPricer(address who) external onlyOwner {
        authorizedAIOracles[who] = true;
    }

    function revokeAIPricer(address who) external onlyOwner {
        authorizedAIOracles[who] = false;
    }

    function toggleGlobalPricing(bool enabled) external onlyOwner {
        globalPricingEnabled = enabled;
    }

    /**
     * @dev Owner (token owner) can opt-out dynamic pricing and disable AI control over their token.
     */
    function ownerOptOutDynamicPricing(uint256 tokenId) external onlyTokenOwner(tokenId) {
        DynamicPricing storage pricing = idToDynamicPricing[tokenId];
        require(pricing.isActive, "Not active");
        pricing.isActive = false;
        pricing.ownerOptedIn = false;
        idToMarketItem[tokenId].hasDynamicPricing = false;
    }

    /**
     * @dev Configure global weighting (e.g., weights used in internal scoring).
     * values are basis points (sum should be <= 10000 but check isn't enforced here)
     */
    function configureGlobalWeights(uint256 _marketSentimentWeight, uint256 _rarityWeight, uint256 _volumeWeight, uint256 _socialWeight, uint256 _utilityWeight) external onlyOwner {
        marketSentimentWeight = _marketSentimentWeight;
        rarityWeight = _rarityWeight;
        volumeWeight = _volumeWeight;
        socialWeight = _socialWeight;
        utilityWeight = _utilityWeight;
    }

    /**
     * @dev Withdraw platform fees collected by the contract
     */
    function withdrawPlatformFees(address payable to) external onlyOwner nonReentrant {
        require(to != address(0), "Zero addr");
        uint256 amount = platformFeeBalance;
        require(amount > 0, "No balance");
        platformFeeBalance = 0;
        (bool sent, ) = to.call{value: amount}("");
        require(sent, "Withdraw failed");
    }

    // ========== GETTERS ==========
    function getCurrentAIPrice(uint256 tokenId) external view returns (uint256 price, uint256 confidence, bool active) {
        DynamicPricing storage pricing = idToDynamicPricing[tokenId];
        return (pricing.currentAIPrice, pricing.priceConfidence, pricing.isActive);
    }

    /**
     * @dev Return price history arrays for a token's dynamic pricing
     */
    function getPriceHistory(uint256 tokenId) external view returns (uint256[] memory timestamps, uint256[] memory prices, uint256[] memory confidences, string[] memory reasons) {
        DynamicPricing storage pricing = idToDynamicPricing[tokenId];
        uint256 len = pricing.priceHistory.length;
        timestamps = new uint256[](len);
        prices = new uint256[](len);
        confidences = new uint256[](len);
        reasons = new string[](len);

        for (uint256 i = 0; i < len; i++) {
            PriceHistory storage p = pricing.priceHistory[i];
            timestamps[i] = p.timestamp;
            prices[i] = p.price;
            confidences[i] = p.confidence;
            reasons[i] = p.reason;
        }
        return (timestamps, prices, confidences, reasons);
    }

    function getDynamicPricingInfo(uint256 tokenId) external view returns (
        uint256 aiPricingId,
        uint256 basePrice,
        uint256 currentAIPrice,
        uint256 lastUpdateTime,
        uint256 priceConfidence,
        bool isActive,
        bool ownerOptedIn,
        uint256 totalUpdates,
        uint256 accuracyScore
    ) {
        DynamicPricing storage pricing = idToDynamicPricing[tokenId];
        return (
            pricing.aiPricingId,
            pricing.basePrice,
            pricing.currentAIPrice,
            pricing.lastUpdateTime,
            pricing.priceConfidence,
            pricing.isActive,
            pricing.ownerOptedIn,
            pricing.totalUpdates,
            pricing.accuracyScore
        );
    }

    // ========== INTERNAL / SIMPLE HELPERS (placeholders you can extend) ==========
    function _applyPricingConstraints(uint256 tokenId, uint256 requestedPrice, uint256 confidence) internal view returns (uint256) {
        DynamicPricing storage pricing = idToDynamicPricing[tokenId];
        uint256 result = requestedPrice;

        // ensure confidence threshold
        if (confidence < PRICING_CONFIDENCE_THRESHOLD) {
            // Should be prevented by modifier, but safe-guard
            revert("confidence too low");
        }

        // clamp change relative to current price if active
        if (pricing.isActive && pricing.currentAIPrice > 0) {
            uint256 current = pricing.currentAIPrice;
            uint256 maxChange = (current * MAX_PRICE_CHANGE_PER_UPDATE) / 10000;
            if (result > current + maxChange) {
                result = current + maxChange;
            }
            if (result < current && current - result > maxChange) {
                result = current - maxChange;
            }
        }

        // minimal positive
        if (result == 0) {
            result = 1;
        }

        return result;
    }

    function _initializeMarketFactors(uint256 /* tokenId */) internal {
        // Placeholder: in production, fetch collection floor, volume, social etc.
        // For now do nothing.
    }

    function _getTargetVolatilityForStrategy(PricingType strategy) internal pure returns (uint256) {
        if (strategy == PricingType.Conservative) return 500; // 5%
        if (strategy == PricingType.Balanced) return 1000; // 10%
        if (strategy == PricingType.Aggressive) return 2000; // 20%
        if (strategy == PricingType.Momentum) return 1500;
        if (strategy == PricingType.Contrarian) return 1200;
        if (strategy == PricingType.ValueBased) return 800;
        return 1000;
    }

    function _getResponsivenessForStrategy(PricingType strategy) internal pure returns (uint256) {
        if (strategy == PricingType.Conservative) return 10;
        if (strategy == PricingType.Balanced) return 50;
        if (strategy == PricingType.Aggressive) return 90;
        if (strategy == PricingType.Momentum) return 80;
        if (strategy == PricingType.Contrarian) return 60;
        if (strategy == PricingType.ValueBased) return 30;
        return 50;
    }

    function _getTrendFollowingForStrategy(PricingType strategy) internal pure returns (uint256) {
        if (strategy == PricingType.Momentum) return 90;
        if (strategy == PricingType.Aggressive) return 70;
        if (strategy == PricingType.Balanced) return 50;
        return 20;
    }

    function _getCurrentMarketVolume() internal pure returns (uint256) {
        // Placeholder: replace with real market volume source
        return 0;
    }

    function _updateAccuracyScore(uint256 tokenId) internal {
        DynamicPricing storage pricing = idToDynamicPricing[tokenId];
        // Placeholder: basic increment proportional to updates
        pricing.accuracyScore = pricing.totalUpdates; // simplistic
    }

    function _calculateOverallMarketSentiment() internal view returns (uint256) {
        // Placeholder: basic neutral sentiment
        return 5000;
    }

    function _calculateNFTMarketTrend() internal view returns (uint256) {
        return 5000;
    }

    function _calculatePredictedVolatility() internal view returns (uint256) {
        return 1000;
    }

    function _updateCategoryTrends(uint256 /* analysisId */) internal {
        // Placeholder
    }

    function _updateCollectionTrends(uint256 /* analysisId */) internal {
        // Placeholder
    }

    function _generateMarketPredictions(uint256 /* analysisId */) internal {
        // Placeholder
    }

    // ========== OVERRIDES / SAFETY ==========
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721) whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    // Receive ETH (marketplace fees etc)
    receive() external payable {
        platformFeeBalance += msg.value;
    }

    fallback() external payable {
        platformFeeBalance += msg.value;
    }

    // Example mint (very simple) - callers should implement proper minting, royalties, etc.
    function simpleMint(string memory tokenURI) external returns (uint256) {
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        _safeMint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, tokenURI);
        // Setup default MarketItem
        idToMarketItem[newTokenId] = MarketItem({
            tokenId: newTokenId,
            seller: payable(msg.sender),
            owner: payable(msg.sender),
            creator: payable(msg.sender),
            price: 0,
            createdAt: block.timestamp,
            expiresAt: 0,
            sold: false,
            isAuction: false,
            category: "",
            collectionId: 0,
            views: 0,
            likes: 0,
            isExclusive: false,
            unlockableContentHash: 0,
            collaborators: new address,
            collaboratorShares: new uint256,
            isLazyMinted: false,
            editionNumber: 0,
            totalEditions: 0,
            acceptsOffers: false,
            minOffer: 0,
            isMetaverseEnabled: false,
            isAIGenerated: false,
            hasCarbonOffset: false,
            isMusicNFT: false,
            isRealEstate: false,
            isFractional: false,
            utilityScore: 0,
            hasDynamicPricing: false,
            aiPricingId: 0
        });
        return newTokenId;
    }

    // A simple helper to mark a creator as verified (owner only)
    function setVerifiedCreator(address creator, bool verified) external onlyOwner {
        verifiedCreators[creator] = verified;
    }

    // Pause / unpause
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // Example emergency setter for platform fee (owner)
    function setPlatformFee(uint256 feeBasisPoints) external onlyOwner {
        platformFee = feeBasisPoints;
    }

    // Helper: allow token owner to enable an authorized updater for their token's dynamic pricing
    function authorizeUpdaterForToken(uint256 tokenId, address updater) external onlyTokenOwner(tokenId) {
        DynamicPricing storage pricing = idToDynamicPricing[tokenId];
        pricing.authorizedUpdaters[updater] = true;
    }

    function revokeUpdaterForToken(uint256 tokenId, address updater) external onlyTokenOwner(tokenId) {
        DynamicPricing storage pricing = idToDynamicPricing[tokenId];
        pricing.authorizedUpdaters[updater] = false;
    }

    // Safety: check if address is authorized for given token (used externally if needed)
    function isAuthorizedUpdater(uint256 tokenId, address who) external view returns (bool) {
        DynamicPricing storage pricing = idToDynamicPricing[tokenId];
        return pricing.authorizedUpdaters[who];
    }
}
