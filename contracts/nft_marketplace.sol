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

    // ========== EIP-712 Type Hashes ==========
    bytes32 private constant _LAZY_MINT_TYPEHASH = 
        keccak256("LazyMintVoucher(uint256 tokenId,uint256 price,string uri,address creator,uint256 nonce,uint256 expiry)");
    
    bytes32 private constant _BID_TYPEHASH = 
        keccak256("SealedBid(uint256 tokenId,uint256 amount,uint256 nonce,uint256 expiry)");

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

    // ========== Enhanced Structs ==========
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
        mapping(uint256 => uint256) dailyVolume; // timestamp => volume
        mapping(address => uint256) topHolders;
    }

    struct FractionalNFT { 
        uint256 tokenId; 
        uint256 totalShares; 
        uint256 sharePrice; 
        mapping(address => uint256) shareOwnership; 
        address[] shareholders; 
        bool isActive;
        uint256 dividendPool;
        mapping(address => uint256) lastDividendClaim;
        uint256 minimumBuyout;
        bool buyoutInitiated;
        address buyoutInitiator;
        uint256 buyoutDeadline;
        uint256 sharesForSale;
        mapping(address => uint256) shareOffers;
        GovernanceSettings governance;
    }

    struct GovernanceSettings {
        uint256 votingPeriod;
        uint256 quorumThreshold;
        bool allowProposals;
        mapping(uint256 => FractionalProposal) proposals;
        uint256 proposalCount;
    }

    struct FractionalProposal {
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 endTime;
        bool executed;
        mapping(address => bool) hasVoted;
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

    struct Auction { 
        uint256 tokenId; 
        uint256 startingPrice; 
        uint256 highestBid; 
        address highestBidder; 
        uint256 auctionEnd; 
        bool ended; 
        mapping(address => uint256) pendingReturns; 
        uint256 reservePrice;
        bool isExtendable;
        uint256 bidIncrement;
        uint256 extensionTime;
        AuctionType auctionType;
        uint256 decrementAmount;
        uint256 decrementInterval;
        bool allowBuyNow;
        uint256 buyNowPrice;
        mapping(bytes32 => SealedBid) sealedBids;
        bytes32[] bidHashes;
        uint256 revealStart;
        uint256 revealEnd;
        bool bidsRevealed;
        AuctionAnalytics analytics;
    }

    struct AuctionAnalytics {
        uint256 totalBids;
        uint256 uniqueBidders;
        uint256 averageBid;
        uint256 bidVolatility;
        mapping(address => uint256) bidderActivity;
    }

    struct SealedBid {
        address bidder;
        uint256 amount;
        bool revealed;
        bool refunded;
    }

    enum AuctionType { English, Dutch, Sealed, Reserve }

    struct Drop {
        uint256 dropId;
        string name;
        string description;
        address creator;
        uint256 startTime;
        uint256 endTime;
        uint256 maxSupply;
        uint256 currentSupply;
        uint256 price;
        uint256 maxPerWallet;
        bool isWhitelistOnly;
        mapping(address => bool) whitelist;
        mapping(address => uint256) purchased;
        string baseURI;
        bool isActive;
        uint256 revealTime;
        bool isRevealed;
        bytes32 merkleRoot;
        bool usesDutchAuction;
        uint256 startPrice;
        uint256 endPrice;
        uint256 priceDecayRate;
        DropAnalytics analytics;
        DropSocial social;
    }

    struct DropAnalytics {
        uint256 totalParticipants;
        uint256 conversionRate;
        uint256 averagePurchase;
        uint256 gasUsed;
        mapping(uint256 => uint256) hourlyMints;
    }

    struct DropSocial {
        uint256 hypeScore;
        uint256 socialMentions;
        uint256 communitySize;
        mapping(address => bool) followers;
        uint256 followerCount;
    }

    // ========== NEW: Advanced Analytics System ==========
    struct MarketAnalytics {
        uint256 analyticsId;
        uint256 totalVolume24h;
        uint256 totalVolume7d;
        uint256 totalVolume30d;
        uint256 averagePrice24h;
        uint256 floorPrice;
        uint256 ceilingPrice;
        uint256 totalSales;
        uint256 uniqueBuyers;
        uint256 uniqueSellers;
        mapping(string => uint256) categoryVolume;
        mapping(address => uint256) topTraders;
        mapping(uint256 => PricePoint) priceHistory;
        uint256 priceHistoryCount;
        TrendData trends;
    }

    struct PricePoint {
        uint256 timestamp;
        uint256 price;
        uint256 volume;
        string category;
    }

    struct TrendData {
        int256 priceChange24h;
        int256 volumeChange24h;
        uint256 trendingTokens;
        uint256 emergingCollections;
        mapping(uint256 => uint256) categoryTrends;
    }

    // ========== NEW: Social Trading Features ==========
    struct SocialTrading {
        uint256 socialId;
        address trader;
        string username;
        string bio;
        string profileImage;
        uint256 followerCount;
        uint256 followingCount;
        mapping(address => bool) followers;
        mapping(address => bool) following;
        TradingStats stats;
        SocialMetrics metrics;
        mapping(uint256 => TradePost) tradePosts;
        uint256 postCount;
        bool isInfluencer;
        uint256 influencerTier;
    }

    struct TradingStats {
        uint256 totalTrades;
        uint256 profitableTrades;
        uint256 totalProfit;
        uint256 totalVolume;
        uint256 averageHoldTime;
        uint256 successRate;
        uint256 reputation;
        mapping(string => uint256) categoryExpertise;
    }

    struct SocialMetrics {
        uint256 postLikes;
        uint256 postShares;
        uint256 commentCount;
        uint256 engagementRate;
        uint256 influenceScore;
    }

    struct TradePost {
        uint256 postId;
        address trader;
        string content;
        uint256 tokenId;
        TradeAction action;
        uint256 price;
        uint256 timestamp;
        uint256 likes;
        uint256 shares;
        mapping(address => bool) likedBy;
        mapping(address => string) comments;
        address[] commenters;
        bool isSignal;
        uint256 confidenceLevel;
    }

    enum TradeAction { Buy, Sell, Hold, Watch }

    // ========== NEW: Gamification System ==========
    struct GamificationSystem {
        uint256 gamificationId;
        mapping(address => UserLevel) userLevels;
        mapping(address => Achievement[]) userAchievements;
        mapping(address => uint256) userXP;
        mapping(address => uint256) userStreaks;
        mapping(uint256 => Quest) activeQuests;
        uint256 questCount;
        mapping(address => uint256[]) userQuests;
        SeasonalEvent currentEvent;
        mapping(address => Badge[]) userBadges;
    }

    struct UserLevel {
        uint256 level;
        uint256 xp;
        uint256 xpToNext;
        string title;
        uint256[] unlockedFeatures;
        uint256 multiplier;
    }

    struct Achievement {
        uint256 achievementId;
        string name;
        string description;
        uint256 xpReward;
        bool unlocked;
        uint256 unlockedAt;
        AchievementType achievementType;
    }

    enum AchievementType { Trading, Social, Collection, Streak, Milestone }

    struct Quest {
        uint256 questId;
        string name;
        string description;
        QuestType questType;
        uint256 target;
        uint256 reward;
        uint256 xpReward;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        mapping(address => uint256) userProgress;
        uint256 participants;
    }

    enum QuestType { Buy, Sell, List, Bid, Follow, Share, Comment }

    struct SeasonalEvent {
        string name;
        uint256 startTime;
        uint256 endTime;
        uint256 bonusMultiplier;
        mapping(address => uint256) eventXP;
        uint256[] eventAchievements;
        bool isActive;
    }

    struct Badge {
        uint256 badgeId;
        string name;
        string image;
        BadgeType badgeType;
        uint256 earnedAt;
    }

    enum BadgeType { Trader, Collector, Creator, Social, Special }

    // ========== NEW: Advanced AI Features ==========
    struct AIRecommendation {
        uint256 tokenId;
        address user;
        uint256 confidence;
        string reason;
        uint256 timestamp;
        bool isPositive;
        uint256 priceTarget;
        uint256 timeframe;
    }

    struct PriceOracle {
        mapping(uint256 => uint256) tokenPredictions;
        mapping(string => uint256) categoryPredictions;
        mapping(address => uint256) userRiskProfiles;
        uint256 lastUpdate;
        bool isActive;
    }

    // ========== Additional Structs (continuing from original) ==========
    struct Affiliate {
        uint256 affiliateId;
        address affiliateAddress;
        uint256 commissionRate;
        uint256 totalEarnings;
        uint256 totalReferrals;
        bool isActive;
        uint256 tier;
        uint256 minReferrals;
        uint256 bonusMultiplier;
    }

    struct DynamicPricing {
        uint256 tokenId;
        uint256 basePrice;
        uint256 currentPrice;
        uint256 priceIncrement;
        uint256 lastSaleTime;
        uint256 demandMultiplier;
        bool isActive;
        uint256 maxPrice;
        uint256 minPrice;
        uint256 volatilityFactor;
    }

    struct BridgeRequest {
        uint256 tokenId;
        address owner;
        uint256 targetChain;
        string targetAddress;
        uint256 timestamp;
        bool completed;
        bytes32 txHash;
        uint256 fee;
        BridgeStatus status;
    }

    enum BridgeStatus { Pending, Processing, Completed, Failed, Cancelled }

    struct Insurance {
        uint256 tokenId;
        address insured;
        uint256 coverageAmount;
        uint256 premium;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        string[] coveredRisks;
        uint256 claimCount;
        bool hasClaim;
    }

    struct StakingPool {
        uint256 poolId;
        string name;
        uint256 rewardRate;
        uint256 lockPeriod;
        uint256 totalStaked;
        uint256 maxStake;
        bool isActive;
        IERC20 rewardToken;
        mapping(address => UserStake) userStakes;
        uint256 penaltyRate;
        uint256 bonusMultiplier;
        uint256 minStakeAmount;
    }

    struct UserStake {
        uint256 amount;
        uint256 stakingTime;
        uint256 lastRewardClaim;
        uint256 totalRewards;
        uint256 lockEndTime;
        bool isAutoCompound;
        uint256 multiplier;
    }

    struct Proposal {
        uint256 proposalId;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        ProposalType proposalType;
        bytes data;
        uint256 quorumRequired;
        bool cancelled;
        address proposer;
    }

    enum ProposalType { FeeChange, CategoryAdd, FeatureToggle, Emergency, ParameterChange }

    struct Rental {
        uint256 rentalId;
        uint256 tokenId;
        address owner;
        address renter;
        uint256 dailyRate;
        uint256 startTime;
        uint256 endTime;
        uint256 deposit;
        bool isActive;
        bool isCompleted;
        RentalTerms terms;
    }

    struct RentalTerms {
        bool allowSubrenting;
        bool requiresApproval;
        uint256 maxRentalPeriod;
        string[] restrictions;
        uint256 lateFee;
        uint256 damageDeposit;
    }

    struct Loan {
        uint256 loanId;
        uint256 tokenId;
        address borrower;
        address lender;
        uint256 loanAmount;
        uint256 interestRate;
        uint256 duration;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        bool isRepaid;
        uint256 totalOwed;
        bool isDefaulted;
    }

    struct Escrow {
        uint256 escrowId;
        uint256 tokenId;
        address buyer;
        address seller;
        uint256 amount;
        bool buyerApproved;
        bool sellerApproved;
        bool isCompleted;
        bool isCancelled;
        uint256 createdAt;
        uint256 expiryTime;
        address arbiter;
    }

    struct Subscription {
        uint256 subscriptionId;
        uint256 tokenId;
        address subscriber;
        uint256 monthlyFee;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        uint256 renewalCount;
        bool autoRenew;
        SubscriptionTier tier;
    }

    enum SubscriptionTier { Basic, Premium, VIP }

    struct Bundle {
        uint256 bundleId;
        uint256[] tokenIds;
        address seller;
        uint256 totalPrice;
        uint256 discountPercentage;
        uint256 createdAt;
        uint256 expiresAt;
        bool isSold;
        bool isActive;
        string bundleName;
        string description;
    }

    struct Lottery {
        uint256 lotteryId;
        uint256[] tokenIds;
        uint256 ticketPrice;
        uint256 totalTickets;
        uint256 maxTickets;
        mapping(address => uint256) ticketsBought;
        address[] participants;
        uint256 startTime;
        uint256 endTime;
        bool isCompleted;
        address winner;
        uint256 randomSeed;
    }

    enum PaymentMethod { ETH, ERC20, Crypto, Fiat }

    struct PaymentToken {
        address tokenAddress;
        bool isAccepted;
        uint256 conversionRate;
        uint8 decimals;
    }

    struct LazyMintVoucher {
        uint256 tokenId;
        uint256 price;
        string uri;
        address creator;
        uint256 nonce;
        uint256 expiry;
        bytes signature;
    }

    // ========== Enhanced Mappings ==========
    mapping(uint256 => MarketItem) private idToMarketItem;
    mapping(uint256 => Auction) private idToAuction;
    mapping(uint256 => Collection) private idToCollection;
    mapping(uint256 => FractionalNFT) private idToFractionalNFT;
    mapping(uint256 => Drop) private idToDrop;
    mapping(uint256 => Affiliate) private idToAffiliate;
    mapping(uint256 => DynamicPricing) private idToDynamicPricing;
    mapping(uint256 => BridgeRequest) private idToBridgeRequest;
    mapping(uint256 => Insurance) private idToInsurance;
    mapping(uint256 => StakingPool) private idToStakingPool;
    mapping(uint256 => Rental) private idToRental;
    mapping(uint256 => Loan) private idToLoan;
    mapping(uint256 => Escrow) private idToEscrow;
    mapping(uint256 => Subscription) private idToSubscription;
    mapping(uint256 => Bundle) private idToBundle;
    mapping(uint256 => Lottery) private idToLottery;
    mapping(uint256 => Proposal) private proposals;

    // NEW: Enhanced mappings
    mapping(uint256 => MarketAnalytics) private marketAnalytics;
    mapping(uint256 => SocialTrading) private socialTrading;
    mapping(uint256 => GamificationSystem) private gamificationSystems;
    mapping(address => AIRecommendation[]) private userRecommendations;
    mapping(address => PriceOracle) private priceOracles;

    // User mappings
    mapping(address => bool) private verifiedCreators;
    mapping(string => bool) private validCategories;
    mapping(address => uint256) private creatorEarnings;
    mapping(address => bool) private bannedUsers;
    mapping(address => uint256) private userNonce;
    mapping(address => address) private referrals;
    mapping(address => uint256[]) private userCollections;
    mapping(uint256 => uint256[]) private collectionPriceHistory;
    mapping(address => mapping(uint256 => bool)) private userVotedForCollection;
    mapping(address => uint256) private lastActivityTime;
    mapping(address => uint256) private userReputation;
    mapping(address => bool) private multisigWallets;
    mapping(uint256 => mapping(address => bool)) private tokenApprovals;
    mapping(address => uint256) private votingPower;
    mapping(uint256 => mapping(address => bool)) private hasVoted;
    mapping(address => PaymentToken) private acceptedPaymentTokens;
    mapping(uint256 => mapping(address => uint256)) private tokenOffers;
    mapping(address => uint256[]) private userWatchlist;

    // NEW: Additional mappings
    mapping(address => bool) private marketAnalysts;
    mapping(address => uint256) private lastActionTime;
    mapping(address => uint256[]) private userAIRecommendations;
    mapping(string => uint256) private categoryPopularity;
    mapping(address => mapping(address => bool)) private socialConnections;
    mapping(uint256 => mapping(address => uint256)) private tokenEngagement;

    // Configuration
    uint256 public actionCooldown = 1 seconds;
    bool public aiRecommendationsEnabled = true;
    bool public socialTradingEnabled = true;
    bool public gamificationEnabled = true;

    // ========== Enhanced Events ==========
    event MarketItemCreated(uint256 indexed tokenId, address seller, address owner, uint256 price, bool sold, string category);
    event MarketItemSold(uint256 indexed tokenId, address seller, address buyer, uint256 price, address indexed referrer);
    event AuctionCreated(uint256 indexed tokenId, uint256 startingPrice, uint256 auctionEnd, AuctionType auctionType);
    event BidPlaced(uint256 indexed tokenId, address bidder, uint256 amount);
    event AuctionEnded(uint256 indexed tokenId, address winner, uint256 amount);
    event DropCreated(uint256 indexed dropId, string name, address creator, uint256 maxSupply);
    event DropMinted(uint256 indexed dropId, address buyer, uint256 quantity, uint256 totalCost);
    event AffiliateRegistered(uint256 indexed affiliateId, address affiliate, uint256 commissionRate);
    event CommissionPaid(address indexed affiliate, uint256 amount, uint256 indexed tokenId);
    event DynamicPriceUpdated(uint256 indexed tokenId, uint256 oldPrice, uint256 newPrice);
    event BridgeRequested(uint256 indexed tokenId, address owner, uint256 targetChain);
    event InsurancePurchased(uint256 indexed tokenId, address insured, uint256 coverageAmount);
    event StakingPoolCreated(uint256 indexed poolId, string name, uint256 rewardRate);
    event TokensStaked(address indexed user, uint256 indexed poolId, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 indexed poolId, uint256 amount);
    event ProposalCreated(uint256 indexed proposalId, string description, ProposalType proposalType);
    event ProposalExecuted(uint256 indexed proposalId);
    event Voted(uint256 indexed proposalId, address voter, bool support, uint256 weight);
    event UserBanned(address indexed user, string reason);
    event UserUnbanned(address indexed user);
    event RentalCreated(uint256 indexed rentalId, uint256 indexed tokenId, address owner, uint256 dailyRate);
    event RentalStarted(uint256 indexed rentalId, address renter, uint256 startTime, uint256 endTime);
    event RentalEnded(uint256 indexed rentalId, bool completed);
    event LoanCreated(uint256 indexed loanId, uint256 indexed tokenId, address borrower, uint256 amount);
    event LoanRepaid(uint256 indexed loanId, uint256 amount);
    event LoanDefaulted(uint256 indexed loanId);
    event EscrowCreated(uint256 indexed escrowId, uint256 indexed tokenId, address buyer, address seller);
    event EscrowCompleted(uint256 indexed escrowId);
    event BundleCreated(uint256 indexed bundleId, uint256[] tokenIds, uint256 totalPrice);
    event BundleSold(uint256 indexed bundleId, address buyer);
    event LotteryCreated(uint256 indexed lotteryId, uint256 ticketPrice, uint256 maxTickets);
    event LotteryTicketBought(uint256 indexed lotteryId, address buyer, uint256 quantity);
    event LotteryWinner(uint256 indexed lotteryId, address winner, uint256[] tokenIds);
    event OfferMade(uint256 indexed tokenId, address buyer, uint256 amount);
    event OfferAccepted(uint256 indexed tokenId, address seller, address buyer, uint256 amount);
    event LazyMinted(uint256 indexed tokenId, address creator, address buyer, uint256 price);

    // NEW: Additional events
    event AnalyticsUpdated(uint256 indexed analyticsId, uint256 volume24h, uint256 floorPrice);
    event SocialConnectionMade(address indexed user1, address indexed user2, bool isFollowing);
    event TradePostCreated(uint256 indexed postId, address indexed trader, uint256 indexed tokenId, TradeAction action);
    event AchievementUnlocked(address indexed user, uint256 indexed achievementId, string name);
    event QuestCompleted(address indexed user, uint256 indexed questId, uint256 xpReward);
    event LevelUp(address indexed user, uint256 newLevel, string newTitle);
    event AIRecommendationGenerated(uint256 indexed tokenId, address indexed user, uint256 confidence);
    event TokenEngagement
