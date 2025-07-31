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

    modifier validTokenId(uint256 tokenId) {
        require(_exists(tokenId), "Token does not exist");
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
        bytes32 merkleRoot; // For whitelist verification
        bool isRevealed;
        string preRevealURI;
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
    }

    struct Affiliate {
        uint256 affiliateId;
        address affiliateAddress;
        uint256 commissionRate; // Basis points (100 = 1%)
        uint256 totalEarnings;
        uint256 totalReferrals;
        bool isActive;
        uint256 tier; // 1: Bronze, 2: Silver, 3: Gold, 4: Platinum
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
        uint256 penaltyRate; // Early withdrawal penalty
        uint256 bonusMultiplier; // Long-term staking bonus
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

    // ========== NEW: NFT Rental System ==========
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

    // ========== NEW: NFT Loans ==========
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

    // ========== NEW: Escrow System ==========
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

    // ========== NEW: Subscription NFTs ==========
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

    // ========== NEW: Bundle System ==========
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

    // ========== NEW: Lottery System ==========
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

    // ========== Payment Methods ==========
    enum PaymentMethod { ETH, ERC20, Crypto, Fiat }

    struct PaymentToken {
        address tokenAddress;
        bool isAccepted;
        uint256 conversionRate; // Rate to ETH
        uint8 decimals;
    }

    // ========== Lazy Minting ==========
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

    // User mappings
    mapping(address => bool) private verifiedCreators;
    mapping(string => bool) private validCategories;
    mapping(address => uint256) private creatorEarnings;
    mapping(address => bool) private bannedUsers;
    mapping(address => uint256) private userNonce;
    mapping(address => address) private referrals; // user -> referrer
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
    mapping(uint256 => mapping(address => uint256)) private tokenOffers; // tokenId -> buyer -> offer
    mapping(address => uint256[]) private userWatchlist;

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

    // ========== Core Functions ==========
    
    function createToken(string memory tokenURI, uint256 price, string memory category) 
        public payable nonReentrant onlyValidCategory(category) whenNotPaused notBanned {
        require(msg.value == listingPrice, "Must pay listing price");
        require(price > 0, "Price must be positive");
        
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

        PaymentMethod[] memory defaultPayments = new PaymentMethod[](1);
        defaultPayments[0] = PaymentMethod.ETH;

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
            1,
            true,
            price / 10, // Min offer is 10% of price
            defaultPayments
        );

        _transfer(msg.sender, address(this), tokenId);
        emit MarketItemCreated(tokenId, msg.sender, address(this), price, false, category);
    }

    function buyToken(uint256 tokenId, address referrer) 
        public payable nonReentrant whenNotPaused notBanned validTokenId(tokenId) {
        MarketItem storage item = idToMarketItem[tokenId];
        require(!item.sold, "Token already sold");
        require(item.price > 0, "Token not for sale");
        require(msg.value == item.price, "Incorrect payment amount");
        require(item.seller != msg.sender, "Cannot buy your own NFT");

        // Handle dynamic pricing
        if (idToDynamicPricing[tokenId].isActive) {
            updateDynamicPrice(tokenId);
        }

        // Calculate fees
        uint256 affiliateCommission = 0;
        if (referrer != address(0) && referrals[msg.sender] == address(0)) {
            referrals[msg.sender] = referrer;
            affiliateCommission = calculateAffiliateCommission(item.price, referrer);
        }

        uint256 platformFeeAmount = (item.price * platformFee) / 10000;
        uint256 royaltyAmount = (item.price * royaltyPercentage) / 10000;
        uint256 sellerAmount = item.price - platformFeeAmount - royaltyAmount - affiliateCommission;

        // Handle collaborator payments
        if (item.collaborators.length > 0) {
            uint256 totalCollaboratorShare = 0;
            for (uint256 i = 0; i < item.collaborators.length; i++) {
                uint256 collaboratorAmount = (sellerAmount * item.collaboratorShares[i]) / 10000;
                payable(item.collaborators[i]).transfer(collaboratorAmount);
                totalCollaboratorShare += collaboratorAmount;
            }
            sellerAmount -= totalCollaboratorShare;
        }

        // Transfer payments
        item.seller.transfer(sellerAmount);
        
        if (item.creator != item.seller) {
            payable(item.creator).transfer(royaltyAmount);
            creatorEarnings[item.creator] += royaltyAmount;
        }

        if (affiliateCommission > 0) {
            payable(referrer).transfer(affiliateCommission);
            updateAffiliateStats(referrer, affiliateCommission);
            emit CommissionPaid(referrer, affiliateCommission, tokenId);
        }

        // Complete the sale
        _transfer(address(this), msg.sender, tokenId);
        item.owner = payable(msg.sender);
        item.sold = true;
        _itemsSold.increment();

        // Update reputation
        userReputation[msg.sender] += 1;
        userReputation[item.seller] += 1;

        emit MarketItemSold(tokenId, item.seller, msg.sender, item.price, referrer);
    }

    // ========== Lazy Minting ==========
    
    function lazyMint(LazyMintVoucher calldata voucher) 
        public payable nonReentrant whenNotPaused notBanned {
        require(voucher.expiry > block.timestamp, "Voucher expired");
        require(msg.value == voucher.price, "Incorrect payment");
        
        // Verify signature
        bytes32 structHash = keccak256(abi.encode(
            _LAZY_MINT_TYPEHASH,
            voucher.tokenId,
            voucher.price,
            keccak256(bytes(voucher.uri)),
            voucher.creator,
            voucher.nonce,
            voucher.expiry
        ));
        
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = hash.recover(voucher.signature);
        require(signer == voucher.creator, "Invalid signature");
        require(userNonce[voucher.creator] == voucher.nonce, "Invalid nonce");
        
        // Mint the token
        _mint(msg.sender, voucher.tokenId);
        _setTokenURI(voucher.tokenId, voucher.uri);
        
        // Update nonce
        userNonce[voucher.creator]++;
        
        // Pay creator (minus fees)
        uint256 platformFeeAmount = (voucher.price * platformFee) / 10000;
        uint256 creatorAmount = voucher.price - platformFeeAmount;
        payable(voucher.creator).transfer(creatorAmount);
        
        emit LazyMinted(voucher.tokenId, voucher.creator, msg.sender, voucher.price);
    }

    // ========== Advanced Auction System ==========
    
    function createAuction(
        uint256 tokenId,
        uint256 startingPrice,
        uint256 duration,
        AuctionType auctionType,
        uint256 reservePrice,
        uint256 buyNowPrice
    ) public onlyTokenOwner(tokenId) nonReentrant {
        require(startingPrice > 0, "Starting price must be positive");
        require(duration > 0, "Duration must be positive");
        require(reservePrice >= startingPrice, "Invalid reserve price");

        // Transfer token to contract
        _transfer(msg.sender, address(this), tokenId);

        Auction storage auction = idToAuction[tokenId];
        auction.tokenId = tokenId;
        auction.startingPrice = startingPrice;
        auction.highestBid = 0;
        auction.auctionEnd = block.timestamp + duration;
        auction.ended = false;
        auction.reservePrice = reservePrice;
        auction.auctionType = auctionType;
        auction.allowBuyNow = buyNowPrice > 0;
        auction.buyNowPrice = buyNowPrice;

        if (auctionType == AuctionType.Sealed) {
            auction.revealStart = block.timestamp + (duration * 2) / 3;
            auction.revealEnd = auction.auctionEnd;
            auction.auctionEnd = auction.revealStart;
        }

        // Mark as auction in market item
        idToMarketItem[tokenId].isAuction = true;

        emit AuctionCreated(tokenId, startingPrice, auction.auctionEnd, auctionType);
    }

    function placeBid(uint256 tokenId) public payable nonReentrant notBanned {
        Auction storage auction = idToAuction[tokenId];
        require(!auction.ended, "Auction ended");
        require(block.timestamp <= auction.auctionEnd, "Auction expired");
        require(msg.value > auction.highestBid, "Bid too low");
        require(msg.value >= auction.startingPrice, "Below starting price");

        if (auction.auctionType == AuctionType.English) {
            // Return previous highest bid
            if (auction.highestBidder != address(0)) {
                auction.pendingReturns[auction.highestBidder] += auction.highestBid;
            }

            auction.highestBid = msg.value;
            auction.highestBidder = msg.sender;

            // Extend auction if bid placed near end
            if (auction.isExtendable && (auction.auctionEnd - block.timestamp) < 300) { // 5 minutes
                auction.auctionEnd += auction.extensionTime;
            }
        }

        emit BidPlaced(tokenId, msg.sender, msg.value);
    }

    function placeSealedBid(uint256 tokenId, bytes32 bidHash) public payable nonReentrant notBanned {
        Auction storage auction = idToAuction[tokenId];
        require(auction.auctionType == AuctionType.Sealed, "Not sealed auction");
        require(!auction.ended, "Auction ended");
        require(block.timestamp <= auction.auctionEnd, "Bidding period ended");
        require(msg.value > 0, "Must send collateral");

        auction.sealedBids[bidHash] = SealedBid({
            bidder: msg.sender,
            amount: msg.value,
            revealed: false,
            refunded: false
        });

        auction.bidHashes.push(bidHash);
    }

    function revealBid(uint256 tokenId, uint256 amount, uint256 nonce) public nonReentrant {
        Auction storage auction = idToAuction[tokenId];
        require(auction.auctionType == AuctionType.Sealed, "Not sealed auction
