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
    Counters.Counter private _bundleIds;

    uint256 public listingPrice = 0.025 ether;
    uint256 public royaltyPercentage = 250; // 2.5% in basis points

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

    struct FractionalNFT {
        uint256 tokenId;
        uint256 totalShares;
        uint256 sharePrice;
        mapping(address => uint256) shareOwnership;
        address[] shareholders;
        bool isActive;
    }

    struct Rental {
        uint256 tokenId;
        address renter;
        uint256 rentPrice;
        uint256 rentDuration;
        uint256 rentStart;
        uint256 rentEnd;
        bool isActive;
    }

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
        uint256 collectionId;
        uint256 views;
        uint256 likes;
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

    mapping(uint256 => Collection) private idToCollection;
    mapping(uint256 => FractionalNFT) private idToFractionalNFT;
    mapping(uint256 => Rental) private idToRental;
    mapping(uint256 => Bundle) private idToBundle;
    mapping(uint256 => mapping(address => bool)) private tokenLikes;
    mapping(address => uint256[]) private userFavorites;
    mapping(address => mapping(address => bool)) private userFollowing;
    mapping(address => address[]) private userFollowers;
    mapping(address => uint256) private userReputationScore;

    event MarketItemCreated(uint256 indexed tokenId, address seller, address owner, uint256 price, bool sold, string category);
    event MarketItemSold(uint256 indexed tokenId, address seller, address buyer, uint256 price);
    event AuctionCreated(uint256 indexed tokenId, uint256 startingPrice, uint256 auctionEnd);
    event BidPlaced(uint256 indexed tokenId, address bidder, uint256 amount);
    event AuctionEnded(uint256 indexed tokenId, address winner, uint256 amount);
    event OfferMade(uint256 indexed tokenId, address buyer, uint256 amount, uint256 expiry);
    event OfferAccepted(uint256 indexed tokenId, address buyer, uint256 amount);
    event CreatorVerified(address indexed creator);
    event RoyaltyPaid(address indexed creator, uint256 amount);

    event CollectionCreated(uint256 indexed collectionId, string name, address creator);
    event TokenAddedToCollection(uint256 indexed tokenId, uint256 indexed collectionId);
    event FractionalNFTCreated(uint256 indexed tokenId, uint256 totalShares, uint256 sharePrice);
    event SharesPurchased(uint256 indexed tokenId, address buyer, uint256 shares, uint256 amount);
    event NFTRented(uint256 indexed tokenId, address renter, uint256 rentPrice, uint256 duration);
    event BundleCreated(uint256 indexed bundleId, uint256[] tokenIds, uint256 bundlePrice);
    event BundleSold(uint256 indexed bundleId, address buyer, uint256 price);
    event TokenLiked(uint256 indexed tokenId, address liker);
    event UserFollowed(address indexed follower, address indexed following);
    event ReputationBoosted(address indexed user, uint256 newScore);

    constructor() ERC721("NFT Marketplace", "NFTM") Ownable(msg.sender) {
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

    // Collection, Fractional, Rental, Bundle, Social, Discovery, Auction functions...
    // (As included in your previous long code - unchanged)

    // ✅ NEW FUNCTION: Boost Reputation on Successful Sale
    function boostReputationOnSale(address user) internal {
        userReputationScore[user] += 10;
        emit ReputationBoosted(user, userReputationScore[user]);
    }

    // Example update (you can use boostReputationOnSale in your existing sale function like this):
    function completeMarketSale(uint256 tokenId) public payable nonReentrant {
        MarketItem storage item = idToMarketItem[tokenId];
        require(msg.value == item.price, "Please submit the asking price");
        require(!item.sold, "Item already sold");

        item.owner = payable(msg.sender);
        item.sold = true;
        _itemsSold.increment();

        _transfer(address(this), msg.sender, tokenId);
        item.seller.transfer(msg.value);

        boostReputationOnSale(item.seller);

        emit MarketItemSold(tokenId, item.seller, msg.sender, item.price);
    }

    // You can also add a public getter for reputation if needed:
    function getUserReputation(address user) public view returns (uint256) {
        return userReputationScore[user];
    }
}
