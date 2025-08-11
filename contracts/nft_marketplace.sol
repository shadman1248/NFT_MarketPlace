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
    uint256 public platformFee = 250; // 2.5%
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

    // ========== ENUMS ==========
    enum PricingType { Conservative, Balanced, Aggressive, Momentum, Contrarian, ValueBased, Technical }
    enum PaymentMethod { ETH, ERC20, Crypto, Fiat }
    enum BridgeStatus { Pending, InProgress, Completed, Failed, Cancelled }
    enum GalleryTheme { Modern, Classic, Cyberpunk, Nature, Abstract }
    enum SubscriptionTierLevel { Basic, Premium, Professional, Enterprise }

    // ========== STRUCTS ==========
    
    struct Vector3 {
        int256 x;
        int256 y;
        int256 z;
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
    }

    struct Collection {
        uint256 collectionId;
        string name;
        string description;
        address creator;
        uint256 totalSupply;
        uint256 maxSupply;
        uint256 royaltyPercentage;
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
        uint256 discountPercentage;
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

    // ========== EIP-712 TYPE HASHES ==========
    bytes32 private constant _LAZY_MINT_TYPEHASH = 
        keccak256("LazyMintVoucher(uint256 tokenId,uint256 price,string uri,address creator,uint256 nonce,uint256 expiry)");
    bytes32 private constant _CROSS_CHAIN_TYPEHASH =
        keccak256("CrossChainTransfer(uint256 tokenId,uint256 targetChain,address targetAddress,uint256 nonce,uint256 expiry)");
    bytes32 private constant _AI_GENERATION_TYPEHASH =
        keccak256("AIGeneration(address user,string prompt,string style,uint256 nonce,uint256 expiry)");
    bytes32 private constant _AI_PRICING_TYPEHASH =
        keccak256("AIPricingUpdate(uint256 tokenId,uint256 newPrice,uint256 confidence,uint256 timestamp,uint256 nonce)");

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
    event MarketItemCreated(uint256 indexed tokenId, address seller, address owner, uint256 price, bool sold, string category);
    event MarketItemSold(uint256 indexed tokenId, address seller, address buyer, uint256 price, address indexed referrer);
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
        require(userSubscriptions[msg.sender].isActive && 
                userSubscriptions[msg.sender].currentTier >= SubscriptionTierLevel.Premium, 
                "Premium subscription required");
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
        require(msg.sender == aiPricingOracle || msg.sender == owner() || authorizedAIOracles[msg.sender], 
                "Not authorized for AI pricing");
        _;
    }

    modifier validPricingUpdate(uint256 tokenId, uint256 newPrice, uint256 confidence) {
        require(newPrice > 0, "Price must be positive");
        require(confidence >= PRICING_CONFIDENCE_THRESHOLD, "Confidence too low");
        require(idToDynamicPricing[tokenId].isActive, "Dynamic pricing not active");
        _;
    }

    // ========== CONSTRUCTOR ==========
    constructor() ERC721("NFT Marketplace", "NFTM") EIP712("NFTMarketplace", "1") {
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

        // Create default loyalty program
        _createDefaultLoyaltyProgram();
        
        // Create default subscription tiers
        _createDefaultSubscriptionTiers();
    }

    // ========== CORE MARKETPLACE FUNCTIONS ==========

    function createMarketItem(
        uint256 tokenId,
        uint256 price,
        string memory category,
        uint256 collectionId
    ) public nonReentrant validTokenId(tokenId) {
        require(price > 0, "Price must be greater than 0");
        require(validCategories[category], "Invalid category");
        require(ownerOf(tokenId) == msg.sender, "Not token owner");

        idToMarketItem[tokenId] = MarketItem({
            tokenId: tokenId,
            seller: payable(msg.sender),
            owner: payable(address(0)),
            creator: payable(msg.sender),
            price: price,
            createdAt: block.timestamp,
            expiresAt: 0,
            sold: false,
            isAuction: false,
            category: category,
            collectionId: collectionId,
            views: 0,
            likes: 0,
            isExclusive: false,
            unlockableContentHash: bytes32(0),
            collaborators: new address[](0),
            collaboratorShares: new uint256[](0),
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
            aiPricingId: 0,
            isGameAsset: false,
            gameAssetId: 0,
            isInVirtualGallery: false,
            galleryIds: new uint256[](0),
            crossChainEnabled: false,
            supportedChainIds: new uint256[](0)
        });

        _transfer(msg.sender, address(this), tokenId);

        emit MarketItemCreated(tokenId, msg.sender, address(0), price, false, category);
    }

    function createMarketSale(uint256 tokenId) public payable nonReentrant validTokenId(tokenId) {
        uint256 price = idToMarketItem[tokenId].price;
        address seller = idToMarketItem[tokenId].seller;
        
        require(msg.value == price, "Incorrect payment amount");
        require(!idToMarketItem[tokenId].sold, "Item already sold");

        // Calculate platform fee
        uint256 platformFeeAmount = (price * platformFee) / 10000;
        uint256 sellerAmount = price - platformFeeAmount;

        // Transfer payment to seller
        (bool sellerPaid, ) = seller.call{value: sellerAmount}("");
        require(sellerPaid, "Payment to seller failed");

        // Store platform fee
        platformFeeBalance += platformFeeAmount;

        // Transfer token to buyer
        _transfer(address(this), msg.sender, tokenId);
        idToMarketItem[tokenId].owner = payable(msg.sender);
        idToMarketItem[tokenId].sold = true;
        _itemsSold.increment();

        // Award loyalty points
        if (loyaltyProgramEnabled) {
            _awardLoyaltyPoints(msg.sender, price / 1e16, "PURCHASE"); // 1 point per 0.01 ETH
        }

        emit MarketItemSold(tokenId, seller, msg.sender, price, address(0));
    }

    // ========== MINTING FUNCTIONS ==========

    function mintToken(
        string memory tokenURI,
        string memory category,
        uint256 collectionId
    ) public returns (uint256) {
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();

        _safeMint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, tokenURI);

        // Add to user tokens
        userTokens[msg.sender].push(newTokenId);

        // Initialize market item
        idToMarketItem[newTokenId] = MarketItem({
            tokenId: newTokenId,
            seller: payable(address(0)),
            owner: payable(msg.sender),
            creator: payable(msg.sender),
            price: 0,
            createdAt: block.timestamp,
            expiresAt: 0,
            sold: false,
            isAuction: false,
            category: category,
            collectionId: collectionId,
            views: 0,
            likes: 0,
            isExclusive: false,
            unlockableContentHash: bytes32(0),
            collaborators: new address[](0),
            collaboratorShares: new uint256[](0),
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
            aiPricingId: 0,
            isGameAsset: false,
            gameAssetId: 0,
            isInVirtualGallery: false,
            galleryIds: new uint256[](0),
            crossChainEnabled: false,
            supportedChainIds: new uint256[](0)
        });

        return newTokenId;
    }

    // ========== VIRTUAL GALLERY FUNCTIONS ==========

    function createVirtualGallery(
        string memory name,
        string memory description,
        GalleryTheme theme,
        bool isPublic,
        uint256 entryFee
    ) external payable returns (uint256) {
        require(virtualGalleriesEnabled, "Virtual galleries disabled");
        require(msg.value >= VIRTUAL_GALLERY_FEE, "Insufficient fee");
        require(bytes(name).length > 0, "Name cannot be empty");

        _virtualGalleryIds.increment();
        uint256 galleryId = _virtualGalleryIds.current();

        VirtualGallery storage gallery = idToVirtualGallery[galleryId];
        gallery.galleryId = galleryId;
        gallery.name = name;
        gallery.description = description;
        gallery.owner = msg.sender;
        gallery.createdAt = block.timestamp;
        gallery.theme = theme;
        gallery.isPublic = isPublic;
        gallery.entryFee = entryFee;
        gallery.totalVisits = 0;
        gallery.isActive = true;

        userVirtualGalleries[msg.sender].push(galleryId);
        platformFeeBalance += msg.value;

        emit VirtualGalleryCreated(galleryId, name, msg.sender);
        return galleryId;
    }

    function visitVirtualGallery(uint256 galleryId) external payable {
        VirtualGallery storage gallery = idToVirtualGallery[galleryId];
        require(gallery.isActive, "Gallery not active");
        
        if (!gallery.isPublic) {
            require(gallery.vipAccess[msg.sender] || msg.value >= gallery.entryFee, 
                   "Access denied or insufficient entry fee");
        }

        gallery.totalVisits++;
        gallery.visitHistory[msg.sender] = block.timestamp;

        if (msg.value > 0) {
            // Transfer entry fee to gallery owner
            (bool sent, ) = gallery.owner.call{value: msg.value}("");
            require(sent, "Fee transfer failed");
        }

        emit VirtualGalleryVisited(galleryId, msg.sender, block.timestamp);
    }

    function exhibitTokenInGallery(uint256 galleryId, uint256 tokenId) 
        external onlyGalleryOwner(galleryId) validTokenId(tokenId) {
        
        VirtualGallery storage gallery = idToVirtualGallery[galleryId];
        require(gallery.isActive, "Gallery not active");

        gallery.exhibitedTokenIds.push(tokenId);
        idToMarketItem[tokenId].isInVirtualGallery = true;
        idToMarketItem[tokenId].galleryIds.push(galleryId);

        emit TokenExhibited(galleryId, tokenId, msg.sender);
    }

    // ========== AI ART GENERATION FUNCTIONS ==========

    function requestAIArtGeneration(
        string memory prompt,
        string memory style
    ) external payable validAIGenerationRequest(prompt, style) returns (uint256) {
        require(aiArtGenerationEnabled, "AI art generation disabled");
        require(msg.value >= AI_GENERATION_FEE, "Insufficient generation fee");

        _aiArtIds.increment();
        uint256 aiArtId = _aiArtIds.current();

        AIArtGeneration storage generation = idToAIArtGeneration[aiArtId];
        generation.aiArtId = aiArtId;
        generation.requester = msg.sender;
        generation.prompt = prompt;
        generation.style = style;
        generation.requestedAt = block.timestamp;
        generation.generationCost = msg.value;
        generation.isCompleted = false;
        generation.isMinted = false;
        generation.qualityScore = 0;
        generation.isPublic = true;

        // Increment daily generation count
        userAIGenerations[msg.sender][today()]++;

        platformFeeBalance += msg.value;

        emit AIArtRequested(aiArtId, msg.sender, prompt, style);
        return aiArtId;
    }

    function completeAIArtGeneration(
        uint256 aiArtId,
        string memory resultURI,
        uint256 qualityScore
    ) external onlyOwner {
        AIArtGeneration storage generation = idToAIArtGeneration[aiArtId];
        require(!generation.isCompleted, "Already completed");
        require(qualityScore <= 100, "Invalid quality score");

        generation.resultURI = resultURI;
        generation.completedAt = block.timestamp;
        generation.isCompleted = true;
        generation.qualityScore = qualityScore;

        // Auto-mint if quality score is high enough
        if (qualityScore >= 70 && !generation.isMinted) {
            uint256 tokenId = mintToken(resultURI, "Art", 0);
            idToMarketItem[tokenId].isAIGenerated = true;
            generation.isMinted = true;
            
            // Transfer to requester
            _transfer(address(this), generation.requester, tokenId);
            
            emit AIArtGenerated(aiArtId, tokenId, resultURI);
        }
    }

    // ========== SUBSCRIPTION FUNCTIONS ==========

    function activateSubscription(uint256 tierId) external payable {
        SubscriptionTier memory tier = subscriptionTiers[tierId];
        require(tier.isActive, "Subscription tier not active");
        require(msg.value >= tier.monthlyFee, "Insufficient payment");

        UserSubscription storage subscription = userSubscriptions[msg.sender];
        subscription.tierId = tierId;
        subscription.startTime = block.timestamp;
        subscription.endTime = block.timestamp + SUBSCRIPTION_DURATION;
        subscription.isActive = true;
        subscription.currentTier = tier.level;
        subscription.totalSpent += msg.value;

        platformFeeBalance += msg.value;

        emit SubscriptionActivated(msg.sender, tierId, SUBSCRIPTION_DURATION);
    }

    function renewSubscription() external payable {
        UserSubscription storage subscription = userSubscriptions[msg.sender];
        require(subscription.isActive, "No active subscription");
        
        SubscriptionTier memory tier = subscriptionTiers[subscription.tierId];
        require(msg.value >= tier.monthlyFee, "Insufficient payment");

        subscription.endTime += SUBSCRIPTION_DURATION;
        subscription.totalSpent += msg.value;

        platformFeeBalance += msg.value;

        emit SubscriptionRenewed(msg.sender, subscription.tierId, subscription.endTime);
    }

    // ========== LOYALTY PROGRAM FUNCTIONS ==========

    function _awardLoyaltyPoints(address user, uint256 points, string memory action) internal {
        if (!loyaltyProgramEnabled) return;

        LoyaltyMember storage member = loyaltyMembers[user];
        if (!member.isActive) {
            member.memberAddress = user;
            member.joinedAt = block.timestamp;
            member.isActive = true;
            loyaltyPrograms[defaultLoyaltyProgramId].totalMembers++;
        }

        member.totalPoints += points;
        member.lastActivityAt = block.timestamp;

        emit LoyaltyPointsEarned(user, points, action);
    }

    function claimLoyaltyReward(string memory rewardName, uint256 pointsCost) external {
        require(loyaltyProgramEnabled, "Loyalty program disabled");
        
        LoyaltyMember storage member = loyaltyMembers[msg.sender];
        require(member.isActive,
