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
// Marketplace
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

    // AI Pricing Constants
    uint256 public constant AI_PRICING_UPDATE_INTERVAL = 1 hours;
    uint256 public constant MIN_PRICE_CHANGE_THRESHOLD = 50;
    uint256 public constant MAX_PRICE_CHANGE_PER_UPDATE = 2000;
    uint256 public constant PRICING_CONFIDENCE_THRESHOLD = 7000;

    // Auction constants
    uint256 public constant MIN_AUCTION_DURATION = 1 hours;
    uint256 public constant AUCTION_TIME_EXTENSION = 10 minutes;

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
    }

    struct Collection {
        uint256 collectionId;
        string name;
        string description;
        address creator;
        uint256 totalSupply;
        uint256 maxSupply;
        uint96 royaltyBps; // NEW: for ERC2981
        address royaltyReceiver;
        bool isVerified;
        string logoURI;
        string bannerURI;
        uint256 floorPrice;
        uint256 totalVolume;
        bool isActive;
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
        uint256 discountPercentage; // used for platform fee discount on seller side
        bool isActive;
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
        uint256 pointsToEtherRate; // 1e18 scale
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

    // Offers
    struct Offer {
        address bidder;
        uint256 amount; // in ETH
        uint256 createdAt;
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

    // ───── NEW: Dutch Auction ─────
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
        address erc20; // optional ERC20 for payment
    }

    // ========== EIP-712 TYPE HASHES ==========
    // Lazy mint voucher
    // NOTE: tokenId==0 means "mint a new token id assigned by contract".
    bytes32 private constant _LAZY_MINT_TYPEHASH =
        keccak256(
            "LazyMintVoucher(uint256 tokenId,uint256 price,string uri,address creator,uint256 nonce,uint256 expiry)"
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

    // Configuration mappings
    mapping(address => bool) private verifiedCreators;
    mapping(string => bool) private validCategories;
    mapping(address => uint256) private creatorEarnings;
    mapping(address => uint256[]) private userTokens;
    mapping(address => uint256[]) private userVirtualGalleries;
    mapping(address => mapping(uint256 => uint256)) private userAIGenerations; // user => day => count
    mapping(string => bool) private supportedAIStyles;
    mapping(uint256 => bool) private supportedChains;
    mapping(address => uint256[]) private userCrossChainTokens;
    mapping(address => uint256) private userNonce;
    mapping(address => bool) private authorizedAIOracles;

    // Payments config
    mapping(address => bool) public allowedERC20; // token => allowed

    // Offers and auctions
    mapping(uint256 => Offer) public bestOffer; // tokenId => best offer
    mapping(uint256 => Auction) public auctions; // tokenId => auction

    // ───── NEW: Dutch Auctions mapping ─────
    mapping(uint256 => DutchAuction) public dutchAuctions; // tokenId => dutch auction

    // Allowlist
    bytes32 public allowlistRoot;
    mapping(address => uint256) public allowlistMinted;

    // Referrals
    uint256 public referralBps = 200; // 2% of platform fee by default (NOT of sale price)
    mapping(address => uint256) public referralEarnings;

    // Platform configuration
    address public aiPricingOracle;
    bool public globalPricingEnabled = true;
    bool public virtualGalleriesEnabled = true;
    bool public aiArtGenerationEnabled = true;
    bool public loyaltyProgramEnabled = true;
    bool public gameAssetIntegrationEnabled = true;
    bool public crossChainEnabled = true;
    uint256 public defaultLoyaltyProgramId = 1;
    uint256 private platformFeeBalance;

    // ========== EVENTS ==========
    event MarketItemCreated(
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        bool sold,
        string category
    );
    event MarketItemSold(
        uint256 indexed tokenId,
        address seller,
        address buyer,
        uint256 price,
        address indexed referrer
    );
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

    // ───── NEW events ─────
    event ListingUpdated(uint256 indexed tokenId, uint256 newPrice, PaymentMethod payWith, address erc20, bool acceptsOffers, uint256 minOffer);
    event DutchAuctionCreated(uint256 indexed tokenId, uint256 startPrice, uint256 endPrice, uint256 startTime, uint256 duration);
    event DutchAuctionPurchased(uint256 indexed tokenId, address buyer, uint256 price, address indexed referrer);
    event AuctionCancelled(uint256 indexed tokenId);
    event CategoryUpdated(string category, bool isValid);
    event CollectionRoyaltyUpdated(uint256 indexed collectionId, address receiver, uint96 bps);

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

        // Default royalty 5% to owner (can change)
        _setDefaultRoyalty(msg.sender, 500);
    }

    // ========== MARKETPLACE: LIST, BUY, CANCEL ==========

    function createMarketItem(
        uint256 tokenId,
        uint256 price,
        string calldata category,
        uint256 collectionId,
        PaymentMethod payWith,
        address erc20 // 0 if ETH
    ) external nonReentrant validTokenId(tokenId) whenNotPaused {
        require(price > 0, "Price must be > 0");
        require(validCategories[category], "Invalid category");
        require(ownerOf(tokenId) == msg.sender, "Not token owner");

        if (payWith == PaymentMethod.ERC20) {
            require(allowedERC20[erc20], "ERC20 not allowed");
        } else {
            require(erc20 == address(0), "ETH listing requires erc20=0");
        }

        // Pull NFT into escrow
        _transfer(msg.sender, address(this), tokenId);

        MarketItem storage m = idToMarketItem[tokenId];
        m.tokenId = tokenId;
        m.seller = payable(msg.sender);
        m.owner = payable(address(0));
        m.creator = m.creator == address(0) ? payable(msg.sender) : m.creator;
        m.price = price;
        m.createdAt = block.timestamp;
        m.expiresAt = 0;
        m.sold = false;
        m.isAuction = false;
        m.category = category;
        m.collectionId = collectionId;
        m.acceptsOffers = true;
        m.minOffer = 0;
        m.payWith = payWith;
        m.erc20 = erc20;

        emit MarketItemCreated(tokenId, msg.sender, address(0), price, false, category);
    }

    // ───── NEW: create listing with expiry ─────
    function createMarketItemWithExpiry(
        uint256 tokenId,
        uint256 price,
        string calldata category,
        uint256 collectionId,
        PaymentMethod payWith,
        address erc20,
        uint256 expiresAt
    ) external nonReentrant validTokenId(tokenId) whenNotPaused {
        createMarketItem(tokenId, price, category, collectionId, payWith, erc20);
        idToMarketItem[tokenId].expiresAt = expiresAt;
    }

    // ───── NEW: update listing fields ─────
    function updateListing(
        uint256 tokenId,
        uint256 newPrice,
        PaymentMethod payWith,
        address erc20,
        bool acceptsOffers,
        uint256 minOffer
    ) external nonReentrant {
        MarketItem storage m = idToMarketItem[tokenId];
        require(m.seller == msg.sender, "Not seller");
        require(!m.sold, "Already sold");
        require(!m.isAuction, "Auction active");
        require(newPrice > 0, "Price must be > 0");

        if (payWith == PaymentMethod.ERC20) {
            require(allowedERC20[erc20], "ERC20 not allowed");
        } else {
            require(erc20 == address(0), "ETH listing requires erc20=0");
        }

        m.price = newPrice;
        m.payWith = payWith;
        m.erc20 = erc20;
        m.acceptsOffers = acceptsOffers;
        m.minOffer = minOffer;

        emit ListingUpdated(tokenId, newPrice, payWith, erc20, acceptsOffers, minOffer);
    }

    function cancelListing(uint256 tokenId) external nonReentrant {
        MarketItem storage m = idToMarketItem[tokenId];
        require(m.seller == msg.sender, "Not seller");
        require(!m.sold, "Already sold");
        require(!m.isAuction, "Auction active");
        _transfer(address(this), m.seller, tokenId);
        delete idToMarketItem[tokenId];
        emit ListingCancelled(tokenId);
    }

    function createMarketSale(uint256 tokenId, address referrer) external payable nonReentrant whenNotPaused {
        MarketItem storage m = idToMarketItem[tokenId];
        require(!m.sold && !m.isAuction, "Not fixed-price");
        require(m.price > 0, "Not listed");
        if (m.expiresAt != 0) {
            require(block.timestamp <= m.expiresAt, "Listing expired");
        }

        uint256 price = m.price;

        if (m.payWith == PaymentMethod.ETH) {
            require(msg.value == price, "Incorrect ETH");
        } else {
            require(msg.value == 0, "ERC20 purchase is non-ETH");
            _collectERC20(m.erc20, msg.sender, price);
        }

        _settleSaleAndTransfer(tokenId, price, referrer, msg.sender);

        emit MarketItemSold(tokenId, m.seller, msg.sender, price, referrer);
    }

    // Internal settlement (royalties + platform + seller; supports ETH & ERC20)
    function _settleSaleAndTransfer(
        uint256 tokenId,
        uint256 grossAmount,
        address referrer,
        address buyer
    ) internal {
        MarketItem storage m = idToMarketItem[tokenId];

        // Royalties (ERC2981)
        (address royaltyRec, uint256 royaltyAmount) = royaltyInfo(tokenId, grossAmount);
        require(royaltyAmount <= (grossAmount * MAX_ROYALTY) / 10000, "Royalty too high");

        // Platform fee (with seller subscription discount) // NEW
        uint256 platformFeeAmount = (grossAmount * platformFee) / 10000;
        UserSubscription memory s = userSubscriptions[m.seller];
        if (s.isActive) {
            uint256 discountBps = subscriptionTiers[s.tierId].discountPercentage;
            if (discountBps > 0) {
                uint256 discount = (platformFeeAmount * discountBps) / 10000;
                if (discount > platformFeeAmount) discount = platformFeeAmount;
                platformFeeAmount -= discount;
            }
        }

        // Referral from platform fee
        uint256 referralCut = 0;
        if (referrer != address(0) && referrer != m.seller && referrer != buyer) {
            referralCut = (platformFeeAmount * referralBps) / 10000;
            referralEarnings[referrer] += referralCut;
            platformFeeAmount -= referralCut;
        }

        uint256 sellerAmount = grossAmount - royaltyAmount - platformFeeAmount;

        if (m.payWith == PaymentMethod.ETH) {
            // Pay royalty
            if (royaltyAmount > 0 && royaltyRec != address(0)) {
                (bool okR, ) = payable(royaltyRec).call{value: royaltyAmount}("");
                require(okR, "Royalty pay failed");
            }
            // Pay seller
            (bool okS, ) = m.seller.call{value: sellerAmount}("");
            require(okS, "Seller pay failed");

            // Add platform fee balance
            platformFeeBalance += platformFeeAmount;

            // Referral earnings are accounted; owner pays via payReferral
        } else {
            // ERC20 flow
            IERC20 token = IERC20(m.erc20);
            if (royaltyAmount > 0 && royaltyRec != address(0)) {
                require(token.transfer(royaltyRec, royaltyAmount), "ERC20 royalty fail");
            }
            require(token.transfer(m.seller, sellerAmount), "ERC20 seller fail");
            // Accrue platform fee into the contract
            require(token.transfer(address(this), platformFeeAmount), "ERC20 platform fee fail");
        }

        // Transfer NFT
        _transfer(address(this), buyer, tokenId);

        // Bookkeeping
        m.owner = payable(buyer);
        m.sold = true;
        _itemsSold.increment();

        // Loyalty points
        if (loyaltyProgramEnabled) {
            _awardLoyaltyPoints(buyer, grossAmount / 1e16, "PURCHASE"); // 1 pt per 0.01 ETH (or 0.01 token unit)
        }
    }

    // ========== OFFERS (ETH escrow) ==========

    function makeOffer(uint256 tokenId) external payable nonReentrant whenNotPaused {
        require(msg.value > 0, "Zero offer");
        MarketItem storage m = idToMarketItem[tokenId];
        require(!m.sold, "Sold");
        require(!m.isAuction, "Auction active");
        require(m.acceptsOffers, "Offers disabled");
        require(msg.value >= m.minOffer, "Below min offer");

        Offer storage current = bestOffer[tokenId];
        require(msg.value > current.amount, "Offer not higher");

        // refund previous
        if (current.amount > 0) {
            (bool ok, ) = payable(current.bidder).call{value: current.amount}("");
            require(ok, "Refund failed");
        }

        bestOffer[tokenId] = Offer({bidder: msg.sender, amount: msg.value, createdAt: block.timestamp});
        emit OfferMade(tokenId, msg.sender, msg.value);
    }

    function cancelMyOffer(uint256 tokenId) external nonReentrant {
        Offer storage current = bestOffer[tokenId];
        require(current.bidder == msg.sender, "Not your offer");
        uint256 amt = current.amount;
        delete bestOffer[tokenId];
        (bool ok, ) = payable(msg.sender).call{value: amt}("");
        require(ok, "Refund failed");
        emit OfferCancelled(tokenId, msg.sender, amt);
    }

    function acceptBestOffer(uint256 tokenId, address referrer) external nonReentrant whenNotPaused {
        MarketItem storage m = idToMarketItem[tokenId];
        require(m.seller == msg.sender, "Not seller");
        Offer storage current = bestOffer[tokenId];
        require(current.amount > 0, "No offer");

        uint256 offerAmt = current.amount;
        address bidder = current.bidder;
        delete bestOffer[tokenId];

        // settle with offer amount
        _settleSaleAndTransfer(tokenId, offerAmt, referrer, bidder);
        emit OfferAccepted(tokenId, msg.sender, bidder, offerAmt);
    }

    // ========== AUCTIONS (English) ==========

    function createAuction(
        uint256 tokenId,
        uint256 startPrice,
        uint256 duration,
        address referrer
    ) external nonReentrant validTokenId(tokenId) whenNotPaused {
        require(duration >= MIN_AUCTION_DURATION, "Duration too short");
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        require(!auctions[tokenId].active, "Auction exists");
        require(!dutchAuctions[tokenId].active, "Dutch auction exists");

        _transfer(msg.sender, address(this), tokenId);

        auctions[tokenId] = Auction({
            active: true,
            tokenId: tokenId,
            seller: payable(msg.sender),
            startPrice: startPrice,
            highestBid: 0,
            highestBidder: payable(address(0)),
            endTime: block.timestamp + duration,
            referrer: referrer
        });

        // mark listing state
        MarketItem storage m = idToMarketItem[tokenId];
        m.tokenId = tokenId;
        m.seller = payable(msg.sender);
        m.isAuction = true;

        emit AuctionCreated(tokenId, startPrice, block.timestamp + duration);
    }

    function bid(uint256 tokenId) external payable nonReentrant whenNotPaused {
        Auction storage a = auctions[tokenId];
        require(a.active, "No auction");
        require(block.timestamp < a.endTime, "Auction ended");
        uint256 minNext = a.highestBid == 0 ? a.startPrice : (a.highestBid + ((a.highestBid * 500) / 10000)); // +5%
        require(msg.value >= minNext, "Bid too low");

        // Refund previous
        if (a.highestBid > 0) {
            (bool ok, ) = a.highestBidder.call{value: a.highestBid}("");
            require(ok, "Refund failed");
        }

        a.highestBid = msg.value;
        a.highestBidder = payable(msg.sender);

        // Anti-sniping
        if (a.endTime - block.timestamp < AUCTION_TIME_EXTENSION) {
            a.endTime = block.timestamp + AUCTION_TIME_EXTENSION;
        }

        emit AuctionBid(tokenId, msg.sender, msg.value);
    }

    function finalizeAuction(uint256 tokenId) external nonReentrant whenNotPaused {
        Auction storage a = auctions[tokenId];
        require(a.active, "No auction");
        require(block.timestamp >= a.endTime, "Not ended");

        a.active = false;

        if (a.highestBid == 0) {
            // return NFT to seller
            _transfer(address(this), a.seller, tokenId);
            delete auctions[tokenId];
            idToMarketItem[tokenId].isAuction = false;
            emit AuctionFinalized(tokenId, address(0), 0);
            return;
        }

        uint256 amount = a.highestBid;
        address winner = a.highestBidder;

        // settle sale (ETH only)
        _settleSaleAndTransfer(tokenId, amount, a.referrer, winner);

        delete auctions[tokenId];
        idToMarketItem[tokenId].isAuction = false;
        emit AuctionFinalized(tokenId, winner, amount);
    }

    // ───── NEW: cancel English auction if no bids ─────
    function cancelAuctionNoBids(uint256 tokenId) external nonReentrant {
        Auction storage a = auctions[tokenId];
        require(a.active, "No auction");
        require(a.seller == msg.sender, "Not seller");
        require(a.highestBid == 0, "Already has bids");
        a.active = false;
        _transfer(address(this), a.seller, tokenId);
        delete auctions[tokenId];
        idToMarketItem[tokenId].isAuction = false;
        emit AuctionCancelled(tokenId);
    }

    // ========== DUTCH AUCTIONS (NEW) ==========
    function createDutchAuction(
        uint256 tokenId,
        uint256 startPrice,
        uint256 endPrice,
        uint256 duration,
        address referrer,
        PaymentMethod payWith,
        address erc20
    ) external nonReentrant validTokenId(tokenId) whenNotPaused {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        require(!auctions[tokenId].active, "English auction exists");
        require(!dutchAuctions[tokenId].active, "Dutch exists");
        require(duration >= MIN_AUCTION_DURATION, "Duration too short");
        require(startPrice > endPrice, "startPrice must > endPrice");
        if (payWith == PaymentMethod.ERC20) {
            require(allowedERC20[erc20], "ERC20 not allowed");
        } else {
            require(erc20 == address(0), "ETH auction requires erc20=0");
        }

        _transfer(msg.sender, address(this), tokenId);

        dutchAuctions[tokenId] = DutchAuction({
            active: true,
            tokenId: tokenId,
            seller: payable(msg.sender),
            startPrice: startPrice,
            endPrice: endPrice,
            startTime: block.timestamp,
            duration: duration,
            referrer: referrer,
            payWith: payWith,
            erc20: erc20
        });

        emit DutchAuctionCreated(tokenId, startPrice, endPrice, block.timestamp, duration);
    }

    function currentDutchPrice(uint256 tokenId) public view returns (uint256) {
        DutchAuction memory d = dutchAuctions[tokenId];
        require(d.active, "No Dutch auction");
        if (block.timestamp >= d.startTime + d.duration) return d.endPrice;
        uint256 elapsed = block.timestamp - d.startTime;
        uint256 priceDrop = ((d.startPrice - d.endPrice) * elapsed) / d.duration;
        return d.startPrice - priceDrop;
    }

    function buyDutchAuction(uint256 tokenId) external payable nonReentrant whenNotPaused {
        DutchAuction storage d = dutchAuctions[tokenId];
        require(d.active, "No Dutch auction");
        uint256 price = currentDutchPrice(tokenId);

        if (d.payWith == PaymentMethod.ETH) {
            require(msg.value == price, "Incorrect ETH");
        } else {
            require(msg.value == 0, "ERC20 purchase is non-ETH");
            _collectERC20(d.erc20, msg.sender, price);
        }

        // Prepare MarketItem scaffold for settlement
        MarketItem storage m = idToMarketItem[tokenId];
        m.tokenId = tokenId;
        m.seller = d.seller;
        m.payWith = d.payWith;
        m.erc20 = d.erc20;

        // settle & transfer
        _settleSaleAndTransfer(tokenId, price, d.referrer, msg.sender);

        delete dutchAuctions[tokenId];
        emit DutchAuctionPurchased(tokenId, msg.sender, price, d.referrer);
    }

    // ========== MINTING & LAZY MINTING ==========

    function mintToken(
        string calldata tokenURI_,
        string calldata category,
        uint256 collectionId,
        address royaltyReceiver,
        uint96 royaltyBps
    ) public whenNotPaused returns (uint256) {
        require(royaltyBps <= MAX_ROYALTY, "Royalty too high");

        // ───── NEW: enforce collection supply & default royalty ─────
        if (collectionId != 0) {
            Collection storage col = idToCollection[collectionId];
            require(col.isActive, "Collection inactive");
            require(col.creator != address(0), "Collection not found");
            require(col.totalSupply < col.maxSupply, "Max supply reached");
            col.totalSupply += 1;

            // If caller didn't pass a royalty receiver, apply collection default
            if (royaltyReceiver == address(0) && col.royaltyReceiver != address(0) && col.royaltyBps > 0) {
                royaltyReceiver = col.royaltyReceiver;
                royaltyBps = col.royaltyBps;
            }
        }

        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();

        _safeMint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, tokenURI_);
        if (royaltyReceiver != address(0) && royaltyBps > 0) {
            _setTokenRoyalty(newTokenId, royaltyReceiver, royaltyBps);
        }

        userTokens[msg.sender].push(newTokenId);

        MarketItem storage m = idToMarketItem[newTokenId];
        m.tokenId = newTokenId;
        m.owner = payable(msg.sender);
        m.creator = payable(msg.sender);
        m.category = category;
        m.collectionId = collectionId;

        return newTokenId;
    }

    // ───── NEW: batch minting helper ─────
    function batchMintToken(
        string[] calldata tokenURIs,
        string calldata category,
        uint256 collectionId,
        address royaltyReceiver,
        uint96 royaltyBps
    ) external whenNotPaused returns (uint256[] memory mintedIds) {
        require(tokenURIs.length > 0, "No URIs");
        mintedIds = new uint256[](tokenURIs.length);
        for (uint256 i = 0; i < tokenURIs.length; i++) {
            mintedIds[i] = mintToken(tokenURIs[i], category, collectionId, royaltyReceiver, royaltyBps);
        }
    }

    // EIP-712 Lazy mint
    struct LazyMintVoucher {
        uint256 tokenId; // 0 means autoincrement
        uint256 price;
        string uri;
        address creator;
        uint256 nonce;
        uint256 expiry;
        bytes signature;
    }

    function lazyMint(LazyMintVoucher calldata v, address buyer, address referrer)
        external
        payable
        nonReentrant
        whenNotPaused
    {
        require(block.timestamp <= v.expiry, "Voucher expired");
        require(v.price > 0, "Price=0");

        bytes32 digest = _hashTypedDataV4(
            keccak256(abi.encode(_LAZY_MINT_TYPEHASH, v.tokenId, v.price, keccak256(bytes(v.uri)), v.creator, v.nonce, v.expiry))
        );
        address signer = ECDSA.recover(digest, v.signature);
        require(signer == v.creator, "Bad signature");

        // Avoid replay per-creator
        require(userNonce[v.creator] == v.nonce, "Bad nonce");
        userNonce[v.creator] += 1;

        if (msg.value != v.price) revert("Incorrect ETH sent");

        // Mint to this contract then settle to buyer
        uint256 tokenId = v.tokenId;
        if (tokenId == 0) {
            _tokenIds.increment();
            tokenId = _tokenIds.current();
        }
        _safeMint(address(this), tokenId);
        _setTokenURI(tokenId, v.uri);

        // set token creator
        MarketItem storage m = idToMarketItem[tokenId];
        m.creator = payable(v.creator);
        m.tokenId = tokenId;
        m.seller = payable(v.creator);
        m.price = v.price;

        // default royalty to creator 5%
        _setTokenRoyalty(tokenId, v.creator, 500);

        _settleSaleAndTransfer(tokenId, v.price, referrer, buyer);
        emit MarketItemSold(tokenId, v.creator, buyer, v.price, referrer);
    }

    // ========== ALLOWLIST MINT (Merkle) ==========

    function setAllowlistRoot(bytes32 root) external onlyOwner {
        allowlistRoot = root;
    }

    function allowlistMint(
        uint256 maxPerWallet,
        bytes32[] calldata proof,
        string calldata tokenURI_,
        uint256 collectionId
    ) external payable whenNotPaused {
        require(allowlistRoot != bytes32(0), "Allowlist off");
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, maxPerWallet));
        require(MerkleProof.verify(proof, allowlistRoot, leaf), "Not allowlisted");
        require(allowlistMinted[msg.sender] < maxPerWallet, "Wallet cap reached");
        require(msg.value >= listingPrice, "Fee");

        allowlistMinted[msg.sender] += 1;
        uint256 tokenId = mintToken(tokenURI_, "Art", collectionId, msg.sender, 500);
        platformFeeBalance += msg.value; // simple mint fee to platform
        // token goes to msg.sender via mintToken
    }

    // ========== VIRTUAL GALLERY ==========

    function createVirtualGallery(
        string calldata name,
        string calldata description,
        GalleryTheme theme,
        bool isPublic,
        uint256 entryFee
    ) external payable returns (uint256) {
        require(virtualGalleriesEnabled, "Galleries disabled");
        require(msg.value >= VIRTUAL_GALLERY_FEE, "Insufficient fee");
        require(bytes(name).length > 0, "Name empty");

        _virtualGalleryIds.increment();
        uint256 galleryId = _virtualGalleryIds.current();

        VirtualGallery storage g = idToVirtualGallery[galleryId];
        g.galleryId = galleryId;
        g.name = name;
        g.description = description;
        g.owner = msg.sender;
        g.createdAt = block.timestamp;
        g.theme = theme;
        g.isPublic = isPublic;
        g.entryFee = entryFee;
        g.totalVisits = 0;
        g.isActive = true;

        userVirtualGalleries[msg.sender].push(galleryId);
        platformFeeBalance += msg.value;

        emit VirtualGalleryCreated(galleryId, name, msg.sender);
        return galleryId;
    }

    function visitVirtualGallery(uint256 galleryId) external payable {
        VirtualGallery storage g = idToVirtualGallery[galleryId];
        require(g.isActive, "Inactive");

        if (!g.isPublic) {
            require(g.vipAccess[msg.sender] || msg.value >= g.entryFee, "No VIP or fee");
        }

        g.totalVisits++;
        g.visitHistory[msg.sender] = block.timestamp;

        if (msg.value > 0) {
            (bool sent, ) = g.owner.call{value: msg.value}("");
            require(sent, "Fee xfer fail");
        }

        emit VirtualGalleryVisited(galleryId, msg.sender, block.timestamp);
    }

    function exhibitTokenInGallery(uint256 galleryId, uint256 tokenId)
        external
        onlyGalleryOwner(galleryId)
        validTokenId(tokenId)
    {
        VirtualGallery storage g = idToVirtualGallery[galleryId];
        require(g.isActive, "Inactive");
        g.exhibitedTokenIds.push(tokenId);

        MarketItem storage m = idToMarketItem[tokenId];
        m.isInVirtualGallery = true;
        m.galleryIds.push(galleryId);

        emit TokenExhibited(galleryId, tokenId, msg.sender);
    }

    // ========== AI ART ==========

    function requestAIArtGeneration(string calldata prompt, string calldata style)
        external
        payable
        validAIGenerationRequest(prompt, style)
        returns (uint256)
    {
        require(aiArtGenerationEnabled, "AI gen disabled");
        require(msg.value >= AI_GENERATION_FEE, "Fee");

        _aiArtIds.increment();
        uint256 aiArtId = _aiArtIds.current();

        AIArtGeneration storage gen = idToAIArtGeneration[aiArtId];
        gen.aiArtId = aiArtId;
        gen.requester = msg.sender;
        gen.prompt = prompt;
        gen.style = style;
        gen.requestedAt = block.timestamp;
        gen.generationCost = msg.value;
        gen.isCompleted = false;
        gen.isMinted = false;
        gen.qualityScore = 0;
        gen.isPublic = true;

        userAIGenerations[msg.sender][today()]++;
        platformFeeBalance += msg.value;

        emit AIArtRequested(aiArtId, msg.sender, prompt, style);
        return aiArtId;
    }

    function completeAIArtGeneration(
        uint256 aiArtId,
        string calldata resultURI,
        uint256 qualityScore
    ) external onlyOwner {
        AIArtGeneration storage gen = idToAIArtGeneration[aiArtId];
        require(!gen.isCompleted, "Completed");
        require(qualityScore <= 100, "Bad score");

        gen.resultURI = resultURI;
        gen.completedAt = block.timestamp;
        gen.isCompleted = true;
        gen.qualityScore = qualityScore;

        if (qualityScore >= 70 && !gen.isMinted) {
            // mint to requester
            _tokenIds.increment();
            uint256 tokenId = _tokenIds.current();
            _safeMint(gen.requester, tokenId);
            _setTokenURI(tokenId, resultURI);

            MarketItem storage m = idToMarketItem[tokenId];
            m.tokenId = tokenId;
            m.owner = payable(gen.requester);
            m.creator = payable(address(this));
            m.isAIGenerated = true;

            gen.isMinted = true;
            emit AIArtGenerated(aiArtId, tokenId, resultURI);
        }
    }

    // ========== SUBSCRIPTIONS ==========

    function activateSubscription(uint256 tierId) external payable {
        SubscriptionTier memory tier = subscriptionTiers[tierId];
        require(tier.isActive, "Tier inactive");
        require(msg.value >= tier.monthlyFee, "Insufficient");

        UserSubscription storage s = userSubscriptions[msg.sender];
        s.tierId = tierId;
        s.startTime = block.timestamp;
        s.endTime = block.timestamp + SUBSCRIPTION_DURATION;
        s.isActive = true;
        s.currentTier = tier.level;
        s.totalSpent += msg.value;

        platformFeeBalance += msg.value;

        emit SubscriptionActivated(msg.sender, tierId, SUBSCRIPTION_DURATION);
    }

    function renewSubscription() external payable {
        UserSubscription storage s = userSubscriptions[msg.sender];
        require(s.isActive, "Inactive");

        SubscriptionTier memory tier = subscriptionTiers[s.tierId];
        require(msg.value >= tier.monthlyFee, "Insufficient");

        s.endTime += SUBSCRIPTION_DURATION;
        s.totalSpent += msg.value;

        platformFeeBalance += msg.value;
        emit SubscriptionRenewed(msg.sender, s.tierId, s.endTime);
    }

    // ========== LOYALTY PROGRAMS ==========

    function _awardLoyaltyPoints(address user, uint256 points, string memory action) internal {
        if (!loyaltyProgramEnabled) return;

        LoyaltyMember storage m = loyaltyMembers[user];
        if (!m.isActive) {
            m.memberAddress = user;
            m.joinedAt = block.timestamp;
            m.isActive = true;
            loyaltyPrograms[defaultLoyaltyProgramId].totalMembers++;
        }

        m.totalPoints += points;
        m.lastActivityAt = block.timestamp;
        emit LoyaltyPointsEarned(user, points, action);
    }

    function claimLoyaltyReward(string calldata rewardName, uint256 pointsCost) external nonReentrant {
        require(loyaltyProgramEnabled, "Disabled");
        LoyaltyMember storage m = loyaltyMembers[msg.sender];
        require(m.isActive && m.totalPoints >= pointsCost, "Not enough points");

        m.totalPoints -= pointsCost;

        // simple ETH cashback from platform pool based on program rate (scaled 1e18)
        uint256 rate = loyaltyPrograms[defaultLoyaltyProgramId].pointsToEtherRate; // e.g., 5e15 => 0.005 ETH per 1,000 pts if multiplied accordingly
        uint256 rebate = (pointsCost * rate) / 1e18;
        if (rebate > 0 && address(this).balance >= rebate && platformFeeBalance >= rebate) {
            platformFeeBalance -= rebate;
            (bool ok, ) = payable(msg.sender).call{value: rebate}("");
            require(ok, "Rebate transfer failed");
        }

        emit LoyaltyRewardClaimed(msg.sender, rewardName, pointsCost);
    }

    // ========== COLLECTIONS (NEW) ==========

    function createCollection(
        string calldata name,
        string calldata description,
        uint256 maxSupply,
        uint96 royaltyBps,
        address royaltyReceiver,
        string calldata logoURI,
        string calldata bannerURI
    ) external returns (uint256) {
        require(bytes(name).length > 0, "Name empty");
        require(maxSupply > 0, "maxSupply=0");
        require(royaltyBps <= MAX_ROYALTY, "Royalty too high");

        _collectionIds.increment();
        uint256 collectionId = _collectionIds.current();

        idToCollection[collectionId] = Collection({
            collectionId: collectionId,
            name: name,
            description: description,
            creator: msg.sender,
            totalSupply: 0,
            maxSupply: maxSupply,
            royaltyBps: royaltyBps,
            royaltyReceiver: royaltyReceiver,
            isVerified: false,
            logoURI: logoURI,
            bannerURI: bannerURI,
            floorPrice: 0,
            totalVolume: 0,
            isActive: true
        });

        emit CollectionCreated(collectionId, name, msg.sender);
        return collectionId;
    }

    function setCollectionRoyalty(uint256 collectionId, address receiver, uint96 bps) external {
        Collection storage col = idToCollection[collectionId];
        require(col.creator == msg.sender || msg.sender == owner(), "Not collection owner");
        require(col.isActive, "Collection inactive");
        require(bps <= MAX_ROYALTY, "Royalty too high");
        col.royaltyReceiver = receiver;
        col.royaltyBps = bps;
        emit CollectionRoyaltyUpdated(collectionId, receiver, bps);
    }

    // ========== ADMIN / CONFIG ==========

    function setPlatformFee(uint256 bps) external onlyOwner {
        require(bps <= MAX_PLATFORM_FEE, "Fee too high");
        platformFee = bps;
    }

    function setReferralBps(uint256 bps) external onlyOwner {
        require(bps <= 5000, "Max 50% of platform fee");
        referralBps = bps;
    }

    function setListingPrice(uint256 priceWei) external onlyOwner {
        listingPrice = priceWei;
    }

    function setDefaultRoyalty(address receiver, uint96 bps) external onlyOwner {
        require(bps <= MAX_ROYALTY, "Royalty too high");
        _setDefaultRoyalty(receiver, bps);
    }

    function allowERC20(address token, bool allowed) external onlyOwner {
        allowedERC20[token] = allowed;
    }

    function setAIPricingOracle(address oracle, bool authorize) external onlyOwner {
        aiPricingOracle = oracle;
        authorizedAIOracles[oracle] = authorize;
    }

    function withdrawPlatformFees(address payable to, uint256 amount) external onlyOwner {
        require(amount <= platformFeeBalance, "Exceeds balance");
        platformFeeBalance -= amount;
        (bool ok, ) = to.call{value: amount}("");
        require(ok, "Withdraw fail");
    }

    // ───── NEW: withdraw ERC20 platform fees (any allowed token) ─────
    function withdrawERC20PlatformFees(address token, address to, uint256 amount) external onlyOwner {
        require(IERC20(token).transfer(to, amount), "ERC20 withdraw fail");
    }

    function payReferral(address payable referrer, uint256 amount) external onlyOwner {
        require(referralEarnings[referrer] >= amount, "Insufficient earned");
        referralEarnings[referrer] -= amount;
        (bool ok, ) = referrer.call{value: amount}("");
        require(ok, "Referral pay fail");
    }

    function rescueETH(address payable to, uint256 amount) external onlyOwner {
        (bool ok, ) = to.call{value: amount}("");
        require(ok, "Rescue fail");
    }

    function rescueERC20(address token, address to, uint256 amount) external onlyOwner {
        require(IERC20(token).transfer(to, amount), "Rescue ERC20 fail");
    }

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    // ───── NEW: manage categories ─────
    function setCategory(string calldata category, bool isValid) external onlyOwner {
        validCategories[category] = isValid;
        emit CategoryUpdated(category, isValid);
    }

    // ========== HELPERS ==========

    function today() internal view returns (uint256) {
        return block.timestamp / 1 days;
    }

    function _createDefaultLoyaltyProgram() internal {
        _loyaltyProgramIds.increment();
        uint256 id = _loyaltyProgramIds.current();
        loyaltyPrograms[id] = LoyaltyProgram({
            programId: id,
            name: "Default",
            isActive: true,
            totalMembers: 0,
            pointsToEtherRate: 5e13 // 0.00005 ETH per 1,000 pts (example)
        });
        defaultLoyaltyProgramId = id;
    }

    function _createDefaultSubscriptionTiers() internal {
        _subscriptionTierIds.increment();
        subscriptionTiers[1] = SubscriptionTier({
            tierId: 1,
            name: "Basic",
            monthlyFee: 0,
            level: SubscriptionTierLevel.Basic,
            maxListings: 10,
            maxAIGenerations: 5,
            enablePrioritySupport: false,
            enableAnalytics: false,
            enableCustomGalleries: false,
            enableCrossChain: false,
            discountPercentage: 0,
            isActive: true
        });

        _subscriptionTierIds.increment();
        subscriptionTiers[2] = SubscriptionTier({
            tierId: 2,
            name: "Premium",
            monthlyFee: PREMIUM_SUBSCRIPTION_FEE,
            level: SubscriptionTierLevel.Premium,
            maxListings: 100,
            maxAIGenerations: 50,
            enablePrioritySupport: true,
            enableAnalytics: true,
            enableCustomGalleries: true,
            enableCrossChain: true,
            discountPercentage: 500, // 5%
            isActive: true
        });
    }

    function _collectERC20(address token, address from, uint256 amount) internal {
        require(allowedERC20[token], "ERC20 not allowed");
        require(IERC20(token).transferFrom(from, address(this), amount), "ERC20 transferFrom fail");
    }

    // ========== OVERRIDES ==========

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // Receive ETH
    receive() external payable {}
}
