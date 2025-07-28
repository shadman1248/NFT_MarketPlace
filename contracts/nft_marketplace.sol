// SPDX-License-Identifier:
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract NFTMarketplace is ERC721URIStorage, ReentrancyGuard, Ownable, Pausable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    Counters.Counter private _itemsSold;
    Counters.Counter private _collectionIds;
    Counters.Counter private _bundleIds;
    Counters.Counter private _subscriptionIds;
    Counters.Counter private _lotteryIds;

    uint256 public listingPrice = 0.025 ether;
    uint256 public royaltyPercentage = 250; // 2.5%
    uint256 public platformFee = 250; // 2.5%
    uint256 public minStakeAmount = 1 ether;
    uint256 public stakingRewardRate = 500; // 5% annually
    uint256 public constant SECONDS_PER_YEAR = 365 * 24 * 60 * 60;

    constructor() ERC721("NFT Marketplace", "NFTM") Ownable(msg.sender) {
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
    }

    struct Rental { 
        uint256 tokenId; 
        address renter; 
        uint256 rentPrice; 
        uint256 rentDuration; 
        uint256 rentStart; 
        uint256 rentEnd; 
        bool isActive;
        bool autoRenew;
        uint256 totalEarned;
    }

    struct Bundle { 
        uint256 bundleId; 
        uint256[] tokenIds; 
        uint256 bundlePrice; 
        address seller; 
        bool sold; 
        uint256 createdAt; 
        uint256 expiresAt;
        uint256 discount;
        string bundleName;
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
    }

    struct Offer { 
        uint256 tokenId; 
        address buyer; 
        uint256 amount; 
        uint256 expiry; 
        bool accepted;
        IERC20 paymentToken;
        bool isCollectionOffer;
    }

    struct Report { 
        uint256 tokenId; 
        address reporter; 
        string reason; 
        uint256 timestamp;
        bool resolved;
        string resolution;
    }

    struct Comment { 
        address commenter; 
        string message; 
        uint256 timestamp;
        uint256 likes;
        bool isVerified;
    }

    // ========== New Structs ==========
    struct Subscription {
        uint256 subscriptionId;
        address subscriber;
        address creator;
        uint256 monthlyFee;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        uint256[] exclusiveTokens;
    }

    struct Lottery {
        uint256 lotteryId;
        uint256[] tokenIds;
        uint256 ticketPrice;
        uint256 maxTickets;
        uint256 ticketsSold;
        mapping(address => uint256) ticketsPurchased;
        address[] participants;
        uint256 endTime;
        bool isActive;
        address winner;
        uint256 prizePool;
    }

    struct StakeInfo {
        uint256 amount;
        uint256 stakingTime;
        uint256 lastRewardClaim;
        uint256 totalRewards;
    }

    struct CreatorProfile {
        string name;
        string bio;
        string avatar;
        string website;
        string[] socialLinks;
        uint256 totalSales;
        uint256 totalVolume;
        uint256 followerCount;
        bool isVerified;
        uint256 verificationTier; // 1: Basic, 2: Premium, 3: Elite
        uint256 createdAt;
    }

    struct LazyMintVoucher {
        uint256 tokenId;
        uint256 price;
        string uri;
        address creator;
        bytes signature;
        uint256 nonce;
        uint256 expiry;
    }

    struct Loan {
        uint256 tokenId;
        address borrower;
        address lender;
        uint256 loanAmount;
        uint256 interestRate;
        uint256 duration;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        bool isDefaulted;
        uint256 collateralValue;
    }

    // ========== Enhanced Mappings ==========
    mapping(uint256 => MarketItem) private idToMarketItem;
    mapping(uint256 => Auction) private idToAuction;
    mapping(uint256 => Offer[]) private tokenOffers;
    mapping(uint256 => Collection) private idToCollection;
    mapping(uint256 => FractionalNFT) private idToFractionalNFT;
    mapping(uint256 => Rental) private idToRental;
    mapping(uint256 => Bundle) private idToBundle;
    mapping(uint256 => Comment[]) private tokenComments;
    mapping(uint256 => Subscription) private idToSubscription;
    mapping(uint256 => Lottery) private idToLottery;
    mapping(uint256 => Loan) private idToLoan;

    mapping(address => bool) private verifiedCreators;
    mapping(string => bool) private validCategories;
    mapping(address => uint256) private creatorEarnings;
    mapping(uint256 => mapping(address => bool)) private tokenLikes;
    mapping(address => uint256[]) private userFavorites;
    mapping(address => mapping(address => bool)) private userFollowing;
    mapping(address => address[]) private userFollowers;
    mapping(address => uint256) private userReputationScore;
    mapping(address => uint256[]) private favoriteCollections;
    mapping(uint256 => Report[]) private tokenReports;

    // ========== New Mappings ==========
    mapping(address => StakeInfo) private userStakes;
    mapping(address => CreatorProfile) private creatorProfiles;
    mapping(address => uint256[]) private userSubscriptions;
    mapping(address => uint256[]) private creatorSubscriptions;
    mapping(address => mapping(uint256 => bool)) private hasAccessToCollection;
    mapping(address => uint256) private userNonce;
    mapping(address => bool) private whitelistedTokens; // For ERC20 payments
    mapping(uint256 => string) private encryptedContent;
    mapping(address => uint256) private lastActivityTime;
    mapping(address => uint256) private tradingVolume;
    mapping(uint256 => uint256) private tokenHistory; // Price history
    mapping(address => bool) private bannedUsers;

    // ========== Enhanced Events ==========
    event MarketItemCreated(uint256 indexed tokenId, address seller, address owner, uint256 price, bool sold, string category);
    event MarketItemSold(uint256 indexed tokenId, address seller, address buyer, uint256 price);
    event AuctionCreated(uint256 indexed tokenId, uint256 startingPrice, uint256 auctionEnd);
    event BidPlaced(uint256 indexed tokenId, address bidder, uint256 amount);
    event AuctionEnded(uint256 indexed tokenId, address winner, uint256 amount);
    event AuctionFinalized(uint256 indexed tokenId, address winner, uint256 amount);
    event OfferMade(uint256 indexed tokenId, address buyer, uint256 amount, uint256 expiry);
    event OfferAccepted(uint256 indexed tokenId, address buyer, uint256 amount);
    event CreatorVerified(address indexed creator);
    event RoyaltyPaid(address indexed creator, uint256 amount);
    event CollectionCreated(uint256 indexed collectionId, string name, address creator);
    event TokenAddedToCollection(uint256 indexed tokenId, uint256 indexed collectionId);
    event FractionalNFTCreated(uint256 indexed tokenId, uint256 totalShares, uint256 sharePrice);
    event SharesPurchased(uint256 indexed tokenId, address buyer, uint256 shares, uint256 amount);
    event ShareTransferred(uint256 indexed tokenId, address from, address to, uint256 shares);
    event NFTRented(uint256 indexed tokenId, address renter, uint256 rentPrice, uint256 duration);
    event BundleCreated(uint256 indexed bundleId, uint256[] tokenIds, uint256 bundlePrice);
    event BundleSold(uint256 indexed bundleId, address buyer, uint256 price);
    event TokenLiked(uint256 indexed tokenId, address liker);
    event UserFollowed(address indexed follower, address indexed following);
    event ReputationBoosted(address indexed user, uint256 newScore);
    event TokenReported(uint256 indexed tokenId, address indexed reporter, string reason);
    event NFTGifted(uint256 indexed tokenId, address from, address to);
    event NFTBurned(uint256 indexed tokenId, address burner);
    event TokenCommented(uint256 indexed tokenId, address commenter, string message);
    event NFTBatchMinted(address indexed owner, uint256[] tokenIds);

    // ========== New Events ==========
    event SubscriptionCreated(uint256 indexed subscriptionId, address subscriber, address creator, uint256 monthlyFee);
    event SubscriptionRenewed(uint256 indexed subscriptionId, uint256 newEndTime);
    event LotteryCreated(uint256 indexed lotteryId, uint256[] tokenIds, uint256 ticketPrice);
    event LotteryTicketPurchased(uint256 indexed lotteryId, address buyer, uint256 tickets);
    event LotteryEnded(uint256 indexed lotteryId, address winner, uint256 prizeAmount);
    event TokenStaked(address indexed user, uint256 amount);
    event TokenUnstaked(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event CreatorProfileUpdated(address indexed creator, string name, string bio);
    event LazyMinted(uint256 indexed tokenId, address indexed creator, address indexed buyer);
    event LoanCreated(uint256 indexed tokenId, address borrower, address lender, uint256 amount);
    event LoanRepaid(uint256 indexed tokenId, uint256 amount);
    event LoanDefaulted(uint256 indexed tokenId);
    event DividendDistributed(uint256 indexed tokenId, uint256 totalAmount);
    event CollectionOfferMade(uint256 indexed collectionId, address buyer, uint256 amount);
    event UserBanned(address indexed user, string reason);
    event UserUnbanned(address indexed user);
    event PriceAlertSet(uint256 indexed tokenId, address user, uint256 targetPrice);

    // ========== Core Functions (Existing) ==========
    
    function createToken(string memory tokenURI, uint256 price, string memory category) 
        public payable nonReentrant onlyValidCategory(category) whenNotPaused {
        require(msg.value == listingPrice, "Must pay listing price");
        require(!bannedUsers[msg.sender], "User is banned");
        
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();

        _mint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, tokenURI);
        createMarketItem(newTokenId, price, category);
        
        // Update creator profile
        if (bytes(creatorProfiles[msg.sender].name).length == 0) {
            creatorProfiles[msg.sender].createdAt = block.timestamp;
        }
        creatorProfiles[msg.sender].totalSales++;
        
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
            new uint256[](0)
        );

        _transfer(msg.sender, address(this), tokenId);
        emit MarketItemCreated(tokenId, msg.sender, address(this), price, false, category);
    }

    function createMarketSale(uint256 tokenId) public payable nonReentrant whenNotPaused {
        uint256 price = idToMarketItem[tokenId].price;
        address seller = idToMarketItem[tokenId].seller;
        address creator = idToMarketItem[tokenId].creator;
        
        require(msg.value == price, "Submit asking price");
        require(!bannedUsers[msg.sender], "User is banned");
        require(seller != msg.sender, "Cannot buy your own NFT");

        // Calculate fees
        uint256 platformFeeAmount = (price * platformFee) / 10000;
        uint256 royaltyAmount = (price * royaltyPercentage) / 10000;
        uint256 sellerAmount = price - platformFeeAmount - royaltyAmount;

        // Transfer payments
        idToMarketItem[tokenId].seller.transfer(sellerAmount);
        if (creator != seller) {
            payable(creator).transfer(royaltyAmount);
            creatorEarnings[creator] += royaltyAmount;
            emit RoyaltyPaid(creator, royaltyAmount);
        }

        _transfer(address(this), msg.sender, tokenId);
        idToMarketItem[tokenId].owner = payable(msg.sender);
        idToMarketItem[tokenId].sold = true;
        _itemsSold.increment();

        // Update stats
        tradingVolume[msg.sender] += price;
        tradingVolume[seller] += price;
        lastActivityTime[msg.sender] = block.timestamp;
        lastActivityTime[seller] = block.timestamp;
        
        // Update collection stats if applicable
        if (idToMarketItem[tokenId].collectionId > 0) {
            uint256 collectionId = idToMarketItem[tokenId].collectionId;
            idToCollection[collectionId].totalVolume += price;
            if (price < idToCollection[collectionId].floorPrice || idToCollection[collectionId].floorPrice == 0) {
                idToCollection[collectionId].floorPrice = price;
            }
        }

        emit MarketItemSold(tokenId, seller, msg.sender, price);
    }

    // ========== Enhanced Auction System ==========
    
    function createAuction(uint256 tokenId, uint256 startingPrice, uint256 duration, uint256 reservePrice, bool isExtendable) 
        public onlyTokenOwner(tokenId) whenNotPaused {
        require(startingPrice > 0, "Starting price must be positive");
        require(duration > 0, "Duration must be positive");
        require(!bannedUsers[msg.sender], "User is banned");

        _transfer(msg.sender, address(this), tokenId);

        Auction storage auction = idToAuction[tokenId];
        auction.tokenId = tokenId;
        auction.startingPrice = startingPrice;
        auction.auctionEnd = block.timestamp + duration;
        auction.ended = false;
        auction.reservePrice = reservePrice;
        auction.isExtendable = isExtendable;
        auction.bidIncrement = startingPrice / 20; // 5% minimum increment
        auction.extensionTime = 600; // 10 minutes

        idToMarketItem[tokenId].isAuction = true;
        idToMarketItem[tokenId].price = startingPrice;

        emit AuctionCreated(tokenId, startingPrice, auction.auctionEnd);
    }

    function placeBid(uint256 tokenId) public payable nonReentrant whenNotPaused {
        Auction storage auction = idToAuction[tokenId];
        require(block.timestamp < auction.auctionEnd, "Auction ended");
        require(msg.value >= auction.startingPrice, "Bid below starting price");
        require(msg.value >= auction.highestBid + auction.bidIncrement, "Bid increment too low");
        require(!bannedUsers[msg.sender], "User is banned");

        // Extend auction if bid placed in last 10 minutes and extensible
        if (auction.isExtendable && (auction.auctionEnd - block.timestamp) < auction.extensionTime) {
            auction.auctionEnd += auction.extensionTime;
        }

        if (auction.highestBidder != address(0)) {
            auction.pendingReturns[auction.highestBidder] += auction.highestBid;
        }

        auction.highestBidder = msg.sender;
        auction.highestBid = msg.value;

        lastActivityTime[msg.sender] = block.timestamp;
        emit BidPlaced(tokenId, msg.sender, msg.value);
    }

    function finalizeAuction(uint256 tokenId) public nonReentrant {
        Auction storage auction = idToAuction[tokenId];
        require(block.timestamp >= auction.auctionEnd, "Auction not ended");
        require(!auction.ended, "Already finalized");
        
        auction.ended = true;

        if (auction.highestBidder != address(0) && auction.highestBid >= auction.reservePrice) {
            address payable seller = idToMarketItem[tokenId].seller;
            address creator = idToMarketItem[tokenId].creator;
            
            // Calculate fees
            uint256 platformFeeAmount = (auction.highestBid * platformFee) / 10000;
            uint256 royaltyAmount = (auction.highestBid * royaltyPercentage) / 10000;
            uint256 sellerAmount = auction.highestBid - platformFeeAmount - royaltyAmount;

            seller.transfer(sellerAmount);
            if (creator != seller) {
                payable(creator).transfer(royaltyAmount);
                creatorEarnings[creator] += royaltyAmount;
                emit RoyaltyPaid(creator, royaltyAmount);
            }

            _transfer(address(this), auction.highestBidder, tokenId);
            idToMarketItem[tokenId].owner = payable(auction.highestBidder);
            idToMarketItem[tokenId].sold = true;
            _itemsSold.increment();

            emit AuctionFinalized(tokenId, auction.highestBidder, auction.highestBid);
        } else {
            // Return NFT to seller if reserve not met
            _transfer(address(this), idToMarketItem[tokenId].seller, tokenId);
            idToMarketItem[tokenId].owner = idToMarketItem[tokenId].seller;
            
            // Return highest bid if any
            if (auction.highestBidder != address(0)) {
                auction.pendingReturns[auction.highestBidder] += auction.highestBid;
            }
        }

        emit AuctionEnded(tokenId, auction.highestBidder, auction.highestBid);
    }

    function withdrawAuctionBid(uint256 tokenId) public nonReentrant {
        Auction storage auction = idToAuction[tokenId];
        uint256 amount = auction.pendingReturns[msg.sender];
        require(amount > 0, "No funds to withdraw");
        
        auction.pendingReturns[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

    // ========== Enhanced Rental System ==========
    
    function listForRent(uint256 tokenId, uint256 dailyPrice, bool autoRenew) public onlyTokenOwner(tokenId) {
        require(dailyPrice > 0, "Price must be positive");
        require(!isCurrentlyRented(tokenId), "Already rented");

        Rental storage rental = idToRental[tokenId];
        rental.tokenId = tokenId;
        rental.rentPrice = dailyPrice;
        rental.autoRenew = autoRenew;
        rental.isActive = false; // Listed but not rented yet
    }

    function rentNFT(uint256 tokenId, uint256 durationInDays) public payable nonReentrant whenNotPaused {
        Rental storage rent = idToRental[tokenId];
        require(!isCurrentlyRented(tokenId), "Already rented");
        require(ownerOf(tokenId) != msg.sender, "Owner can't rent");
        require(durationInDays > 0, "Duration must be positive");
        require(!bannedUsers[msg.sender], "User is banned");

        uint256 totalCost = rent.rentPrice * durationInDays;
        require(msg.value == totalCost, "Incorrect rent amount");

        rent.renter = msg.sender;
        rent.rentDuration = durationInDays * 1 days;
        rent.rentStart = block.timestamp;
        rent.rentEnd = block.timestamp + rent.rentDuration;
        rent.isActive = true;
        rent.totalEarned += msg.value;

        // Pay owner (minus platform fee)
        uint256 platformFeeAmount = (msg.value * platformFee) / 10000;
        uint256 ownerAmount = msg.value - platformFeeAmount;
        payable(ownerOf(tokenId)).transfer(ownerAmount);

        boostReputationOnRental(msg.sender);
        lastActivityTime[msg.sender] = block.timestamp;
        
        emit NFTRented(tokenId, msg.sender, msg.value, rent.rentDuration);
    }

    function isCurrentlyRented(uint256 tokenId) public view returns (bool) {
        Rental memory rent = idToRental[tokenId];
        return rent.isActive && block.timestamp < rent.rentEnd;
    }

    function extendRental(uint256 tokenId, uint256 additionalDays) public payable {
        Rental storage rent = idToRental[tokenId];
        require(rent.renter == msg.sender, "Not current renter");
        require(isCurrentlyRented(tokenId), "Rental expired");
        
        uint256 extensionCost = rent.rentPrice * additionalDays;
        require(msg.value == extensionCost, "Incorrect extension amount");

        rent.rentEnd += additionalDays * 1 days;
        rent.totalEarned += msg.value;

        uint256 platformFeeAmount = (msg.value * platformFee) / 10000;
        uint256 ownerAmount = msg.value - platformFeeAmount;
        payable(ownerOf(tokenId)).transfer(ownerAmount);
    }

    // ========== NEW: Subscription System ==========
    
    function createSubscription(address creator, uint256 monthlyFee) public payable {
        require(monthlyFee > 0, "Fee must be positive");
        require(msg.value >= monthlyFee, "Insufficient payment");
        require(creator != msg.sender, "Cannot subscribe to yourself");
        require(verifiedCreators[creator], "Creator not verified");

        _subscriptionIds.increment();
        uint256 subscriptionId = _subscriptionIds.current();

        idToSubscription[subscriptionId] = Subscription({
            subscriptionId: subscriptionId,
            subscriber: msg.sender,
            creator: creator,
            monthlyFee: monthlyFee,
            startTime: block.timestamp,
            endTime: block.timestamp + 30 days,
            isActive: true,
            exclusiveTokens: new uint256[](0)
        });

        userSubscriptions[msg.sender].push(subscriptionId);
        creatorSubscriptions[creator].push(subscriptionId);

        // Pay creator (minus platform fee)
        uint256 platformFeeAmount = (monthlyFee * platformFee) / 10000;
        uint256 creatorAmount = monthlyFee - platformFeeAmount;
        payable(creator).transfer(creatorAmount);

        // Refund excess payment
        if (msg.value > monthlyFee) {
            payable(msg.sender).transfer(msg.value - monthlyFee);
        }

        emit SubscriptionCreated(subscriptionId, msg.sender, creator, monthlyFee);
    }

    function renewSubscription(uint256 subscriptionId) public payable {
        Subscription storage sub = idToSubscription[subscriptionId];
        require(sub.subscriber == msg.sender, "Not subscriber");
        require(msg.value >= sub.monthlyFee, "Insufficient payment");

        sub.endTime = block.timestamp + 30 days;
        sub.isActive = true;

        uint256 platformFeeAmount = (sub.monthlyFee * platformFee) / 10000;
        uint256 creatorAmount = sub.monthlyFee - platformFeeAmount;
        payable(sub.creator).transfer(creatorAmount);

        if (msg.value > sub.monthlyFee) {
            payable(msg.sender).transfer(msg.value - sub.monthlyFee);
        }

        emit SubscriptionRenewed(subscriptionId, sub.endTime);
    }

    function hasActiveSubscription(address subscriber, address creator) public view returns (bool) {
        uint256[] memory subs = userSubscriptions[subscriber];
        for (uint256 i = 0; i < subs.length; i++) {
            Subscription memory sub = idToSubscription[subs[i]];
            if (sub.creator == creator && sub.isActive && block.timestamp < sub.endTime) {
                return true;
            }
        }
        return false;
    }

    // ========== NEW: NFT Lottery System ==========
    
    function createLottery(uint256[] memory tokenIds, uint256 ticketPrice, uint256 maxTickets, uint256 duration) 
        public whenNotPaused {
        require(tokenIds.length > 0, "Must include tokens");
        require(ticketPrice > 0, "Ticket price must be positive");
        require(maxTickets > 0, "Max tickets must be positive");
        require(duration > 0, "Duration must be positive");

        // Verify ownership of all tokens
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(ownerOf(tokenIds[i]) == msg.sender, "Not owner of token");
            _transfer(msg.sender, address(this), tokenIds[i]);
        }

        _lotteryIds.increment();
        uint256 lotteryId = _lotteryIds.current();

        Lottery storage lottery = idToLottery[lotteryId];
        lottery.lotteryId = lotteryId;
        lottery.tokenIds = tokenIds;
        lottery.ticketPrice = ticketPrice;
        lottery.maxTickets = maxTickets;
        lottery.endTime = block.timestamp + duration;
        lottery.isActive = true;

        emit LotteryCreated(lotteryId, tokenIds, ticketPrice);
    }

    function buyLotteryTickets(uint256 lotteryId, uint256 numTickets) public payable nonReentrant {
        Lottery storage lottery = idToLottery[lotteryId];
        require(lottery.isActive, "Lottery not active");
        require(block.timestamp < lottery.endTime, "Lottery ended");
        require(numTickets > 0, "Must buy at least one ticket");
        require(lottery.ticketsSold + numTickets <= lottery.maxTickets, "Exceeds max tickets");
        require(msg.value == lottery.ticketPrice * numTickets, "Incorrect payment");

        if (lottery.ticketsPurchased[msg.sender] == 0) {
            lottery.participants.push(msg.sender);
        }

        lottery.ticketsPurchased[msg.sender] += numTickets;
        lottery.ticketsSold += numTickets;
        lottery.prizePool += msg.value;

        emit LotteryTicketPurchased(lotteryId, msg.sender, numTickets);
    }

    function drawLottery(uint256 lotteryI
