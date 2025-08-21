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
// Enhanced NFT Marketplace with New Features
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
    // NEW: Additional counters for new features
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

    // AI Pricing Constants
    uint256 public constant AI_PRICING_UPDATE_INTERVAL = 1 hours;
    uint256 public constant MIN_PRICE_CHANGE_THRESHOLD = 50;
    uint256 public constant MAX_PRICE_CHANGE_PER_UPDATE = 2000;
    uint256 public constant PRICING_CONFIDENCE_THRESHOLD = 7000;

    // Auction constants
    uint256 public constant MIN_AUCTION_DURATION = 1 hours;
    uint256 public constant AUCTION_TIME_EXTENSION = 10 minutes;

    // Social & Community Constants
    uint256 public constant COMMUNITY_CREATION_FEE = 0.02 ether;
    uint256 public constant MIN_PROPOSAL_THRESHOLD = 100; // 1%
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant EXECUTION_DELAY = 2 days;

    // NEW: Additional constants for new features
    uint256 public constant MIN_RENTAL_DURATION = 1 hours;
    uint256 public constant MAX_RENTAL_DURATION = 30 days;
    uint256 public constant RENTAL_FEE = 50; // 0.5% platform fee on rentals
    uint256 public constant INSURANCE_PREMIUM_RATE = 200; // 2% annual rate
    uint256 public constant BUNDLE_CREATION_FEE = 0.01 ether;
    uint256 public constant WEATHER_UPDATE_INTERVAL = 6 hours;
    uint256 public constant QUEST_CREATION_FEE = 0.005 ether;
    uint256 public constant LOOTBOX_MIN_ITEMS = 3;
    uint256 public constant LOOTBOX_MAX_ITEMS = 10;

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

    // NEW: Additional Enums
    enum RentalStatus { Active, Completed, Cancelled, Defaulted }
    enum InsuranceStatus { Active, Claimed, Expired, Cancelled }
    enum WeatherCondition { Sunny, Rainy, Stormy, Snowy, Foggy, Windy }
    enum QuestStatus { Active, Completed, Failed, Expired }
    enum QuestDifficulty { Easy, Medium, Hard, Legendary }
    enum LootboxRarity { Common, Uncommon, Rare, Epic, Legendary, Mythic }
    enum EvolutionTrigger { TimeExpired, ActivityMilestone, WeatherCondition, CommunityEvent, PriceThreshold }

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
        // NEW: Additional fields
        bool isRentable;
        uint256 rentalPricePerHour;
        bool hasInsurance;
        uint256 insurancePolicyId;
        bool isEvolutionary;
        uint256 evolutionId;
        bool isWeatherSensitive;
        uint256 currentWeatherModifier; // Basis points modifier
        bool isQuestItem;
        uint256[] associatedQuests;
        bool isSubscriptionBox;
        uint256 subscriptionBoxId;
        bool canBeLootboxItem;
        LootboxRarity lootboxRarity;
    }

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
        // NEW: Additional fields
        bool hasEvolutionaryItems;
        bool isWeatherSensitive;
        bool supportsRentals;
        bool hasSubscriptionBoxes;
    }

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
        // NEW: Additional fields
        bool hasWeatherEffects;
        WeatherCondition currentWeather;
        uint256 lastWeatherUpdate;
    }

    struct AIArtGeneration {
        uint256 aiArtId;
        address requester;
        string prompt;
        string style;
        uint256 requestedAt;
        uint256 completedAt;
        string resultURI;
        bool isCompleted;
        bool isMinted;
        uint256 generationCost;
        uint256 qualityScore;
        bool isPublic;
        bool isCollaborative;
        address[] collaborators;
        uint256[] collaboratorShares;
    }

    struct SubscriptionTier {
        uint256 tierId;
        string name;
        uint256 monthlyFee;
        SubscriptionTierLevel level;
        uint256 maxListings;
        uint256 maxAIGenerations;
        bool enablePrioritySupport;
        bool enableAnalytics;
        bool enableCustomGalleries;
        bool enableCrossChain;
        uint256 discountPercentage;
        bool isActive;
        bool enableFractional;
        bool enableStaking;
        bool enableGovernance;
        uint256 maxCommunities;
        // NEW: Additional fields
        bool enableRentals;
        bool enableInsurance;
        bool enableSubscriptionBoxes;
        bool enableLootboxes;
        uint256 maxQuestsCreated;
    }

    struct UserSubscription {
        uint256 tierId;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        bool autoRenew;
        uint256 totalSpent;
        SubscriptionTierLevel currentTier;
    }

    struct LoyaltyProgram {
        uint256 programId;
        string name;
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
        uint256 lifetimeSpent;
        uint256 referralCount;
        bool isActive;
        ReputationLevel reputation;
        uint256 reputationScore;
        uint256[] badges;
        // NEW: Additional fields
        uint256 questsCompleted;
        uint256 lootboxesOpened;
        uint256 evolutionsWitnessed;
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
    }

    struct GameAssetIntegration {
        uint256 assetId;
        uint256 tokenId;
        string gameId;
        string assetType;
        uint256 powerLevel;
        uint256 rarity;
        bool isTransferable;
        bool isUpgradeable;
        uint256 experiencePoints;
        string[] compatibleGames;
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
        uint256 totalUpdates;
        uint256 accuracyScore;
        PricingType pricingType;
        mapping(address => bool) authorizedUpdaters;
    }

    struct FractionalNFT {
        uint256 fractionalId;
        uint256 tokenId;
        address originalOwner;
        uint256 totalSupply;
        uint256 pricePerShare;
        uint256 buyoutPrice;
        FractionalStatus status;
        uint256 createdAt;
        address fractionalToken; // ERC20 representing shares
        mapping(address => uint256) shares;
        mapping(address => bool) hasVoted;
        uint256 totalVotes;
        uint256 votesForBuyout;
    }

    struct StakingPool {
        uint256 poolId;
        string name;
        address creator;
        StakingPoolType poolType;
        uint256[] allowedCollections; // 0 = all collections
        uint256 rewardRate; // APY in basis points
        uint256 minStakeDuration;
        uint256 maxStakeDuration;
        uint256 totalStaked;
        uint256 totalRewards;
        bool isActive;
        uint256 createdAt;
        address rewardToken; // ERC20 or native ETH (0x0)
    }

    struct StakeInfo {
        uint256 tokenId;
        address staker;
        uint256 poolId;
        uint256 stakedAt;
        uint256 unlockAt;
        uint256 rewardsClaimed;
        bool isActive;
    }

    struct SocialProfile {
        string username;
        string bio;
        string avatar;
        string[] socialLinks;
        uint256 followersCount;
        uint256 followingCount;
        uint256 reputation;
        bool isVerified;
        mapping(address => bool) followers;
        mapping(address => bool) following;
        uint256[] ownedTokens;
        uint256[] createdTokens;
    }

    struct Community {
        uint256 communityId;
        string name;
        string description;
        address creator;
        uint256 memberCount;
        uint256 createdAt;
        bool isPublic;
        uint256 entryFee;
        address governanceToken;
        mapping(address => bool) members;
        mapping(address => bool) moderators;
        uint256[] relatedCollections;
        bool hasGovernance;
    }

    struct Proposal {
        uint256 proposalId;
        uint256 communityId;
        address proposer;
        string title;
        string description;
        ProposalStatus status;
        uint256 votingStart;
        uint256 votingEnd;
        uint256 executionTime;
        uint256 forVotes;
        uint256 againstVotes;
        mapping(address => bool) hasVoted;
        mapping(address => bool) voteChoice; // true = for, false = against
        bytes executionData;
    }

    struct MarketAnalytics {
        uint256 totalVolume;
        uint256 totalSales;
        uint256 avgSalePrice;
        uint256 floorPrice;
        uint256 ceilingPrice;
        uint256 activeListings;
        uint256 uniqueOwners;
        uint256 priceChangePercent; // basis points
        uint256 lastUpdated;
        mapping(string => uint256) categoryVolumes;
        mapping(address => uint256) creatorVolumes;
    }

    // ========== NEW STRUCTS FOR ADDITIONAL FEATURES ==========

    // NFT Rental System
    struct NFTRental {
        uint256 rentalId;
        uint256 tokenId;
        address renter;
        address owner;
        uint256 pricePerHour;
        uint256 startTime;
        uint256 duration;
        uint256 totalCost;
        RentalStatus status;
        uint256 securityDeposit;
        bool autoRenew;
        uint256 maxAutoRenewals;
        uint256 currentRenewals;
    }

    // NFT Bundles
    struct NFTBundle {
        uint256 bundleId;
        string name;
        string description;
        address creator;
        uint256[] tokenIds;
        uint256 bundlePrice;
        uint256 totalIndividualPrice;
        uint256 discountPercentage;
        bool isActive;
        uint256 createdAt;
        uint256 expiresAt;
        bool requiresAllTokens; // true = must buy all, false = can buy individual
    }

    // NFT Insurance
    struct InsurancePolicy {
        uint256 policyId;
        uint256 tokenId;
        address owner;
        uint256 coverageAmount;
        uint256 premiumPaid;
        uint256 startTime;
        uint256 duration;
        InsuranceStatus status;
        string[] coveredRisks;
        uint256 deductible;
        address insuranceProvider;
    }

    // Enhanced Escrow System
    struct EscrowTransaction {
        uint256 escrowId;
        uint256 tokenId;
        address buyer;
        address seller;
        uint256 amount;
        uint256 createdAt;
        uint256 releaseTime; // Time-locked escrow
        bool isActive;
        bool requiresArbitration;
        address arbitrator;
        mapping(address => bool) hasApproved;
        string[] conditions;
        bool[] conditionsMet;
    }

    // Evolutionary NFTs
    struct EvolutionaryNFT {
        uint256 evolutionId;
        uint256 tokenId;
        uint256 currentStage;
        uint256 maxStages;
        EvolutionTrigger[] triggers;
        string[] stageURIs;
        uint256[] stageUnlockTimes;
        mapping(uint256 => bool) stageUnlocked;
        uint256 experiencePoints;
        uint256 evolutionThreshold;
        bool autoEvolve;
    }

    // Weather System for NFTs
    struct WeatherSystem {
        uint256 systemId;
        WeatherCondition currentCondition;
        uint256 lastUpdate;
        uint256 temperature; // In Celsius * 100
        uint256 humidity; // Percentage * 100
        mapping(WeatherCondition => uint256) conditionModifiers; // Price modifiers
        mapping(uint256 => uint256) tokenWeatherBonuses; // TokenId => bonus
        bool isGlobalSystem;
        uint256[] affectedCollections;
    }

    // Quest and Achievement System
    struct Quest {
        uint256 questId;
        string title;
        string description;
        address creator;
        QuestDifficulty difficulty;
        QuestStatus status;
        uint256[] requiredTokenIds;
        string[] objectives;
        uint256 reward;
        address rewardToken; // ERC20 or address(0) for ETH
        uint256 timeLimit;
        uint256 createdAt;
        uint256 participantCount;
        mapping(address => bool) participants;
        mapping(address => bool) completedBy;
        mapping(address => uint256) progressTracking;
    }

    struct Achievement {
        uint256 achievementId;
        string name;
        string description;
        string badgeURI;
        uint256 pointsRequired;
        bool isSecret;
        uint256 unlockedBy;
        mapping(address => bool) earnedBy;
    }

    // Subscription Boxes
    struct SubscriptionBox {
        uint256 boxId;
        string name;
        string description;
        address creator;
        uint256 monthlyPrice;
        uint256 maxSubscribers;
        uint256 currentSubscribers;
        uint256[] guaranteedTokenIds;
        uint256[] possibleTokenIds;
        uint256[] rarityWeights;
        bool isActive;
        uint256 nextDelivery;
        mapping(address => bool) subscribers;
        mapping(address => uint256) subscriptionStart;
    }

    // Lootboxes
    struct Lootbox {
        uint256 lootboxId;
        string name;
        uint256 price;
        LootboxRarity rarity;
        uint256[] possibleTokenIds;
        uint256[] dropRates; // Basis points (10000 = 100%)
        uint256 maxOpens;
        uint256 currentOpens;
        bool isActive;
        address creator;
        uint256 createdAt;
        mapping(address => uint256) userOpens;
    }

    // Offers struct (existing)
    struct Offer {
        address bidder;
        uint256 amount;
        uint256 createdAt;
        uint256 expiresAt;
        PaymentMethod payWith;
        address erc20;
    }

    // Auctions (English) - existing
    struct Auction {
        bool active;
        uint256 tokenId;
        address payable seller;
        uint256 startPrice;
        uint256 highestBid;
        address payable highestBidder;
        uint256 endTime;
        address referrer;
    }

    // Dutch Auction - existing
    struct DutchAuction {
        bool active;
        uint256 tokenId;
        address payable seller;
        uint256 startPrice;
        uint256 endPrice;
        uint256 startTime;
        uint256 duration;
        address referrer;
        PaymentMethod payWith;
        address erc20;
    }

    // EIP-712 Lazy Minting Voucher - existing
    struct LazyMintVoucher {
        uint256 tokenId;
        uint256 price;
        string uri;
        address creator;
        uint256 nonce;
        uint256 expiry;
    }

    // ========== EIP-712 TYPE HASHES ==========
    bytes32 private constant _LAZY_MINT_TYPEHASH = keccak256(
        "LazyMintVoucher(uint256 tokenId,uint256 price,string uri,address creator,uint256 nonce,uint256 expiry)"
    );
    bytes32 private constant _OFFER_TYPEHASH = keccak256(
        "OfferVoucher(uint256 tokenId,uint256 amount,uint256 expiry,uint256 nonce)"
    );

    // ========== MAPPINGS ==========
    mapping(uint256 => MarketItem) private idToMarketItem;
    mapping(uint256 => Collection) private idToCollection;
    mapping(uint256 => VirtualGallery) private idToVirtualGallery;
    mapping(uint256 => AIArtGeneration) private idToAIArtGeneration;
    mapping(uint256 => SubscriptionTier) private subscriptionTiers;
    mapping(address => UserSubscription) private userSubscriptions;
    mapping(uint256 => LoyaltyProgram) private loyaltyPrograms;
    mapping(address => LoyaltyMember) private loyaltyMembers;
    mapping(uint256 => CrossChainBridge) private idToCrossChainBridge;
    mapping(uint256 => GameAssetIntegration) private idToGameAsset;
    mapping(uint256 => DynamicPricing) private idToDynamicPricing;
    mapping(uint256 => FractionalNFT) private idToFractionalNFT;
    mapping(uint256 => StakingPool) private idToStakingPool;
    mapping(uint256 => StakeInfo) private tokenStakeInfo;
    mapping(address => SocialProfile) private socialProfiles;
    mapping(uint256 => Community) private idToCommunity;
    mapping(uint256 => Proposal) private idToProposal;
    mapping(string => MarketAnalytics) private categoryAnalytics;
    mapping(uint256 => MarketAnalytics) private collectionAnalytics;

    // NEW: Additional Mappings for new features
    mapping(uint256 => NFTRental) private idToRental;
    mapping(uint256 => NFTBundle) private idToBundle;
    mapping(uint256 => InsurancePolicy) private idToInsurancePolicy;
    mapping(uint256 => EscrowTransaction) private idToEscrow;
    mapping(uint256 => EvolutionaryNFT) private idToEvolution;
    mapping(uint256 => WeatherSystem) private idToWeatherSystem;
    mapping(uint256 => Quest) private idToQuest;
    mapping(uint256 => Achievement) private idToAchievement;
    mapping(uint256 => SubscriptionBox) private idToSubscriptionBox;
    mapping(uint256 => Lootbox) private idToLootbox;

    // Additional utility mappings
    mapping(uint256 => bool) private tokenCurrentlyRented;
    mapping(address => uint256[]) private userRentals;
    mapping(address => uint256[]) private userBundles;
    mapping(address => uint256[]) private userInsurancePolicies;
    mapping(address => uint256[]) private userEscrows;
    mapping(address => uint256[]) private userCompletedQuests;
    mapping(address => uint256[]) private userAchievements;
    mapping(address => uint256[]) private userSubscriptionBoxes;
    mapping(address => uint256[]) private userLootboxes;

    // Configuration mappings (existing)
    mapping(address => bool) private verifiedCreators;
    mapping(string => bool) private validCategories;
    mapping(address => uint256) private creatorEarnings;
    mapping(address => uint256[]) private userTokens;
    mapping(address => uint256[]) private userVirtualGalleries;
    mapping(address => mapping(uint256 => uint256)) private userAIGenerations;
    mapping(string => bool) private supportedAIStyles;
    mapping(uint256 => bool) private supportedChains;
    mapping(address => uint256[]) private userCrossChainTokens;
    mapping(address => uint256) private userNonce;
    mapping(address => bool) private authorizedAIOracles;
    mapping(address => uint256[]) private userStakedTokens;
    mapping(address => uint256[]) private userCommunities;
    mapping(string => bool) private reservedUsernames;
    mapping(address => mapping(uint256 => bool)) private userCommunityMembership;

    // Payments config
    mapping(address => bool) public allowedERC20;

    // Offers and auctions
    mapping(uint256 => Offer[]) public offers;
    mapping(uint256 => Offer) public bestOffer;
    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => DutchAuction) public dutchAuctions;

    // Allowlist
    bytes32 public allowlistRoot;
    mapping(address => uint256) public allowlistMinted;

    // Referrals
    uint256 public referralBps = 200;
    mapping(address => uint256) public referralEarnings;

    // Platform configuration
    address public aiPricingOracle;
    bool public globalPricingEnabled = true;
    bool public virtualGalleriesEnabled = true;
    bool public aiArtGenerationEnabled = true;
    bool public loyaltyProgramEnabled = true;
    bool public gameAssetIntegrationEnabled = true;
    bool public crossChainEnabled = true;
    bool public fractionalNFTEnabled = true;
    bool public stakingEnabled = true;
    bool public socialFeaturesEnabled = true;
    bool public governanceEnabled = true;
    uint256 public defaultLoyaltyProgramId = 1;
    uint256 private platformFeeBalance;

    // NEW: Global configuration for new features
    bool public rentalSystemEnabled = true;
    bool public bundleSystemEnabled = true;
    bool public insuranceSystemEnabled = true;
    bool public escrowSystemEnabled = true;
    bool public evolutionSystemEnabled = true;
    bool public weatherSystemEnabled = true;
    bool public questSystemEnabled = true;
    bool public subscriptionBoxEnabled = true;
    bool public lootboxSystemEnabled = true;

    // Global weather system
    uint256 public globalWeatherSystemId = 1;

    // Global analytics
    MarketAnalytics public globalAnalytics;

    // ========== EVENTS ==========
    // Existing events...
    event MarketItemCreated(uint256 indexed tokenId, address seller, address owner, uint256 price, bool sold, string category);
    event MarketItemSold(uint256 indexed tokenId, address seller, address buyer, uint256 price, address indexed referrer);
    event ListingCancelled(uint256 indexed tokenId);
    event OfferMade(uint256

