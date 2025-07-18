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

    uint256 public listingPrice = 0.025 ether;
    uint256 public royaltyPercentage = 250; // 2.5% in basis points (100 basis points = 1%)
    
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
    }

    struct Auction {
        uint256 tokenId;
        uint256 startingPrice;
        uint256 highestBid;
        address highestBidder;
        uint256 auctionEnd;
        bool ended;
        mapping(address => uint256) pendingReturns;
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
        uint256 price
    );

    event AuctionCreated(
        uint256 indexed tokenId,
        uint256 startingPrice,
        uint256 auctionEnd
    );

    event BidPlaced(
        uint256 indexed tokenId,
        address bidder,
        uint256 amount
    );

    event AuctionEnded(
        uint256 indexed tokenId,
        address winner,
        uint256 amount
    );

    event OfferMade(
        uint256 indexed tokenId,
        address buyer,
        uint256 amount,
        uint256 expiry
    );

    event OfferAccepted(
        uint256 indexed tokenId,
        address buyer,
        uint256 amount
    );

    event CreatorVerified(address indexed creator);
    event RoyaltyPaid(address indexed creator, uint256 amount);

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

    /**
     * @dev Updates the listing price of the contract
     * @param _listingPrice New listing price
     */
    function updateListingPrice(uint256 _listingPrice) public onlyOwner {
        listingPrice = _listingPrice;
    }

    /**
     * @dev Updates the royalty percentage
     * @param _royaltyPercentage New royalty percentage in basis points
     */
    function updateRoyaltyPercentage(uint256 _royaltyPercentage) public onlyOwner {
        require(_royaltyPercentage <= 1000, "Royalty too high"); // Max 10%
        royaltyPercentage = _royaltyPercentage;
    }

    /**
     * @dev Returns the listing price of the contract
     */
    function getListingPrice() public view returns (uint256) {
        return listingPrice;
    }

    /**
     * @dev Add a new valid category
     * @param category The category to add
     */
    function addCategory(string memory category) public onlyOwner {
        validCategories[category] = true;
    }

    /**
     * @dev Verify a creator
     * @param creator The creator address to verify
     */
    function verifyCreator(address creator) public onlyOwner {
        verifiedCreators[creator] = true;
        emit CreatorVerified(creator);
    }

    /**
     * @dev Check if a creator is verified
     * @param creator The creator address to check
     */
    function isCreatorVerified(address creator) public view returns (bool) {
        return verifiedCreators[creator];
    }

    /**
     * @dev Pause the contract
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause the contract
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    /**
     * @dev Mints a token and lists it in the marketplace
     * @param tokenURI The URI for the token metadata
     * @param price The price for the token
     * @param category The category of the NFT
     * @param duration Duration in seconds for the listing (0 for no expiry)
     */
    function createToken(
        string memory tokenURI, 
        uint256 price,
        string memory category,
        uint256 duration
    ) 
        public 
        payable 
        nonReentrant
        whenNotPaused
        onlyValidCategory(category)
        returns (uint256) 
    {
        require(msg.value == listingPrice, "Price must be equal to listing price");
        require(price > 0, "Price must be greater than 0");

        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();

        _mint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, tokenURI);
        
        createMarketItem(newTokenId, price, category, duration);
        
        return newTokenId;
    }

    /**
     * @dev Creates a market item for an existing token
     * @param tokenId The token ID to list
     * @param price The price for the token
     * @param category The category of the NFT
     * @param duration Duration in seconds for the listing (0 for no expiry)
     */
    function createMarketItem(
        uint256 tokenId, 
        uint256 price,
        string memory category,
        uint256 duration
    ) 
        private 
    {
        require(price > 0, "Price must be greater than 0");
        require(msg.value == listingPrice, "Price must be equal to listing price");

        uint256 expiresAt = duration > 0 ? block.timestamp + duration : 0;

        idToMarketItem[tokenId] = MarketItem(
            tokenId,
            payable(msg.sender),
            payable(address(this)),
            payable(msg.sender), // Creator is the initial seller
            price,
            block.timestamp,
            expiresAt,
            false,
            false,
            category
        );

        _transfer(msg.sender, address(this), tokenId);

        emit MarketItemCreated(
            tokenId,
            msg.sender,
            address(this),
            price,
            false,
            category
        );
    }

    /**
     * @dev Create an auction for a token
     * @param tokenId The token ID to auction
     * @param startingPrice The starting price for the auction
     * @param duration Duration in seconds for the auction
     * @param category The category of the NFT
     */
    function createAuction(
        uint256 tokenId,
        uint256 startingPrice,
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
            category
        );

        Auction storage auction = idToAuction[tokenId];
        auction.tokenId = tokenId;
        auction.startingPrice = startingPrice;
        auction.auctionEnd = auctionEnd;
        auction.ended = false;

        _transfer(msg.sender, address(this), tokenId);

        emit AuctionCreated(tokenId, startingPrice, auctionEnd);
    }

    /**
     * @dev Bid on an auction
     * @param tokenId The token ID to bid on
     */
    function bid(uint256 tokenId) public payable nonReentrant whenNotPaused {
        Auction storage auction = idToAuction[tokenId];
        MarketItem storage item = idToMarketItem[tokenId];

        require(item.isAuction, "Not an auction");
        require(block.timestamp < auction.auctionEnd, "Auction has ended");
        require(msg.value > auction.highestBid, "Bid too low");
        require(msg.value >= auction.startingPrice, "Bid below starting price");

        // Return money to previous highest bidder
        if (auction.highestBidder != address(0)) {
            auction.pendingReturns[auction.highestBidder] += auction.highestBid;
        }

        auction.highestBidder = msg.sender;
        auction.highestBid = msg.value;

        emit BidPlaced(tokenId, msg.sender, msg.value);
    }

    /**
     * @dev End an auction
     * @param tokenId The token ID of the auction to end
     */
    function endAuction(uint256 tokenId) public nonReentrant whenNotPaused {
        Auction storage auction = idToAuction[tokenId];
        MarketItem storage item = idToMarketItem[tokenId];

        require(item.isAuction, "Not an auction");
        require(block.timestamp >= auction.auctionEnd, "Auction not yet ended");
        require(!auction.ended, "Auction already ended");

        auction.ended = true;

        if (auction.highestBidder != address(0)) {
            // Transfer NFT to highest bidder
            item.owner = payable(auction.highestBidder);
            item.sold = true;
            _itemsSold.increment();
            
            _transfer(address(this), auction.highestBidder, tokenId);

            // Pay royalty to creator
            uint256 royaltyAmount = (auction.highestBid * royaltyPercentage) / 10000;
            if (royaltyAmount > 0 && item.creator != item.seller) {
                creatorEarnings[item.creator] += royaltyAmount;
                payable(item.creator).transfer(royaltyAmount);
                emit RoyaltyPaid(item.creator, royaltyAmount);
            }

            // Pay marketplace fee and seller
            uint256 marketplaceFee = listingPrice;
            uint256 sellerAmount = auction.highestBid - royaltyAmount;
            
            payable(owner()).transfer(marketplaceFee);
            payable(item.seller).transfer(sellerAmount);

            emit AuctionEnded(tokenId, auction.highestBidder, auction.highestBid);
        } else {
            // No bids, return NFT to seller
            _transfer(address(this), item.seller, tokenId);
        }
    }

    /**
     * @dev Withdraw pending returns from failed auction bids
     */
    function withdrawPendingReturns(uint256 tokenId) public nonReentrant {
        Auction storage auction = idToAuction[tokenId];
        uint256 amount = auction.pendingReturns[msg.sender];
        
        require(amount > 0, "No pending returns");
        
        auction.pendingReturns[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

    /**
     * @dev Make an offer on a token
     * @param tokenId The token ID to make an offer on
     * @param duration Duration in seconds for the offer
     */
    function makeOffer(uint256 tokenId, uint256 duration) 
        public 
        payable 
        nonReentrant 
        whenNotPaused 
    {
        require(msg.value > 0, "Offer must be greater than 0");
        require(duration > 0, "Duration must be greater than 0");
        require(idToMarketItem[tokenId].tokenId == tokenId, "Token does not exist");

        uint256 expiry = block.timestamp + duration;

        tokenOffers[tokenId].push(Offer({
            tokenId: tokenId,
            buyer: msg.sender,
            amount: msg.value,
            expiry: expiry,
            accepted: false
        }));

        emit OfferMade(tokenId, msg.sender, msg.value, expiry);
    }

    /**
     * @dev Accept an offer on a token
     * @param tokenId The token ID
     * @param offerIndex The index of the offer to accept
     */
    function acceptOffer(uint256 tokenId, uint256 offerIndex) 
        public 
        nonReentrant 
        whenNotPaused 
    {
        MarketItem storage item = idToMarketItem[tokenId];
        require(item.seller == msg.sender, "Only seller can accept offers");
        require(offerIndex < tokenOffers[tokenId].length, "Invalid offer index");

        Offer storage offer = tokenOffers[tokenId][offerIndex];
        require(offer.expiry > block.timestamp, "Offer has expired");
        require(!offer.accepted, "Offer already accepted");

        offer.accepted = true;
        item.owner = payable(offer.buyer);
        item.sold = true;
        _itemsSold.increment();

        _transfer(address(this), offer.buyer, tokenId);

        // Pay royalty to creator
        uint256 royaltyAmount = (offer.amount * royaltyPercentage) / 10000;
        if (royaltyAmount > 0 && item.creator != item.seller) {
            creatorEarnings[item.creator] += royaltyAmount;
            payable(item.creator).transfer(royaltyAmount);
            emit RoyaltyPaid(item.creator, royaltyAmount);
        }

        // Pay marketplace fee and seller
        uint256 marketplaceFee = listingPrice;
        uint256 sellerAmount = offer.amount - royaltyAmount;
        
        payable(owner()).transfer(marketplaceFee);
        payable(item.seller).transfer(sellerAmount);

        emit OfferAccepted(tokenId, offer.buyer, offer.amount);
    }

    /**
     * @dev Allows someone to resell a token they have purchased
     * @param tokenId The token ID to resell
     * @param price The new price for the token
     * @param category The category of the NFT
     * @param duration Duration in seconds for the listing (0 for no expiry)
     */
    function resellToken(
        uint256 tokenId, 
        uint256 price,
        string memory category,
        uint256 duration
    ) 
        public 
        payable 
        nonReentrant
        whenNotPaused
        onlyValidCategory(category)
    {
        require(idToMarketItem[tokenId].owner == msg.sender, "Only item owner can perform this operation");
        require(msg.value == listingPrice, "Price must be equal to listing price");
        require(price > 0, "Price must be greater than 0");

        uint256 expiresAt = duration > 0 ? block.timestamp + duration : 0;

        idToMarketItem[tokenId].sold = false;
        idToMarketItem[tokenId].price = price;
        idToMarketItem[tokenId].seller = payable(msg.sender);
        idToMarketItem[tokenId].owner = payable(address(this));
        idToMarketItem[tokenId].createdAt = block.timestamp;
        idToMarketItem[tokenId].expiresAt = expiresAt;
        idToMarketItem[tokenId].isAuction = false;
        idToMarketItem[tokenId].category = category;
        
        _itemsSold.decrement();

        _transfer(msg.sender, address(this), tokenId);
    }

    /**
     * @dev Creates the sale of a marketplace item
     * @param tokenId The token ID to purchase
     */
    function createMarketSale(uint256 tokenId) 
        public 
        payable 
        nonReentrant
        whenNotPaused
    {
        MarketItem storage item = idToMarketItem[tokenId];
        uint256 price = item.price;
        address seller = item.seller;
        
        require(msg.value == price, "Please submit the asking price in order to complete the purchase");
        require(!item.sold, "This Sale has already been completed");
        require(!item.isAuction, "This is an auction item");
        require(item.expiresAt == 0 || block.timestamp < item.expiresAt, "Listing has expired");

        item.owner = payable(msg.sender);
        item.sold = true;
        item.seller = payable(address(0));
        
        _itemsSold.increment();
        _transfer(address(this), msg.sender, tokenId);

        // Pay royalty to creator
        uint256 royaltyAmount = (price * royaltyPercentage) / 10000;
        if (royaltyAmount > 0 && item.creator != seller) {
            creatorEarnings[item.creator] += royaltyAmount;
            payable(item.creator).transfer(royaltyAmount);
            emit RoyaltyPaid(item.creator, royaltyAmount);
        }

        // Pay marketplace fee and seller
        uint256 marketplaceFee = listingPrice;
        uint256 sellerAmount = price - royaltyAmount;
        
        payable(owner()).transfer(marketplaceFee);
        payable(seller).transfer(sellerAmount);

        emit MarketItemSold(tokenId, seller, msg.sender, price);
    }

    /**
     * @dev Returns all unsold market items
     */
    function fetchMarketItems() public view returns (MarketItem[] memory) {
        uint256 itemCount = _tokenIds.current();
        uint256 unsoldItemCount = _tokenIds.current() - _itemsSold.current();
        uint256 currentIndex = 0;

        MarketItem[] memory items = new MarketItem[](unsoldItemCount);
        for (uint256 i = 0; i < itemCount; i++) {
            if (idToMarketItem[i + 1].owner == address(this) && 
                !idToMarketItem[i + 1].sold &&
                (idToMarketItem[i + 1].expiresAt == 0 || block.timestamp < idToMarketItem[i + 1].expiresAt)) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    /**
     * @dev Returns market items by category
     * @param category The category to filter by
     */
    function fetchMarketItemsByCategory(string memory category) 
        public 
        view 
        returns (MarketItem[] memory) 
    {
        uint256 itemCount = _tokenIds.current();
        uint256 categoryItemCount = 0;
        uint256 currentIndex = 0;

        // Count items in category
        for (uint256 i = 0; i < itemCount; i++) {
            if (idToMarketItem[i + 1].owner == address(this) && 
                !idToMarketItem[i + 1].sold &&
                keccak256(bytes(idToMarketItem[i + 1].category)) == keccak256(bytes(category)) &&
                (idToMarketItem[i + 1].expiresAt == 0 || block.timestamp < idToMarketItem[i + 1].expiresAt)) {
                categoryItemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](categoryItemCount);
        for (uint256 i = 0; i < itemCount; i++) {
            if (idToMarketItem[i + 1].owner == address(this) && 
                !idToMarketItem[i + 1].sold &&
                keccak256(bytes(idToMarketItem[i + 1].category)) == keccak256(bytes(category)) &&
                (idToMarketItem[i + 1].expiresAt == 0 || block.timestamp < idToMarketItem[i + 1].expiresAt)) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    /**
     * @dev Returns only items that a user has purchased
     */
    function fetchMyNFTs() public view returns (MarketItem[] memory) {
        uint256 totalItemCount = _tokenIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].owner == msg.sender) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].owner == msg.sender) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    /**
     * @dev Returns only items a user has listed
     */
    function fetchItemsListed() public view returns (MarketItem[] memory) {
        uint256 totalItemCount = _tokenIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].seller == msg.sender) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].seller == msg.sender) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    /**
     * @dev Get offers for a token
     * @param tokenId The token ID
     */
    function getTokenOffers(uint256 tokenId) public view returns (Offer[] memory) {
        return tokenOffers[tokenId];
    }

    /**
     * @dev Get auction info for a token
     * @param tokenId The token ID
     */
    function getAuctionInfo(uint256 tokenId) public view returns (
        uint256 startingPrice,
        uint256 highestBid,
        address highestBidder,
        uint256 auctionEnd,
        bool ended
    ) {
        Auction storage auction = idToAuction[tokenId];
        return (
            auction.startingPrice,
            auction.highestBid,
            auction.highestBidder,
            auction.auctionEnd,
            auction.ended
        );
    }

    /**
     * @dev Get market item by token ID
     */
    function getMarketItem(uint256 tokenId) public view returns (MarketItem memory) {
        return idToMarketItem[tokenId];
    }

    /**
     * @dev Get creator earnings
     * @param creator The creator address
     */
    function getCreatorEarnings(address creator) public view returns (uint256) {
        return creatorEarnings[creator];
    }

    /**
     * @dev Withdraw creator earnings
     */
    function withdrawCreatorEarnings() public nonReentrant {
        uint256 earnings = creatorEarnings[msg.sender];
        require(earnings > 0, "No earnings to withdraw");
        
        creatorEarnings[msg.sender] = 0;
        payable(msg.sender).transfer(earnings);
    }

    /**
     * @dev Withdraw contract balance (only owner)
     */
    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        
        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");
    }

    /**
     * @dev Emergency function to remove expired listings
     * @param tokenId The token ID to remove
     */
    function removeExpiredListing(uint256 tokenId) public {
        MarketItem storage item = idToMarketItem[tokenId];
        require(item.expiresAt > 0 && block.timestamp >= item.expiresAt, "Listing not expired");
        require(!item.sold, "Item already sold");
        
        // Return NFT to seller
        _transfer(address(this), item.seller, tokenId);
        
        // Mark as sold to remove from active listings
        item.sold = true;
        item.owner = item.seller;
    }
}
