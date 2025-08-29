// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// OpenZeppelin
// ────────────────────────────────────────────────────────────────────────────── 
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

// ────────────────────────────────────────────────────────────────────────────── 
// Enhanced NFT Marketplace with Advanced Features
// ────────────────────────────────────────────────────────────────────────────── 
contract NFTMarketplace is ERC721URIStorage, ERC2981, ReentrancyGuard, Ownable, Pausable, EIP712 {
    using Counters for Counters.Counter;
    using ECDSA for bytes32;

    // ========== COUNTERS ==========
    Counters.Counter private _tokenIds;
    Counters.Counter private _itemsSold;
    Counters.Counter private _collectionIds;
    Counters.Counter private _virtualGalleryIds;
    Counters.Counter private _aiArtIds;
    Counters.Counter private _subscriptionTierIds;
    Counters.Counter private _loyaltyProgramIds;
    Counters.Counter private _crossChainIds;
    Counters.Counter private _gameAssetIds;
    Counters.Counter private _aiPricingIds;
    Counters.Counter private _analyticsIds;
    Counters.Counter private _fractionalTokenIds;
    Counters.Counter private _stakingPoolIds;
    Counters.Counter private _socialTokenIds;
    Counters.Counter private _communityIds;
    Counters.Counter private _proposalIds;
    Counters.Counter private _rentalIds;
    Counters.Counter private _bundleIds;
    Counters.Counter private _insurancePolicyIds;
    Counters.Counter private _escrowIds;
    Counters.Counter private _evolutionIds;
    Counters.Counter private _weatherSystemIds;
    Counters.Counter private _questIds;
    Counters.Counter private _achievementIds;
    Counters.Counter private _subscriptionBoxIds;
    Counters.Counter private _lootboxIds;
    // NEW: Additional counters for new features
    Counters.Counter private _aiCuratorIds;
    Counters.Counter private _carbonCreditIds;
    Counters.Counter private _virtualEventIds;
    Counters.Counter private _timeCapIds;
    Counters.Counter private _metaverseAssetIds;
    Counters.Counter private _predictiveTokenIds;
    Counters.Counter private _daoProposalIds;
    Counters.Counter private _crossPlatformIds;
    Counters.Counter private _aiPersonalityIds;
    Counters.Counter private _dreamSequenceIds;

    // ========== CONSTANTS ==========
    uint256 public listingPrice = 0.025 ether;
    uint256 public platformFee = 250; // 2.5% (basis points)
    uint256 public constant MAX_PLATFORM_FEE = 1000; // 10%
    uint256 public constant MAX_ROYALTY = 1000; // 10%
    uint256 public constant VIRTUAL_GALLERY_FEE = 0.005 ether;
    uint256 public constant AI_GENERATION_FEE = 0.02 ether;
    uint256 public constant PREMIUM_SUBSCRIPTION_FEE = 0.1 ether;
    uint256 public constant CROSS_CHAIN_FEE = 0.01 ether;
    uint256 public constant MAX_AI_GENERATIONS_PER_DAY = 10;
    uint256 public constant LOYALTY_TIER_UPGRADE_THRESHOLD = 1000;
    uint256 public constant SUBSCRIPTION_DURATION = 30 days;
    uint256 public constant FRACTIONAL_CREATION_FEE = 0.01 ether;
    uint256 public constant STAKING_POOL_CREATION_FEE = 0.05 ether;
    uint256 public constant MIN_STAKING_DURATION = 7 days;
    uint256 public constant MAX_STAKING_DURATION = 365 days;
    uint256 public constant AI_PRICING_UPDATE_INTERVAL = 1 hours;
    uint256 public constant MIN_PRICE_CHANGE_THRESHOLD = 50;
    uint256 public constant MAX_PRICE_CHANGE_PER_UPDATE = 2000;
    uint256 public constant PRICING_CONFIDENCE_THRESHOLD = 7000;
    uint256 public constant MIN_AUCTION_DURATION = 1 hours;
    uint256 public constant AUCTION_TIME_EXTENSION = 10 minutes;
    uint256 public constant COMMUNITY_CREATION_FEE = 0.02 ether;
    uint256 public constant MIN_PROPOSAL_THRESHOLD = 100; // 1%
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant EXECUTION_DELAY = 2 days;
    uint256 public constant MIN_RENTAL_DURATION = 1 hours;
    uint256 public constant MAX_RENTAL_DURATION = 30 days;
    uint256 public constant RENTAL_FEE = 50; // 0.5% platform fee on rentals
    uint256 public constant INSURANCE_PREMIUM_RATE = 200; // 2% annual rate
    uint256 public constant BUNDLE_CREATION_FEE = 0.01 ether;
    uint256 public constant WEATHER_UPDATE_INTERVAL = 6 hours;
    uint256 public constant QUEST_CREATION_FEE = 0.005 ether;
    uint256 public constant LOOTBOX_MIN_ITEMS = 3;
    uint256 public constant LOOTBOX_MAX_ITEMS = 10;
    
    // NEW: Additional constants for new features
    uint256 public constant AI_CURATOR_FEE = 0.015 ether;
    uint256 public constant CARBON_CREDIT_FEE = 0.002 ether;
    uint256 public constant VIRTUAL_EVENT_FEE = 0.05 ether;
    uint256 public constant TIME_CAPSULE_FEE = 0.01 ether;
    uint256 public constant METAVERSE_ASSET_FEE = 0.03 ether;
    uint256 public constant PREDICTIVE_ANALYSIS_FEE = 0.025 ether;
    uint256 public constant DAO_PROPOSAL_FEE = 0.01 ether;
    uint256 public constant CROSS_PLATFORM_SYNC_FEE = 0.008 ether;
    uint256 public constant AI_PERSONALITY_FEE = 0.02 ether;
    uint256 public constant DREAM_SEQUENCE_FEE = 0.035 ether;
    uint256 public constant MIN_TIME_CAPSULE_DURATION = 30 days;
    uint256 public constant MAX_TIME_CAPSULE_DURATION = 10 * 365 days; // 10 years
    uint256 public constant PREDICTIVE_ACCURACY_THRESHOLD = 8000; // 80%
    uint256 public constant MAX_DREAM_LAYERS = 5;
    uint256 public constant VIRTUAL_EVENT_MIN_DURATION = 30 minutes;
    uint256 public constant VIRTUAL_EVENT_MAX_DURATION = 7 days;

    // ========== ENUMS ==========
    enum PricingType { Conservative, Balanced, Aggressive, Momentum, Contrarian, ValueBased, Technical }
    enum PaymentMethod { ETH, ERC20 }
    enum BridgeStatus { Pending, InProgress, Completed, Failed, Cancelled }
    enum GalleryTheme { Modern, Classic, Cyberpunk, Nature, Abstract }
    enum SubscriptionTierLevel { Basic, Premium, Professional, Enterprise }
    enum FractionalStatus { Active, Buyout, Dissolved }
    enum StakingPoolType { FlexibleReward, FixedAPY, LiquidityMining, GovernanceStaking }
    enum ProposalStatus { Active, Passed, Failed, Executed, Cancelled }
    enum ReputationLevel { Newcomer, Bronze, Silver, Gold, Platinum, Diamond }
    enum RentalStatus { Active, Completed, Cancelled, Defaulted }
    enum InsuranceStatus { Active, Claimed, Expired, Cancelled }
    enum WeatherCondition { Sunny, Rainy, Stormy, Snowy, Foggy, Windy }
    enum QuestStatus { Active, Completed, Failed, Expired }
    enum QuestDifficulty { Easy, Medium, Hard, Legendary }
    enum LootboxRarity { Common, Uncommon, Rare, Epic, Legendary, Mythic }
    enum EvolutionTrigger { TimeExpired, ActivityMilestone, WeatherCondition, CommunityEvent, PriceThreshold }
    
    // NEW: Additional Enums for new features
    enum AICuratorStyle { Minimalist, Maximalist, Thematic, Emotional, Analytical, Experimental }
    enum CarbonCreditType { Renewable, ForestConservation, TechInnovation, CarbonCapture }
    enum VirtualEventType { Exhibition, Concert, Conference, Auction, GameTournament, SocialGathering }
    enum TimeCapsuleStatus { Sealed, Unlocked, Expired, Transferring }
    enum MetaverseAssetType { Land, Building, Vehicle, Wearable, Furniture, Experience }
    enum PredictiveModelType { PriceTrend, PopularityForecast, MarketSentiment, CollectionSuccess }
    enum DAOGovernanceType { Democratic, Weighted, Delegated, Quadratic }
    enum CrossPlatformType { Social, Gaming, Metaverse, DeFi, RealWorld }
    enum AIPersonalityType { Friendly, Professional, Quirky, Mysterious, Wise, Playful }
    enum DreamLayerType { Memory, Imagination, Future, Abstract, Emotion }

    // ========== STRUCTS ==========
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
        bytes32 unlockableContentHash;
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
        bool isGameAsset;
        uint256 gameAssetId;
        bool isInVirtualGallery;
        uint256[] galleryIds;
        bool crossChainEnabled;
        uint256[] supportedChainIds;
        PaymentMethod payWith;
        address erc20;
        bool isStaked;
        uint256 stakingPoolId;
        uint256 reputationScore;
        bool hasUnlockableContent;
        bool isRentable;
        uint256 rentalPricePerHour;
        bool hasInsurance;
        uint256 insurancePolicyId;
        bool isEvolutionary;
        uint256 evolutionId;
        bool isWeatherSensitive;
        uint256 currentWeatherModifier;
        bool isQuestItem;
        uint256[] associatedQuests;
        bool isSubscriptionBox;
        uint256 subscriptionBoxId;
        bool canBeLootboxItem;
        LootboxRarity lootboxRarity;
        // NEW: Additional fields for new features
        bool hasAICurator;
        uint256 aiCuratorId;
        bool hasCarbonCredits;
        uint256 carbonCreditId;
        bool isVirtualEventTicket;
        uint256 virtualEventId;
        bool isTimeCapsule;
        uint256 timeCapsuleId;
        bool isMetaverseAsset;
        uint256 metaverseAssetId;
        bool hasPredictiveAnalysis;
        uint256 predictiveTokenId;
        bool isDAOGoverned;
        uint256 daoProposalId;
        bool crossPlatformSynced;
        uint256 crossPlatformId;
        bool hasAIPersonality;
        uint256 aiPersonalityId;
        bool isDreamSequence;
        uint256 dreamSequenceId;
    }

    // NEW: Advanced AI Curator System
    struct AICurator {
        uint256 curatorId;
        string name;
        string description;
        AICuratorStyle style;
        address owner;
        uint256 curatedCollections;
        uint256 successRate; // Basis points
        uint256 totalCurations;
        bool isActive;
        string aiModelVersion;
        uint256[] preferredCategories;
        uint256 learningDataPoints;
        mapping(string => uint256) stylePreferences;
        mapping(address => bool) trustedCollectors;
        uint256 reputationScore;
        uint256 lastUpdateTime;
    }

    // NEW: Carbon Credit Integration
    struct CarbonCredit {
        uint256 creditId;
        uint256 tokenId;
        CarbonCreditType creditType;
        uint256 carbonOffset; // In kg CO2
        string verificationHash;
        address certifier;
        uint256 issuedAt;
        uint256 expiresAt;
        bool isRetired;
        string projectDetails;
        uint256 pricePerTon;
        bool isTransferable;
    }

    // NEW: Virtual Events System
    struct VirtualEvent {
        uint256 eventId;
        string name;
        string description;
        VirtualEventType eventType;
        address organizer;
        uint256 startTime;
        uint256 duration;
        uint256 maxAttendees;
        uint256 currentAttendees;
        uint256 ticketPrice;
        string metaverseLocation;
        bool requiresNFT; // Gate-token requirement
        uint256[] gatingTokenIds;
        mapping(address => bool) attendees;
        mapping(address => bool) vipAccess;
        bool isActive;
        bool isRecorded;
        string recordingURI;
        uint256[] featuredNFTs;
        bool allowsNetworking;
    }

    // NEW: Time Capsule System
    struct TimeCapsule {
        uint256 capsuleId;
        uint256 tokenId;
        address creator;
        uint256 sealedAt;
        uint256 unlockTime;
        TimeCapsuleStatus status;
        string message;
        uint256[] encapsulatedTokenIds;
        bytes32 secretHash;
        address[] futureRecipients;
        uint256[] recipientShares;
        bool allowsEarlyUnlock;
        uint256 earlyUnlockFee;
        string timeContext; // Historical context when sealed
        uint256 inflationAdjustedValue;
    }

    // NEW: Advanced Metaverse Asset Integration
    struct MetaverseAsset {
        uint256 assetId;
        uint256 tokenId;
        MetaverseAssetType assetType;
        string[] supportedPlatforms;
        mapping(string => string) platformSpecificData;
        uint256 virtualLandSize; // For land assets
        string[] coordinates; // Virtual coordinates
        bool isInteractive;
        string[] functionalities;
        uint256 maintenanceCost;
        address[] authorizedUsers;
        bool isRentable;
        uint256 rentalYield; // Annual yield in basis points
        mapping(string => uint256) platformPopularity;
    }

    // NEW: Predictive NFT Analysis
    struct PredictiveToken {
        uint256 predictiveId;
        uint256 targetTokenId;
        PredictiveModelType modelType;
        uint256 predictionMadeAt;
        uint256 predictionPeriod; // Duration for prediction
        uint256 predictedValue;
        uint256 confidenceLevel; // Basis points
        address predictor;
        bool isResolved;
        uint256 actualOutcome;
        uint256 accuracyScore;
        string predictionRationale;
        uint256 stakingReward; // Reward for accurate predictions
        mapping(address => uint256) userPredictions;
        mapping(address => uint256) userStakes;
    }

    // NEW: Enhanced DAO Governance
    struct DAOProposal {
        uint256 proposalId;
        string title;
        string description;
        address proposer;
        DAOGovernanceType governanceType;
        uint256 startTime;
        uint256 endTime;
        uint256 executionDelay;
        uint256 quorum; // Minimum participation
        uint256 totalVotes;
        uint256 yesVotes;
        uint256 noVotes;
        mapping(address => uint256) votingPower;
        mapping(address => bool) hasVoted;
        bool isExecuted;
        bytes executionCallData;
        address targetContract;
        uint256 fundingRequired;
        bool isFunded;
    }

    // NEW: Cross-Platform Synchronization
    struct CrossPlatform {
        uint256 crossId;
        uint256 tokenId;
        CrossPlatformType platformType;
        string[] connectedPlatforms;
        mapping(string => string) platformIdentifiers;
        mapping(string => uint256) lastSyncTime;
        mapping(string => bool) syncEnabled;
        uint256 totalSyncs;
        bool autoSync;
        address[] authorizedSyncers;
        string masterPlatform; // Primary platform for conflicts
        mapping(string => bytes) platformSpecificMetadata;
    }

    // NEW: AI Personality Integration
    struct AIPersonality {
        uint256 personalityId;
        uint256 tokenId;
        AIPersonalityType personalityType;
        string name;
        string backstory;
        mapping(string => uint256) traits; // Trait name => intensity (0-100)
        mapping(string => string) responses; // Situation => Response
        uint256 learningProgress;
        bool canEvolve;
        uint256 interactionCount;
        mapping(address => uint256) userInteractions;
        string[] memories;
        uint256 emotionalState; // 0-100 scale
        bool isConversational;
        string voiceCharacteristics;
        mapping(string => bool) capabilities;
    }

    // NEW: Dream Sequence System (Surreal NFT experiences)
    struct DreamSequence {
        uint256 dreamId;
        uint256 tokenId;
        address dreamer;
        uint256 createdAt;
        DreamLayerType[] layers;
        mapping(uint256 => string) layerContent; // Layer index => Content URI
        mapping(uint256 => uint256) layerTransitions; // Layer => Next layer
        uint256 currentLayer;
        bool isRecurring;
        uint256 recurringInterval;
        uint256 maxLayers;
        bool allowsCollaboration;
        address[] collaborators;
        mapping(address => uint256) collaboratorContributions;
        string moodSetting;
        uint256 abstractionLevel; // 0-100
        bool isLucid; // Can be controlled by owner
    }

    // Additional existing structs (keeping previous ones)...
    struct Collection {
        uint256 collectionId;
        string name;
        string description;
        address creator;
        uint256 totalSupply;
        uint256 maxSupply;
        uint96 royaltyBps;
        address royaltyReceiver;
        bool isVerified;
        string logoURI;
        string bannerURI;
        uint256 floorPrice;
        uint256 totalVolume;
        bool isActive;
        uint256 communityId;
        bool hasGovernance;
        mapping(address => bool) moderators;
        bool hasEvolutionaryItems;
        bool isWeatherSensitive;
        bool supportsRentals;
        bool hasSubscriptionBoxes;
        // NEW: Additional fields
        bool hasAICuration;
        bool hasCarbonCredits;
        bool supportsVirtualEvents;
        bool allowsTimeCapsules;
        bool metaverseIntegrated;
        bool hasPredictiveAnalysis;
        bool daoGoverned;
        bool crossPlatformEnabled;
        bool hasAIPersonalities;
        bool supportsDreamSequences;
    }

    // Keep all existing structs for backward compatibility...
    struct VirtualGallery {
        uint256 galleryId;
        string name;
        string description;
        address owner;
        uint256 createdAt;
        uint256[] exhibitedTokenIds;
        GalleryTheme theme;
        bool isPublic;
        uint256 entryFee;
        uint256 totalVisits;
        bool isActive;
        string metaverseLocation;
        mapping(address => bool) curators;
        mapping(address => uint256) visitHistory;
        mapping(address => bool) vipAccess;
        bool isCollaborative;
        uint256 communityId;
        bool hasWeatherEffects;
        WeatherCondition currentWeather;
        uint256 lastWeatherUpdate;
        // NEW: Additional fields
        bool hasAICurator;
        uint256 aiCuratorId;
        bool hostsVirtualEvents;
        uint256[] scheduledEvents;
        bool supportsDreamSequences;
    }

    // ========== MAPPINGS ==========
    mapping(uint256 => MarketItem) private idToMarketItem;
    mapping(uint256 => Collection) private idToCollection;
    mapping(uint256 => VirtualGallery) private idToVirtualGallery;
    
    // NEW: Advanced feature mappings
    mapping(uint256 => AICurator) private idToAICurator;
    mapping(uint256 => CarbonCredit) private idToCarbonCredit;
    mapping(uint256 => VirtualEvent) private idToVirtualEvent;
    mapping(uint256 => TimeCapsule) private idToTimeCapsule;
    mapping(uint256 => MetaverseAsset) private idToMetaverseAsset;
    mapping(uint256 => PredictiveToken) private idToPredictiveToken;
    mapping(uint256 => DAOProposal) private idToDAOProposal;
    mapping(uint256 => CrossPlatform) private idToCrossPlatform;
    mapping(uint256 => AIPersonality) private idToAIPersonality;
    mapping(uint256 => DreamSequence) private idToDreamSequence;

    // User-specific mappings for new features
    mapping(address => uint256[]) private userAICurators;
    mapping(address => uint256[]) private userCarbonCredits;
    mapping(address => uint256[]) private userVirtualEvents;
    mapping(address => uint256[]) private userTimeCapsules;
    mapping(address => uint256[]) private userMetaverseAssets;
    mapping(address => uint256[]) private userPredictiveTokens;
    mapping(address => uint256[]) private userDAOProposals;
    mapping(address => uint256[]) private userCrossPlatforms;
    mapping(address => uint256[]) private userAIPersonalities;
    mapping(address => uint256[]) private userDreamSequences;

    // Global configuration for new features
    bool public aiCurationEnabled = true;
    bool public carbonCreditsEnabled = true;
    bool public virtualEventsEnabled = true;
    bool public timeCapsuleEnabled = true;
    bool public metaverseAssetsEnabled = true;
    bool public predictiveAnalysisEnabled = true;
    bool public daoGovernanceEnabled = true;
    bool public crossPlatformEnabled = true;
    bool public aiPersonalityEnabled = true;
    bool public dreamSequenceEnabled = true;

    // Keep existing mappings...
    mapping(address => bool) private verifiedCreators;
    mapping(string => bool) private validCategories;
    mapping(address => uint256) private creatorEarnings;
    mapping(address => uint256[]) private userTokens;
    mapping(address => bool) public allowedERC20;
    mapping(address => uint256) private userNonce;
    mapping(address => bool) private authorizedAIOracles;

    // Platform configuration
    address public aiPricingOracle;
    address public carbonCreditOracle;
    address public metaverseOracle;
    address public predictiveAnalysisOracle;
    uint256 private platformFeeBalance;

    // ========== EVENTS ==========
    // Existing events
    event MarketItemCreated(uint256 indexed tokenId, address seller, address owner, uint256 price, bool sold, string category);
    event MarketItemSold(uint256 indexed tokenId, address seller, address buyer, uint256 price, address indexed referrer);
    event ListingCancelled(uint256 indexed tokenId);
    
    // NEW: Advanced feature events
    event AICuratorCreated(uint256 indexed curatorId, string name, AICuratorStyle style, address owner);
    event AICurationCompleted(uint256 indexed curatorId, uint256 indexed tokenId, uint256 recommendation);
    event CarbonCreditIssued(uint256 indexed creditId, uint256 indexed tokenId, uint256 carbonOffset);
    event VirtualEventCreated(uint256 indexed eventId, string name, uint256 startTime, address organizer);
    event VirtualEventAttended(uint256 indexed eventId, address attendee, uint256 timestamp);
    event TimeCapsuleSealed(uint256 indexed capsuleId, uint256 indexed tokenId, uint256 unlockTime);
    event TimeCapsuleUnlocked(uint256 indexed capsuleId, uint256 indexed tokenId, address unlocker);
    event MetaverseAssetLinked(uint256 indexed assetId, uint256 indexed tokenId, string platform);
    event PredictionMade(uint256 indexed predictiveId, uint256 targetTokenId, uint256 predictedValue, address predictor);
    event PredictionResolved(uint256 indexed predictiveId, uint256 actualOutcome, uint256 accuracyScore);
    event DAOProposalCreated(uint256 indexed proposalId, string title, address proposer);
    event DAOVoteCast(uint256 indexed proposalId, address voter, uint256 votingPower, bool support);
    event CrossPlatformSynced(uint256 indexed crossId, uint256 indexed tokenId, string platform);
    event AIPersonalityCreated(uint256 indexed personalityId, uint256 indexed tokenId, string name);
    event AIInteraction(uint256 indexed personalityId, address user, string interactionType);
    event DreamSequenceStarted(uint256 indexed dreamId, uint256 indexed tokenId, address dreamer);
    event DreamLayerAdded(uint256 indexed dreamId, uint256 layerIndex, DreamLayerType layerType);

    // ========== CONSTRUCTOR ==========
    constructor() ERC721("NFTMarketplace", "NFTM") EIP712("NFTMarketplace", "1") {
        // Initialize default categories
        validCategories["Art"] = true;
        validCategories["Music"] = true;
        validCategories["Photography"] = true;
        validCategories["Gaming"] = true;
        validCategories["Utility"] = true;
        validCategories["Collectibles"] = true;
        validCategories["Metaverse"] = true;
        validCategories["AIGenerated"] = true;
        validCategories["DreamSequence"] = true;
        
        // Initialize first AI Curator as default
        _createDefaultAICurator();
        
        // Initialize global weather system
        _initializeGlobalWeatherSystem();
    }

    // ========== INTERNAL INITIALIZATION FUNCTIONS ==========
    function _createDefaultAICurator() internal {
        _aiCuratorIds.increment();
        uint256 newCuratorId = _aiCuratorIds.current();
        
        AICurator storage curator = idToAICurator[newCuratorId];
        curator.curatorId = newCuratorId;
        curator.name = "Genesis AI Curator";
        curator.description = "The original AI curator of the marketplace";
        curator.style = AICuratorStyle.Analytical;
        curator.owner = owner();
        curator.isActive = true;
        curator.aiModelVersion = "GPT-4.5-Art-v1";
        curator.reputationScore = 5000; // Start with neutral reputation
        curator.lastUpdateTime = block.timestamp;
        
        emit AICuratorCreated(newCuratorId, "Genesis AI Curator", AICuratorStyle.Analytical, owner());
    }

    function _initializeGlobalWeatherSystem() internal {
        _weatherSystemIds.increment();
        uint256 weatherSystemId = _weatherSystemIds.current();
        
        WeatherSystem storage weather = idToWeatherSystem[weatherSystemId];
        weather.systemId = weatherSystemId;
        weather.currentCondition = WeatherCondition.Sunny;
        weather.lastUpdate = block.timestamp;
        weather.temperature = 2200; // 22°C
        weather.humidity = 5000; // 50%
        weather.isGlobalSystem = true;
        
        // Set default weather modifiers (basis points)
        weather.conditionModifiers[WeatherCondition.Sunny] = 10000; // No change
        weather.conditionModifiers[WeatherCondition.Rainy] = 9500; // -5%
        weather.conditionModifiers[WeatherCondition.Stormy] = 8500; // -15%
        weather.conditionModifiers[WeatherCondition.Snowy] = 9000; // -10%
        weather.conditionModifiers[WeatherCondition.Foggy] = 9700; // -3%
        weather.conditionModifiers[WeatherCondition.Windy] = 10200; // +2%
    }

    // ========== NEW ADVANCED FEATURES ==========

    // AI Curator Functions
    function createAICurator(
        string memory _name,
        string memory _description,
        AICuratorStyle _style,
        uint256[] memory _preferredCategories
    ) external pay
