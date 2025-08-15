// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// ──────────────────────────────────────────────────────────────────────────────
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
contract NFTMarketplace is
    ERC721URIStorage,
    ERC2981,
    ReentrancyGuard,
    Ownable,
    Pausable,
    EIP712
{
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

    // NEW: Social & Community Constants
    uint256 public constant COMMUNITY_CREATION_FEE = 0.02 ether;
    uint256 public constant MIN_PROPOSAL_THRESHOLD = 100; // 1%
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant EXECUTION_DELAY = 2 days;

    // ========== ENUMS ==========
    enum PricingType {
        Conservative,
        Balanced,
        Aggressive,
        Momentum,
        Contrarian,
        ValueBased,
        Technical
    }
    enum PaymentMethod {
        ETH,
        ERC20
    }
    enum BridgeStatus {
        Pending,
        InProgress,
        Completed,
        Failed,
        Cancelled
    }
    enum GalleryTheme {
        Modern,
        Classic,
        Cyberpunk,
        Nature,
        Abstract
    }
    enum SubscriptionTierLevel {
        Basic,
        Premium,
        Professional,
        Enterprise
    }
    
    // NEW: Additional Enums
    enum FractionalStatus {
        Active,
        Buyout,
        Dissolved
    }
    enum StakingPoolType {
        FlexibleReward,
        FixedAPY,
        LiquidityMining,
        GovernanceStaking
    }
    enum ProposalStatus {
        Active,
        Passed,
        Failed,
        Executed,
        Cancelled
    }
    enum ReputationLevel {
        Newcomer,
        Bronze,
        Silver,
        Gold,
        Platinum,
        Diamond
    }

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

    // NEW: Fractional NFT Structs
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

    // NEW: Staking Pool Structs
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

    // NEW: Social & Community Structs
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

    // NEW: Advanced Analytics Struct
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

    // Offers
    struct Offer {
        address bidder;
        uint256 amount;
        uint256 createdAt;
        uint256 expiresAt;
        PaymentMethod payWith;
        address erc20;
    }

    // Auctions (English)
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

    // Dutch Auction
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

    // ========== EIP-712 TYPE HASHES ==========
    bytes32 private constant _LAZY_MINT_TYPEHASH =
        keccak256(
            "LazyMintVoucher(uint256 tokenId,uint256 price,string uri,address creator,uint256 nonce,uint256 expiry)"
        );

    bytes32 private constant _OFFER_TYPEHASH =
        keccak256(
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

    // NEW: Additional Mappings
    mapping(uint256 => FractionalNFT) private idToFractionalNFT;
    mapping(uint256 => StakingPool) private idToStakingPool;
    mapping(uint256 => StakeInfo) private tokenStakeInfo;
    mapping(address => SocialProfile) private socialProfiles;
    mapping(uint256 => Community) private idToCommunity;
    mapping(uint256 => Proposal) private idToProposal;
    mapping(string => MarketAnalytics) private categoryAnalytics;
    mapping(uint256 => MarketAnalytics) private collectionAnalytics;

    // Configuration mappings
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

    // NEW: Social mappings
    mapping(address => uint256[]) private userStakedTokens;
    mapping(address => uint256[]) private userCommunities;
    mapping(string => bool) private reservedUsernames;
    mapping(address => mapping(uint256 => bool)) private userCommunityMembership;

    // Payments config
    mapping(address => bool) public allowedERC20;

    // Offers and auctions
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

    // NEW: Global analytics
    MarketAnalytics public globalAnalytics;

    // ========== EVENTS ==========
    // Existing events...
    event MarketItemCreated(uint256 indexed tokenId, address seller, address owner, uint256 price, bool sold, string category);
    event MarketItemSold(uint256 indexed tokenId, address seller, address buyer, uint256 price, address indexed referrer);
    event ListingCancelled(uint256 indexed tokenId);
    event OfferMade(uint256 indexed tokenId, address bidder, uint256 amount);
    event OfferCancelled(uint256 indexed tokenId, address bidder, uint256 amount);
    event OfferAccepted(uint256 indexed tokenId, address seller, address bidder, uint256 amount);
    event AuctionCreated(uint256 indexed tokenId, uint256 startPrice, uint256 endTime);
    event AuctionBid(uint256 indexed tokenId, address bidder, uint256 amount);
    event AuctionFinalized(uint256 indexed tokenId, address winner, uint256 amount);
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
    event GameAssetUsed(uint256 indexed assetId, address indexed player, string gameId);
    event DynamicPricingEnabled(uint256 indexed tokenId, uint256 basePrice, PricingType strategy);
    event AIPriceUpdated(uint256 indexed tokenId, uint256 oldPrice, uint256 newPrice, uint256 confidence, string reason);
    event CollectionCreated(uint256 indexed collectionId, string name, address indexed creator);
    event ListingUpdated(uint256 indexed tokenId, uint256 newPrice, PaymentMethod payWith, address erc20, bool acceptsOffers, uint256 minOffer);
    event DutchAuctionCreated(uint256 indexed tokenId, uint256 startPrice, uint256 endPrice, uint256 startTime, uint256 duration);
    event DutchAuctionPurchased(uint256 indexed tokenId, address buyer, uint256 price, address indexed referrer);
    event AuctionCancelled(uint256 indexed tokenId);
    event CategoryUpdated(string category, bool isValid);
    event CollectionRoyaltyUpdated(uint256 indexed collectionId, address receiver, uint96 bps);

    // NEW: Additional Events
    event FractionalNFTCreated(uint256 indexed fractionalId, uint256 indexed tokenId, uint256 totalSupply, uint256 pricePerShare);
    event FractionalSharesPurchased(uint256 indexed fractionalId, address indexed buyer, uint256 shares, uint256 totalCost);
    event FractionalBuyoutInitiated(uint256 indexed fractionalId, address indexed buyer, uint256 buyoutPrice);
    event StakingPoolCreated(uint256 indexed poolId, string name, address indexed creator, StakingPoolType poolType);
    event TokenStaked(uint256 indexed tokenId, address indexed staker, uint256 indexed poolId, uint256 duration);
    event TokenUnstaked(uint256 indexed tokenId, address indexed staker, uint256 rewards);
    event RewardsClaimed(address indexed staker, uint256 indexed poolId, uint256 amount);
    event SocialProfileCreated(address indexed user, string username);
    event UserFollowed(address indexed follower, address indexed following);
    event CommunityCreated(uint256 indexed communityId, string name, address indexed creator);
    event CommunityJoined(uint256 indexed communityId, address indexed member);
    event ProposalCreated(uint256 indexed proposalId, uint256 indexed communityId, address indexed proposer, string title);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId);
    event ReputationUpdated(address indexed user, uint256 newScore, ReputationLevel newLevel);
    event BadgeEarned(address indexed user, uint256 indexed badgeId, string badgeName);
    event AnalyticsUpdated(string indexed category, uint256 volume, uint256 floorPrice);

    // ========== MODIFIERS ==========
    modifier onlyTokenOwner(uint256 tokenId) {
        require(ownerOf(tokenId) == msg.sender, "Not token owner");
        _;
    }

    modifier validTokenId(uint256 tokenId) {
        require(_exists(tokenId), "Token does not exist");
        _;
    }

    modifier onlyVerifiedCreator() {
        require(verifiedCreators[msg.sender] || msg.sender == owner(), "Not verified creator");
        _;
    }

    modifier onlyPremiumSubscriber() {
        require(
            userSubscriptions[msg.sender].isActive &&
                userSubscriptions[msg.sender].currentTier >= SubscriptionTierLevel.Premium,
            "Premium subscription required"
        );
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

    modifier onlyAIPricingOracle() {
        require(
            msg.sender == aiPricingOracle || msg.sender == owner() || authorizedAIOracles[msg.sender],
            "Not authorized for AI pricing"
        );
        _;
    }

    // NEW: Additional Modifiers
    modifier onlyCommunityMember(uint256 communityId) {
        require(idToCommunity[communityId].members[msg.sender], "Not community member");
        _;
    }

    modifier onlyCommunityModerator(uint256 communityId) {
        require(
            idToCommunity[communityId].moderators[msg.sender] || 
            idToCommunity[communityId].creator == msg.sender,
            "Not community moderator"
        );
        _;
    }

    modifier socialFeaturesEnabled() {
        require(socialFeaturesEnabled, "Social features disabled");
        _;
    }

    modifier fractionalEnabled() {
        require(fractionalNFTEnabled, "Fractional NFTs disabled");
        _;
    }

    modifier stakingEnabledModifier() {
        require(stakingEnabled, "Staking disabled");
        _;
    }

    // ========== CONSTRUCTOR ==========
    constructor()
        ERC721("NFT Marketplace", "NFTM")
        EIP712("NFTMarketplace", "1")
    {
        // Initialize valid categories
        validCategories["Art"] = true;
        validCategories["Music"] = true;
        validCategories["Photography"] = true;
        validCategories["Sports"] = true;
        validCategories["Gaming"] = true;
        validCategories["Utility"] = true;
        validCategories["Collectibles"] = true;
        validCategories["Domain"] = true;
        validCategories["Metaverse"] = true;
        validCategories["VirtualGallery"] = true;
        validCategories["GameAsset"] = true;

        // Initialize AI Pricing Oracle
        aiPricingOracle = msg.sender;
        authorizedAIOracles[msg.sender] = true;

        // Initialize supported chains
        supportedChains[1] = true; // Ethereum
        supportedChains[137] = true; // Polygon
        supportedChains[56] = true; // BSC
        supportedChains[43114] = true; // Avalanche

        // Initialize AI art styles
        supportedAIStyles["Realistic"] = true;
        supportedAIStyles["Abstract"] = true;
        supportedAIStyles["Impressionist"] = true;
        supportedAIStyles["Cyberpunk"] = true;
        supportedAIStyles["Fantasy"] = true;

        // Default loyalty program and subscription tiers
        _createDefaultLoyaltyProgram();
        _createDefaultSubscriptionTiers();
        _createDefaultStakingPool();

        // Default royalty 5% to owner (can change)
        _setDefaultRoyalty(msg.sender, 500);

        // Initialize global analytics
        globalAnalytics.lastUpdated = block.timestamp;
    }

    // ========== MARKETPLACE: LIST, BUY, CANCEL ==========

    function createMarketItem(
        uint256 tokenId,
        uint256 price,
        string calldata category,
        uint256 collectionId,
        PaymentMethod payWith,
        address erc20
    ) external nonReentrant validTokenId(tokenId) whenNotPaused {
        require(price > 0, "Price must be > 0");
        require(validCategories[category], "Invalid category");
