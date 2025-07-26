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
    uint256 public royaltyPercentage = 250; // 2.5%

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

    modifier onlyTokenOwner(uint256 tokenId) {
        require(ownerOf(tokenId) == msg.sender, "Not token owner");
        _;
    }

    // ========== Structs ==========
    struct Collection { uint256 collectionId; string name; string description; string coverImage; address creator; uint256 createdAt; bool verified; uint256[] tokenIds; }
    struct FractionalNFT { uint256 tokenId; uint256 totalShares; uint256 sharePrice; mapping(address => uint256) shareOwnership; address[] shareholders; bool isActive; }
    struct Rental { uint256 tokenId; address renter; uint256 rentPrice; uint256 rentDuration; uint256 rentStart; uint256 rentEnd; bool isActive; }
    struct Bundle { uint256 bundleId; uint256[] tokenIds; uint256 bundlePrice; address seller; bool sold; uint256 createdAt; uint256 expiresAt; }
    struct MarketItem { uint256 tokenId; address payable seller; address payable owner; address payable creator; uint256 price; uint256 createdAt; uint256 expiresAt; bool sold; bool isAuction; string category; uint256 collectionId; uint256 views; uint256 likes; }
    struct Auction { uint256 tokenId; uint256 startingPrice; uint256 highestBid; address highestBidder; uint256 auctionEnd; bool ended; mapping(address => uint256) pendingReturns; uint256 reservePrice; }
    struct Offer { uint256 tokenId; address buyer; uint256 amount; uint256 expiry; bool accepted; }
    struct Report { uint256 tokenId; address reporter; string reason; uint256 timestamp; }
    struct Comment { address commenter; string message; uint256 timestamp; }

    // ========== Mappings ==========
    mapping(uint256 => MarketItem) private idToMarketItem;
    mapping(uint256 => Auction) private idToAuction;
    mapping(uint256 => Offer[]) private tokenOffers;
    mapping(uint256 => Collection) private idToCollection;
    mapping(uint256 => FractionalNFT) private idToFractionalNFT;
    mapping(uint256 => Rental) private idToRental;
    mapping(uint256 => Bundle) private idToBundle;
    mapping(uint256 => Comment[]) private tokenComments;

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

    // ========== Events ==========
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

    // ========== New: Rent ==========
    function rentNFT(uint256 tokenId, uint256 durationInSeconds) public payable {
        Rental storage rent = idToRental[tokenId];
        require(!rent.isActive, "Already rented");
        require(ownerOf(tokenId) != msg.sender, "Owner can't rent");

        uint256 rentPrice = idToMarketItem[tokenId].price;
        require(msg.value == rentPrice, "Incorrect rent amount");

        rent.tokenId = tokenId;
        rent.renter = msg.sender;
        rent.rentPrice = msg.value;
        rent.rentDuration = durationInSeconds;
        rent.rentStart = block.timestamp;
        rent.rentEnd = block.timestamp + durationInSeconds;
        rent.isActive = true;

        payable(ownerOf(tokenId)).transfer(msg.value);
        boostReputationOnRental(msg.sender);
        emit NFTRented(tokenId, msg.sender, msg.value, durationInSeconds);
    }

    function isCurrentlyRented(uint256 tokenId) public view returns (bool) {
        Rental memory rent = idToRental[tokenId];
        return rent.isActive && block.timestamp < rent.rentEnd;
    }

    // ========== New: Auction Finalization ==========
    function finalizeAuction(uint256 tokenId) public {
        Auction storage auction = idToAuction[tokenId];
        require(block.timestamp >= auction.auctionEnd, "Auction not ended");
        require(!auction.ended, "Already finalized");
        require(auction.highestBidder != address(0), "No bids");

        auction.ended = true;

        address payable seller = idToMarketItem[tokenId].seller;
        seller.transfer(auction.highestBid);
        _transfer(address(this), auction.highestBidder, tokenId);

        emit AuctionFinalized(tokenId, auction.highestBidder, auction.highestBid);
    }

    // ========== New: Withdraw Pending Bids ==========
    function withdrawAuctionBid(uint256 tokenId) public {
        Auction storage auction = idToAuction[tokenId];
        uint256 amount = auction.pendingReturns[msg.sender];
        require(amount > 0, "No funds");
        auction.pendingReturns[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

    // ========== New: Batch Minting ==========
    function batchMint(string[] memory tokenURIs) public {
        uint256[] memory newTokenIds = new uint256[](tokenURIs.length);
        for (uint256 i = 0; i < tokenURIs.length; i++) {
            _tokenIds.increment();
            uint256 tokenId = _tokenIds.current();
            _mint(msg.sender, tokenId);
            _setTokenURI(tokenId, tokenURIs[i]);
            newTokenIds[i] = tokenId;
        }
        emit NFTBatchMinted(msg.sender, newTokenIds);
    }

    // ========== New: Share Transfer ==========
    function transferShares(uint256 tokenId, address to, uint256 shares) public {
        FractionalNFT storage frac = idToFractionalNFT[tokenId];
        require(frac.shareOwnership[msg.sender] >= shares, "Not enough shares");
        frac.shareOwnership[msg.sender] -= shares;
        frac.shareOwnership[to] += shares;
        emit ShareTransferred(tokenId, msg.sender, to, shares);
    }

    // ========== New: Royalties ==========
    function payRoyalty(address creator, uint256 salePrice) internal {
        uint256 royalty = (salePrice * royaltyPercentage) / 10000;
        creator.transfer(royalty);
        creatorEarnings[creator] += royalty;
        emit RoyaltyPaid(creator, royalty);
    }

    function getCreatorEarnings(address creator) public view returns (uint256) {
        return creatorEarnings[creator];
    }

    // ========== Admin ==========
    function pauseMarketplace() public onlyOwner {
        _pause();
    }

    function unpauseMarketplace() public onlyOwner {
        _unpause();
    }

    // ========== Existing Core Features like completeMarketSale, boostReputation, reportToken, burnNFT, etc remain unchanged ==========
}
