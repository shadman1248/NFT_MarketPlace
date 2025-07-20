// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract NFTMarketplace is ERC721URIStorage, ReentrancyGuard, Ownable, Pausable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    Counters.Counter private _itemsSold;
    Counters.Counter private _collectionIds;

    uint256 public listingPrice = 0.025 ether;
    uint256 public royaltyPercentage = 250; // 2.5% in basis points (100 basis points = 1%)
    
    // NEW: Collection struct for organizing NFTs into collections
    struct Collection {
        uint256 collectionId;
        string name;
        string description;
        string coverImage;
        address creator;
        uint256 createdAt;
        bool verified;
        uint256[] tokenIds;
    }
    
    // NEW: Fractional ownership struct
    struct FractionalNFT {
        uint256 tokenId;
        uint256 totalShares;
        uint256 sharePrice;
        mapping(address => uint256) shareOwnership;
        address[] shareholders;
        bool isActive;
    }
    
    // NEW: Rental struct for NFT rentals
    struct Rental {
        uint256 tokenId;
        address renter;
        uint256 rentPrice;
        uint256 rentDuration;
        uint256 rentStart;
        uint256 rentEnd;
        bool isActive;
    }
    
    // NEW: Bundle struct for selling multiple NFTs together
    struct Bundle {
        uint256 bundleId;
        uint256[] tokenIds;
        uint256 bundlePrice;
        address seller;
        bool sold;
        uint256 createdAt;
        uint256 expiresAt;
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
        uint256 collectionId; // NEW: Link to collection
        uint256 views; // NEW: Track views
        uint256 likes; // NEW: Track likes
    }

    struct Auction {
        uint256 tokenId;
        uint256 startingPrice;
        uint256 highestBid;
        address highestBidder;
        uint256 auctionEnd;
        bool ended;
        mapping(address => uint256) pendingReturns;
        uint256 reservePrice; // NEW: Reserve price
    }

    struct Offer {
        uint256 tokenId;
        address buyer;
        uint256 amount;
        uint256 expiry;
        bool accepted;
    }

    mapping(uint256 => MarketItem) private idToMarketItem;
    mapping(uint256 => Auction) private idToAuction;
    mapping(uint256 => Offer[]) private tokenOffers;
    mapping(address => bool) private verifiedCreators;
    mapping(string => bool) private validCategories;
    mapping(address => uint256) private creatorEarnings;
    
    // NEW: Additional mappings for new features
    mapping(uint256 => Collection) private idToCollection;
    mapping(uint256 => FractionalNFT) private idToFractionalNFT;
    mapping(uint256 => Rental) private idToRental;
    mapping(uint256 => Bundle) private idToBundle;
    mapping(uint256 => mapping(address => bool)) private tokenLikes; // tokenId => user => liked
    mapping(address => uint256[]) private userFavorites;
    mapping(address => mapping(address => bool)) private userFollowing; // follower => following => true
    mapping(address => address[]) private userFollowers;
    mapping(address => uint256) private userReputationScore;
    Counters.Counter private _bundleIds;

    // Existing events...
    event MarketItemCreated(uint256 indexed tokenId, address seller, address owner, uint256 price, bool sold, string category);
    event MarketItemSold(uint256 indexed tokenId, address seller, address buyer, uint256 price);
    event AuctionCreated(uint256 indexed tokenId, uint256 startingPrice, uint256 auctionEnd);
    event BidPlaced(uint256 indexed tokenId, address bidder, uint256 amount);
    event AuctionEnded(uint256 indexed tokenId, address winner, uint256 amount);
    event OfferMade(uint256 indexed tokenId, address buyer, uint256 amount, uint256 expiry);
    event OfferAccepted(uint256 indexed tokenId, address buyer, uint256 amount);
    event CreatorVerified(address indexed creator);
    event RoyaltyPaid(address indexed creator, uint256 amount);

    // NEW: Events for new features
    event CollectionCreated(uint256 indexed collectionId, string name, address creator);
    event TokenAddedToCollection(uint256 indexed tokenId, uint256 indexed collectionId);
    event FractionalNFTCreated(uint256 indexed tokenId, uint256 totalShares, uint256 sharePrice);
    event SharesPurchased(uint256 indexed tokenId, address buyer, uint256 shares, uint256 amount);
    event NFTRented(uint256 indexed tokenId, address renter, uint256 rentPrice, uint256 duration);
    event BundleCreated(uint256 indexed bundleId, uint256[] tokenIds, uint256 bundlePrice);
    event BundleSold(uint256 indexed bundleId, address buyer, uint256 price);
    event TokenLiked(uint256 indexed tokenId, address liker);
    event UserFollowed(address indexed follower, address indexed following);

    constructor() ERC721("NFT Marketplace", "NFTM") Ownable(msg.sender) {
        // Initialize valid categories
        validCategories["Art"] = true;
        validCategories["Music"] = true;
        validCategories["Photography"] = true;
        validCategories["Gaming"] = true;
        validCategories["Sports"] = true;
        validCategories["Collectibles"] = true;
    }

    modifier onlyValidCategory(string memory category) {
        require(validCategories[category], "Invalid category");
        _;
    }

    // NEW FEATURE 1: Collections
    /**
     * @dev Create a new collection
     * @param name Collection name
     * @param description Collection description
     * @param coverImage Cover image URI
     */
    function createCollection(
        string memory name,
        string memory description,
        string memory coverImage
    ) public returns (uint256) {
        _collectionIds.increment();
        uint256 newCollectionId = _collectionIds.current();
        
        Collection storage collection = idToCollection[newCollectionId];
        collection.collectionId = newCollectionId;
        collection.name = name;
        collection.description = description;
        collection.coverImage = coverImage;
        collection.creator = msg.sender;
        collection.createdAt = block.timestamp;
        collection.verified = false;
        
        emit CollectionCreated(newCollectionId, name, msg.sender);
        return newCollectionId;
    }

    /**
     * @dev Add token to collection
     * @param tokenId Token ID to add
     * @param collectionId Collection ID
     */
    function addTokenToCollection(uint256 tokenId, uint256 collectionId) public {
        require(ownerOf(tokenId) == msg.sender, "Only token owner can add to collection");
        require(idToCollection[collectionId].creator == msg.sender, "Only collection creator can add tokens");
        
        idToMarketItem[tokenId].collectionId = collectionId;
        idToCollection[collectionId].tokenIds.push(tokenId);
        
        emit TokenAddedToCollection(tokenId, collectionId);
    }

    // NEW FEATURE 2: Fractional NFT Ownership
    /**
     * @dev Create fractional ownership for an NFT
     * @param tokenId Token ID to fractionalize
     * @param totalShares Total number of shares
     * @param sharePrice Price per share
     */
    function createFractionalNFT(
        uint256 tokenId,
        uint256 totalShares,
        uint256 sharePrice
    ) public {
        require(ownerOf(tokenId) == msg.sender, "Only token owner can fractionalize");
        require(totalShares > 1, "Must have more than 1 share");
        require(sharePrice > 0, "Share price must be greater than 0");
        
        FractionalNFT storage fractional = idToFractionalNFT[tokenId];
        fractional.tokenId = tokenId;
        fractional.totalShares = totalShares;
        fractional.sharePrice = sharePrice;
        fractional.isActive = true;
        
        // Owner gets all initial shares
        fractional.shareOwnership[msg.sender] = totalShares;
        fractional.shareholders.push(msg.sender);
        
        emit FractionalNFTCreated(tokenId, totalShares, sharePrice);
    }

    /**
     * @dev Buy shares of a fractional NFT
     * @param tokenId Token ID
     * @param shares Number of shares to buy
     */
    function buyShares(uint256 tokenId, uint256 shares) public payable nonReentrant {
        FractionalNFT storage fractional = idToFractionalNFT[tokenId];
        require(fractional.isActive, "Fractional NFT not active");
        require(shares > 0, "Must buy at least 1 share");
        require(msg.value == shares * fractional.sharePrice, "Incorrect payment amount");
        
        // Find a seller with enough shares (simplified - in practice, you'd need a marketplace for shares)
        address seller = fractional.shareholders[0];
        require(fractional.shareOwnership[seller] >= shares, "Not enough shares available");
        
        fractional.shareOwnership[seller] -= shares;
        fractional.shareOwnership[msg.sender] += shares;
        
        if (fractional.shareOwnership[msg.sender] == shares) {
            fractional.shareholders.push(msg.sender);
        }
        
        payable(seller).transfer(msg.value);
        
        emit SharesPurchased(tokenId, msg.sender, shares, msg.value);
    }

    // NEW FEATURE 3: NFT Rentals
    /**
     * @dev List NFT for rent
     * @param tokenId Token ID to rent
     * @param rentPrice Rental price
     * @param maxRentDuration Maximum rental duration in seconds
     */
    function listForRent(
        uint256 tokenId,
        uint256 rentPrice,
        uint256 maxRentDuration
    ) public {
        require(ownerOf(tokenId) == msg.sender, "Only token owner can list for rent");
        
        Rental storage rental = idToRental[tokenId];
        rental.tokenId = tokenId;
        rental.rentPrice = rentPrice;
        rental.rentDuration = maxRentDuration;
        rental.isActive = true;
    }

    /**
     * @dev Rent an NFT
     * @param tokenId Token ID to rent
     * @param duration Rental duration in seconds
     */
    function rentNFT(uint256 tokenId, uint256 duration) public payable nonReentrant {
        Rental storage rental = idToRental[tokenId];
        require(rental.isActive, "NFT not available for rent");
        require(duration <= rental.rentDuration, "Duration exceeds maximum");
        require(msg.value == rental.rentPrice, "Incorrect rental payment");
        
        rental.renter = msg.sender;
        rental.rentStart = block.timestamp;
        rental.rentEnd = block.timestamp + duration;
        rental.isActive = false;
        
        payable(ownerOf(tokenId)).transfer(msg.value);
        
        emit NFTRented(tokenId, msg.sender, rental.rentPrice, duration);
    }

    // NEW FEATURE 4: Bundle Sales
    /**
     * @dev Create a bundle of NFTs for sale
     * @param tokenIds Array of token IDs to bundle
     * @param bundlePrice Price for the entire bundle
     * @param duration Duration for the bundle sale
     */
    function createBundle(
        uint256[] memory tokenIds,
        uint256 bundlePrice,
        uint256 duration
    ) public payable nonReentrant {
        require(tokenIds.length > 1, "Bundle must contain more than 1 NFT");
        require(bundlePrice > 0, "Bundle price must be greater than 0");
        require(msg.value == listingPrice, "Must pay listing fee");
        
        // Verify ownership of all tokens
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(ownerOf(tokenIds[i]) == msg.sender, "Must own all tokens in bundle");
            _transfer(msg.sender, address(this), tokenIds[i]);
        }
        
        _bundleIds.increment();
        uint256 newBundleId = _bundleIds.current();
        
        Bundle storage bundle = idToBundle[newBundleId];
        bundle.bundleId = newBundleId;
        bundle.tokenIds = tokenIds;
        bundle.bundlePrice = bundlePrice;
        bundle.seller = msg.sender;
        bundle.sold = false;
        bundle.createdAt = block.timestamp;
        bundle.expiresAt = duration > 0 ? block.timestamp + duration : 0;
        
        emit BundleCreated(newBundleId, tokenIds, bundlePrice);
    }

    /**
     * @dev Purchase a bundle
     * @param bundleId Bundle ID to purchase
     */
    function purchaseBundle(uint256 bundleId) public payable nonReentrant {
        Bundle storage bundle = idToBundle[bundleId];
        require(!bundle.sold, "Bundle already sold");
        require(msg.value == bundle.bundlePrice, "Incorrect payment amount");
        require(bundle.expiresAt == 0 || block.timestamp < bundle.expiresAt, "Bundle has expired");
        
        bundle.sold = true;
        
        // Transfer all NFTs to buyer
        for (uint256 i = 0; i < bundle.tokenIds.length; i++) {
            _transfer(address(this), msg.sender, bundle.tokenIds[i]);
            idToMarketItem[bundle.tokenIds[i]].owner = payable(msg.sender);
        }
        
        // Pay seller
        payable(bundle.seller).transfer(msg.value);
        
        emit BundleSold(bundleId, msg.sender, bundle.bundlePrice);
    }

    // NEW FEATURE 5: Social Features
    /**
     * @dev Like a token
     * @param tokenId Token ID to like
     */
    function likeToken(uint256 tokenId) public {
        require(!tokenLikes[tokenId][msg.sender], "Already liked");
        
        tokenLikes[tokenId][msg.sender] = true;
        idToMarketItem[tokenId].likes += 1;
        
        emit TokenLiked(tokenId, msg.sender);
    }

    /**
     * @dev Add token to favorites
     * @param tokenId Token ID to add to favorites
     */
    function addToFavorites(uint256 tokenId) public {
        userFavorites[msg.sender].push(tokenId);
    }

    /**
     * @dev Follow a user
     * @param userToFollow Address of user to follow
     */
    function followUser(address userToFollow) public {
        require(userToFollow != msg.sender, "Cannot follow yourself");
        require(!userFollowing[msg.sender][userToFollow], "Already following");
        
        userFollowing[msg.sender][userToFollow] = true;
        userFollowers[userToFollow].push(msg.sender);
        
        emit UserFollowed(msg.sender, userToFollow);
    }

    /**
     * @dev Increment view count for a token
     * @param tokenId Token ID to increment views
     */
    function viewToken(uint256 tokenId) public {
        idToMarketItem[tokenId].views += 1;
    }

    // NEW FEATURE 6: Enhanced Search and Discovery
    /**
     * @dev Get trending NFTs based on views and likes
     */
    function getTrendingNFTs(uint256 limit) public view returns (MarketItem[] memory) {
        uint256 itemCount = _tokenIds.current();
        
        // Simple implementation - in practice, you'd want more sophisticated sorting
        MarketItem[] memory trending = new MarketItem[](limit);
        uint256 addedCount = 0;
        
        for (uint256 i = 1; i <= itemCount && addedCount < limit; i++) {
            if (idToMarketItem[i].views > 0 || idToMarketItem[i].likes > 0) {
                trending[addedCount] = idToMarketItem[i];
                addedCount++;
            }
        }
        
        return trending;
    }

    /**
     * @dev Get user's favorite NFTs
     */
    function getUserFavorites(address user) public view returns (uint256[] memory) {
        return userFavorites[user];
    }

    /**
     * @dev Get collection info
     */
    function getCollection(uint256 collectionId) public view returns (Collection memory) {
        return idToCollection[collectionId];
    }

    /**
     * @dev Get bundle info
     */
    function getBundle(uint256 bundleId) public view returns (Bundle memory) {
        return idToBundle[bundleId];
    }

    // Existing functions remain the same...
    // (All your existing functions like createToken, createMarketSale, etc.)
    
    // NEW: Enhanced auction with reserve price
    function createAuctionWithReserve(
        uint256 tokenId,
        uint256 startingPrice,
        uint256 reservePrice,
        uint256 duration,
        string memory category
    ) 
        public 
        payable 
        nonReentrant
        whenNotPaused
        onlyValidCategory(category)
    {
        require(ownerOf(tokenId) == msg.sender, "Only token owner can create auction");
        require(msg.value == listingPrice, "Price must be equal to listing price");
        require(startingPrice > 0, "Starting price must be greater than 0");
        require(reservePrice >= startingPrice, "Reserve price must be >= starting price");
        require(duration > 0, "Duration must be greater than 0");

        uint256 auctionEnd = block.timestamp + duration;

        idToMarketItem[tokenId] = MarketItem(
            tokenId,
            payable(msg.sender),
            payable(address(this)),
            payable(msg.sender),
            startingPrice,
            block.timestamp,
            auctionEnd,
            false,
            true,
            category,
            0, // collectionId
            0, // views
            0  // likes
        );

        Auction storage auction = idToAuction[tokenId];
        auction.tokenId = tokenId;
        auction.startingPrice = startingPrice;
        auction.reservePrice = reservePrice;
        auction.auctionEnd = auctionEnd;
        auction.ended = false;

        _transfer(msg.sender, address(this), tokenId);

        emit AuctionCreated(tokenId, startingPrice, auctionEnd);
    }
}
