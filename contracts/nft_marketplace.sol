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

contract NFTMarketplace is ERC721URIStorage, ReentrancyGuard, Ownable, Pausable, EIP712 {
    using Counters for Counters.Counter;
    using ECDSA for bytes32;

    Counters.Counter private _tokenIds;
    Counters.Counter private _itemsSold;
    Counters.Counter private _collectionIds;
    Counters.Counter private _bundleIds;
    Counters.Counter private _subscriptionIds;
    Counters.Counter private _lotteryIds;
    Counters.Counter private _affiliateIds;
    Counters.Counter private _dropIds;

    uint256 public listingPrice = 0.025 ether;
    uint256 public royaltyPercentage = 250; // 2.5%
    uint256 public platformFee = 250; // 2.5%
    uint256 public minStakeAmount = 1 ether;
    uint256 public stakingRewardRate = 500; // 5% annually
    uint256 public constant SECONDS_PER_YEAR = 365 * 24 * 60 * 60;
    uint256 public constant MAX_ROYALTY = 1000; // 10% max royalty

    // NEW: Domain separator for EIP-712
    bytes32 private constant _LAZY_MINT_TYPEHASH = 
        keccak256("LazyMintVoucher(uint256 tokenId,uint256 price,string uri,address creator,uint256 nonce,uint256 expiry)");

    constructor() ERC721("NFT Marketplace", "NFTM") Ownable(msg.sender) EIP712("NFTMarketplace", "1") {
        validCategories["Art"] = true;
        validCategories["Music"] = true;
        validCategories["Photography"] = true;
        validCategories["Gaming"] = true;
        validCategories["Sports"] = true;
        validCategories["Collectibles"] = true;
        validCategories["Utility"] = true;
        validCategories["Metaverse"] = true;
    }

    modifier onlyValidCategory(string memory category) {
        require(validCategories[category], "Invalid category");
        _;
    }

    modifier onlyTokenOwner(uint256 tokenId) {
        require(ownerOf(tokenId) == msg.sender, "Not token owner");
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
    }

    // NEW: Advanced Auction with multiple bid types
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
        uint256 decrementAmount; // For Dutch auctions
        uint256 decrementInterval; // For Dutch auctions
        bool allowBuyNow;
        uint256 buyNowPrice;
    }

    enum AuctionType { English, Dutch, Sealed }

    // NEW: NFT Drop System
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
    }

    // NEW: Affiliate System
    struct Affiliate {
        uint256 affiliateId;
        address affiliateAddress;
        uint256 commissionRate; // Basis points (100 = 1%)
        uint256 totalEarnings;
        uint256 totalReferrals;
        bool isActive;
        uint256 tier; // 1: Bronze, 2: Silver, 3: Gold, 4: Platinum
    }

    // NEW: Dynamic Pricing
    struct DynamicPricing {
        uint256 tokenId;
        uint256 basePrice;
        uint256 currentPrice;
        uint256 priceIncrement;
        uint256 lastSaleTime;
        uint256 demandMultiplier;
        bool isActive;
    }

    // NEW: Cross-chain Bridge Support
    struct BridgeRequest {
        uint256 tokenId;
        address owner;
        uint256 targetChain;
        string targetAddress;
        uint256 timestamp;
        bool completed;
        bytes32 txHash;
    }

    // NEW: NFT Insurance
    struct Insurance {
        uint256 tokenId;
        address insured;
        uint256 coverageAmount;
        uint256 premium;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        string[] coveredRisks;
    }

    // NEW: Advanced Staking with multiple pools
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
    }

    struct UserStake {
        uint256 amount;
        uint256 stakingTime;
        uint256 lastRewardClaim;
        uint256 totalRewards;
        uint256 lockEndTime;
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

    mapping(address => bool) private verifiedCreators;
    mapping(string => bool) private validCategories;
    mapping(address => uint256) private creatorEarnings;
    mapping(address => bool) private bannedUsers;
    mapping(address => uint256) private userNonce;
    mapping(address => address) private referrals; // user -> referrer
    mapping(address => uint256[]) private userCollections;
    mapping(uint256 => uint256[]) private collectionPriceHistory;
    mapping(address => mapping(uint256 => bool)) private userVotedForCollection;

    // NEW: Multi-signature wallet support
    mapping(address => bool) private multisigWallets;
    mapping(uint256 => mapping(address => bool)) private tokenApprovals; // token -> approver -> approved

    // NEW: Governance
    mapping(address => uint256) private votingPower;
    mapping(uint256 => Proposal) private proposals;
    mapping(uint256 => mapping(address => bool)) private hasVoted;
    Counters.Counter private _proposalIds;

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
    }

    enum ProposalType { FeeChange, CategoryAdd, FeatureToggle, Emergency }

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

    // ========== Core Functions ==========
    
    function createToken(string memory tokenURI, uint256 price, string memory category) 
        public payable nonReentrant onlyValidCategory(category) whenNotPaused notBanned {
        require(msg.value == listingPrice, "Must pay listing price");
        
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();

        _mint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, tokenURI);
        createMarketItem(newTokenId, price, category);
        
        lastActivityTime[msg.sender] = block.timestamp;
    }

    function createMarketItem(uint256 tokenId, uint256 price, string memory category) 
        private onlyValidCategory(category) {
        require(price > 0, "Price must be positive");

        idToMarketItem[tokenId] = MarketItem(
            tokenId,
            payable(msg.sender),
            payable(address(this)),
            payable(msg.sender),
            price,
            block.timestamp,
            0,
            false,
            false,
            category,
            0,
            0,
            0,
            false,
            0,
            new address[](0),
            new uint256[](0),
            false,
            1,
            1
        );

        _transfer(msg.sender, address(this), tokenId);
        emit MarketItemCreated(tokenId, msg.sender, address(this), price, false, category);
    }

    function buyToken(uint256 tokenId, address referrer) public payable nonReentrant whenNotPaused notBanned {
        uint256 price = idToMarketItem[tokenId].price;
        address seller = idToMarketItem[tokenId].seller;
        address creator = idToMarketItem[tokenId].creator;
        
        require(msg.value == price, "Submit asking price");
        require(seller != msg.sender, "Cannot buy your own NFT");

        // Handle dynamic pricing
        if (idToDynamicPricing[tokenId].isActive) {
            updateDynamicPrice(tokenId);
        }

        // Calculate fees including affiliate commission
        uint256 affiliateCommission = 0;
        if (referrer != address(0) && referrals[msg.sender] == address(0)) {
            referrals[msg.sender] = referrer;
            affiliateCommission = calculateAffiliateCommission(price, referrer);
        }

        uint256 platformFeeAmount = (price * platformFee) / 10000;
        uint256 royaltyAmount = (price * royaltyPercentage) / 10000;
        uint256 sellerAmount = price - platformFeeAmount - royaltyAmount - affiliateCommission;

        // Transfer payments
        idToMarketItem[tokenId].seller.transfer(sellerAmount);
        
        if (creator != seller) {
            payable(creator).transfer(royaltyAmount);
            creatorEarnings[creator] += royaltyAmount;
        }

        if (affiliateCommission > 0) {
            payable(referrer).transfer(affiliateCommission);
            emit CommissionPaid(referrer, affiliateCommission, tokenId);
        }

        _transfer(address(this), msg.sender, tokenId);
        idToMarketItem[tokenId].owner = payable(msg.sender);
        idToMarketItem[tokenId].sold = true;
        _itemsSold.increment();

        emit MarketItemSold(tokenId, seller, msg.sender, price, referrer);
    }

    // ========== NEW: NFT Drop System ==========
    
    function createDrop(
        string memory name,
        string memory description,
        uint256 maxSupply,
        uint256 price,
        uint256 maxPerWallet,
        uint256 startTime,
        uint256 endTime,
        string memory baseURI,
        bool isWhitelistOnly
    ) public onlyVerifiedCreator returns (uint256) {
        require(maxSupply > 0, "Max supply must be positive");
        require(price > 0, "Price must be positive");
        require(endTime > startTime, "Invalid time range");
        require(startTime > block.timestamp, "Start time must be future");

        _dropIds.increment();
        uint256 dropId = _dropIds.current();

        Drop storage newDrop = idToDrop[dropId];
        newDrop.dropId = dropId;
        newDrop.name = name;
        newDrop.description = description;
        newDrop.creator = msg.sender;
        newDrop.startTime = startTime;
        newDrop.endTime = endTime;
        newDrop.maxSupply = maxSupply;
        newDrop.price = price;
        newDrop.maxPerWallet = maxPerWallet;
        newDrop.isWhitelistOnly = isWhitelistOnly;
        newDrop.baseURI = baseURI;
        newDrop.isActive = true;

        emit DropCreated(dropId, name, msg.sender, maxSupply);
        return dropId;
    }

    function mintFromDrop(uint256 dropId, uint256 quantity) public payable nonReentrant notBanned {
        Drop storage drop = idToDrop[dropId];
        require(drop.isActive, "Drop not active");
        require(block.timestamp >= drop.startTime, "Drop not started");
        require(block.timestamp <= drop.endTime, "Drop ended");
        require(quantity > 0, "Quantity must be positive");
        require(drop.currentSupply + quantity <= drop.maxSupply, "Exceeds max supply");
        require(drop.purchased[msg.sender] + quantity <= drop.maxPerWallet, "Exceeds max per wallet");

        if (drop.isWhitelistOnly) {
            require(drop.whitelist[msg.sender], "Not whitelisted");
        }

        uint256 totalCost = drop.price * quantity;
        require(msg.value == totalCost, "Incorrect payment");

        // Mint tokens
        for (uint256 i = 0; i < quantity; i++) {
            _tokenIds.increment();
            uint256 tokenId = _tokenIds.current();
            
            _mint(msg.sender, tokenId);
            string memory tokenURI = string(abi.encodePacked(drop.baseURI, "/", toString(tokenId)));
            _setTokenURI(tokenId, tokenURI);
            
            drop.currentSupply++;
        }

        drop.purchased[msg.sender] += quantity;

        // Pay creator (minus platform fee)
        uint256 platformFeeAmount = (totalCost * platformFee) / 10000;
        uint256 creatorAmount = totalCost - platformFeeAmount;
        payable(drop.creator).transfer(creatorAmount);

        emit DropMinted(dropId, msg.sender, quantity, totalCost);
    }

    function addToWhitelist(uint256 dropId, address[] memory addresses) public {
        Drop storage drop = idToDrop[dropId];
        require(drop.creator == msg.sender, "Not drop creator");
        
        for (uint256 i = 0; i < addresses.length; i++) {
            drop.whitelist[addresses[i]] = true;
        }
    }

    // ========== NEW: Affiliate System ==========
    
    function registerAffiliate(uint256 commissionRate) public returns (uint256) {
        require(commissionRate <= 500, "Commission rate too high"); // Max 5%
        require(commissionRate > 0, "Commission rate must be positive");

        _affiliateIds.increment();
        uint256 affiliateId = _affiliateIds.current();

        idToAffiliate[affiliateId] = Affiliate({
            affiliateId: affiliateId,
            affiliateAddress: msg.sender,
            commissionRate: commissionRate,
            totalEarnings: 0,
            totalReferrals: 0,
            isActive: true,
            tier: 1
        });

        emit AffiliateRegistered(affiliateId, msg.sender, commissionRate);
        return affiliateId;
    }

    function calculateAffiliateCommission(uint256 salePrice, address affiliate) internal view returns (uint256) {
        // Find affiliate by address
        for (uint256 i = 1; i <= _affiliateIds.current(); i++) {
            if (idToAffiliate[i].affiliateAddress == affiliate && idToAffiliate[i].isActive) {
                return (salePrice * idToAffiliate[i].commissionRate) / 10000;
            }
        }
        return 0;
    }

    // ========== NEW: Dynamic Pricing ==========
    
    function enableDynamicPricing(uint256 tokenId, uint256 basePrice, uint256 priceIncrement) public onlyTokenOwner(tokenId) {
        require(basePrice > 0, "Base price must be positive");
        require(priceIncrement > 0, "Price increment must be positive");

        idToDynamicPricing[tokenId] = DynamicPricing({
            tokenId: tokenId,
            basePrice: basePrice,
            currentPrice: basePrice,
            priceIncrement: priceIncrement,
            lastSaleTime: 0,
            demandMultiplier: 100, // 1x multiplier initially
            isActive: true
        });

        idToMarketItem[tokenId].price = basePrice;
    }

    function updateDynamicPrice(uint256 tokenId) internal {
        DynamicPricing storage pricing = idToDynamicPricing[tokenId];
        if (!pricing.isActive) return;

        // Increase price based on demand and time since last sale
        uint256 timeSinceLastSale = block.timestamp - pricing.lastSaleTime;
        if (timeSinceLastSale < 1 hours) {
            // High demand - increase price
            pricing.currentPrice += pricing.priceIncrement;
            pricing.demandMultiplier += 10; // Increase multiplier
        } else if (timeSinceLastSale > 7 days) {
            // Low demand - decrease price gradually
            if (pricing.currentPrice > pricing.basePrice) {
                pricing.currentPrice = (pricing.currentPrice * 95) / 100; // 5% decrease
            }
        }

        pricing.lastSaleTime = block.timestamp;
        idToMarketItem[tokenId].price = pricing.currentPrice;
        
        emit DynamicPriceUpdated(tokenId, idToMarketItem[tokenId].price, pricing.currentPrice);
    }

    // ========== NEW: Advanced Staking Pools ==========
    
    function createStakingPool(
        string memory name,
        uint256 rewardRate,
        uint256 lockPeriod,
        uint256 maxStake,
        address rewardTokenAddress
    ) public onlyOwner returns (uint256) {
        _stakingPoolIds.increment();
        uint256 poolId = _stakingPoolIds.current();

        StakingPool storage pool = idToStakingPool[poolId];
        pool.poolId = poolId;
        pool.name = name;
        pool.rewardRate = rewardRate;
        pool.lockPeriod = lockPeriod;
        pool.maxStake = maxStake;
        pool.isActive = true;
        pool.rewardToken = IERC20(rewardTokenAddress);

        emit StakingPoolCreated(poolId, name, rewardRate);
        return poolId;
    }

    function stakeInPool(uint256 poolId) public payable nonReentrant {
        StakingPool storage pool = idToStakingPool[poolId];
        require(pool.isActive, "Pool not active");
        require(msg.value > 0, "Must stake positive amount");
        require(pool.totalStaked + msg.value <= pool.maxStake, "Exceeds pool max stake");

        UserStake storage userStake = pool.userStakes[msg.sender];
        
        // Claim pending rewards before updating stake
        if (userStake.amount > 0) {
            claimStakingRewards(poolId);
        }

        userStake.amount += msg.value;
        userStake.stakingTime = block.timestamp;
        userStake.lockEndTime = block.timestamp + pool.lockPeriod;
        userStake.lastRewardClaim = block.timestamp;
        
        pool.totalStaked += msg.value;

        emit TokensStaked(msg.sender, poolId, msg.value);
    }

    function claimStakingRewards(uint256 poolId) public nonReentrant {
        StakingPool storage pool = idToStakingPool[poolId];
        UserStake storage userStake = pool.userStakes[msg.sender];
        
        require(userStake.amount > 0, "No stake found");
        
        uint256 timeStaked = block.timestamp - userStake.lastRewardClaim;
        uint256 reward = (userStake.amount * pool.rewardRate * timeStaked) / (10000 * SECONDS_PER_YEAR);
        
        if (reward > 0) {
            userStake.totalRewards += reward;
            userStake.lastRewardClaim = block.timestamp;
            
            // Transfer reward tokens
            require(pool.rewardToken.transfer(msg.sender, reward), "Reward transfer failed");
            
            emit RewardsClaimed(msg.sender, poolId, reward);
        }
    }

    // ========== NEW: Cross-chain Bridge ==========
    
    function initiateBridge(uint256 tokenId, uint256 targetChain, string memory targetAddress) 
        public onlyTokenOwner(tokenId) {
        require(targetChain != block.chainid, "Cannot bridge to same chain");
        require(bytes(targetAddress).length > 0, "Target address required");

        // Lock the NFT
        _transfer(msg.sender, address(this), tokenId);

        uint256 requestId = _bridgeRequestIds.current();
        idToBridgeRequest[requestId] = BridgeRequest({
            tokenId: tokenId,
            owner: msg.sender,
            targetChain: targetChain,
            targetAddress: targetAddress,
            timestamp: block.timestamp,
            completed: false,
            txHash: bytes32(0)
        });

        emit BridgeRequested(tokenId, msg.sender, targetChain);
    }

    // ========== NEW: Governance System ==========
    
    function createProposal(
        string memory description,
        ProposalType proposalType,
        bytes memory data
    ) public returns (uint256) {
        require(votingPower[msg.sender] >= 1000, "Insufficient voting power"); // Minimum 1000 tokens
        
        _proposalIds.increment();
        uint256 proposalId = _proposalIds.current();

        proposals[proposalId] = Proposal({
            proposalId: proposalId,
            description: description,
            forVotes: 0,
            againstVotes: 0,
            startTime: block.timestamp,
            endTime: block.timestamp + 7 days,
            executed: false,
            proposalType: proposalType,
            data: data
        });

        emit ProposalCreated(proposalId, description, proposalType);
        return proposalId;
    }

    function vote(uint256 proposalId, bool support) public {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp <= proposal.endTime, "Voting ended");
        require(!hasVoted[proposalId][msg.sender], "Already voted");
        require(votingPower[msg.sender] > 0, "No voting power");

        hasVoted[proposalId][msg.sender] = true;
        uint256 weight = votingPower[msg.sender];

        if (support) {
            proposal.forVotes += weight;
        } else {
            proposal.againstVotes += weight;
        }

        emit Voted(proposalId, msg.sender, support, weight);
    }

    // ========== Utility Functions ==========
    
    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    // ========== Admin Functions ==========
    
    function updatePlatformFee(uint256 newFee) public onlyOwner {
        require(newFee <= 1000, "Fee too high"); // Max 10%
        platformFee = newFee;
    }

    function banUser(address user, string memory reason) public onlyOwner {
        bannedUsers[user] = true;
        emit UserBanned(user, reason);
    }

    function unbanUser(address user) public onlyOwner {
        bannedUsers[user] = false;
        emit UserUnbanned(user);
    }

    function emergencyPause() public onlyOwner {
        _pause();
    }

    function emergencyUnpause() public onlyOwner {
        _unpause();
    }

    function withdrawPlatformFees() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        payable(owner()).transfer(balance);
    }

    // ========== View Functions ==========
    
    function getMarketItem(uint256 tokenId) public view returns (MarketItem memory) {
        return idToMarketItem[tokenId];
    }

    function getCollection(uint256 collectionId) public view returns (Collection memory) {
        return idToCollection[collectionId];
    }

    function getDrop(uint256 dropId) public view returns (Drop memory drop) {
        Drop storage storedDrop = idToDrop[dropId];
        return Drop({
            dropId: storedDrop.dropId,
            name: storedDrop.name,
            description: storedDrop.description,
            creator: storedDrop.creator,
            startTime: storedDrop.startTime,
            endTime: storedDrop.endTime,
            maxSupply: storedDrop.maxSupply,
            currentSupply: storedDrop.currentSupply,
            price: storedDrop.price,
            max
