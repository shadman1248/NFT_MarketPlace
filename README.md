# NFT Marketplace

A decentralized NFT marketplace built on Core Testnet 2 using Solidity and Hardhat, enabling users to mint, buy, sell, and trade non-fungible tokens in a trustless environment.

## Project Description

The NFT Marketplace is a comprehensive smart contract solution that facilitates the creation, listing, and trading of NFTs. Built on the Core blockchain testnet, this marketplace provides a secure and efficient platform for digital asset transactions. The contract combines ERC-721 functionality with marketplace logic, allowing users to mint new NFTs directly to the marketplace or list existing NFTs for sale.

The platform implements a fee-based system where users pay a small listing fee to create or list NFTs, ensuring sustainable marketplace operations. The contract includes essential marketplace features such as direct purchases, reselling capabilities, and comprehensive item tracking.

## Project Vision

Our vision is to create a user-friendly, secure, and decentralized NFT marketplace that empowers creators and collectors to participate in the digital economy. We aim to build a platform that:

- **Democratizes NFT Creation**: Makes it easy for anyone to mint and sell NFTs
- **Ensures Fair Trading**: Implements transparent pricing and secure transactions
- **Builds Community**: Connects creators with collectors in a trustless environment
- **Promotes Innovation**: Provides a foundation for advanced NFT utilities and features
- **Maintains Security**: Prioritizes user fund safety and smart contract security

## Key Features

### Core Functionality
- **NFT Minting**: Create new NFTs with custom metadata and URI
- **Marketplace Listing**: List NFTs for sale with custom pricing
- **Direct Purchase**: Buy NFTs instantly at listed prices
- **Reselling**: Relist purchased NFTs at new prices
- **Ownership Tracking**: Complete transaction and ownership history

### Technical Features
- **ERC-721 Compliance**: Full NFT standard implementation
- **Reentrancy Protection**: Secure against common attack vectors
- **Gas Optimization**: Efficient contract design for lower transaction costs
- **Event Logging**: Comprehensive event emission for frontend integration
- **Access Control**: Owner-only administrative functions

### User Experience
- **Portfolio Management**: View owned NFTs and listed items
- **Market Discovery**: Browse all available NFTs in the marketplace
- **Transaction History**: Track all marketplace activities
- **Flexible Pricing**: Set custom prices for NFT listings
- **Instant Transfers**: Immediate ownership transfer upon purchase

### Security Measures
- **ReentrancyGuard**: Protection against reentrancy attacks
- **Input Validation**: Comprehensive parameter checking
- **Safe Transfers**: Secure ETH and NFT transfer mechanisms
- **Owner Controls**: Administrative functions for marketplace management

## Future Scope

### Phase 1: Enhanced Features
- **Auction System**: Implement time-based bidding mechanisms
- **Offer System**: Allow users to make offers on NFTs
- **Collection Support**: Group NFTs into collections
- **Advanced Search**: Filter and search functionality
- **Batch Operations**: Multiple NFT operations in single transaction

### Phase 2: Advanced Functionality
- **Royalty System**: Automatic creator royalty distribution
- **Multi-token Support**: Accept various ERC-20 tokens as payment
- **Fractionalized NFTs**: Enable partial ownership of high-value NFTs
- **Cross-chain Support**: Bridge to other blockchain networks
- **Governance Token**: Community-driven marketplace decisions

### Phase 3: Ecosystem Expansion
- **Creator Tools**: Advanced minting and management interfaces
- **Analytics Dashboard**: Market insights and trading statistics
- **Mobile Integration**: Native mobile app development
- **DeFi Integration**: Lending and borrowing against NFTs
- **Metaverse Integration**: Virtual world compatibility

### Phase 4: Enterprise Solutions
- **Brand Partnerships**: White-label marketplace solutions
- **API Services**: Developer tools and marketplace APIs
- **Layer 2 Integration**: Scaling solutions for high-volume trading
- **AI Integration**: Automated pricing and recommendation systems
- **Compliance Tools**: KYC/AML integration for institutional users

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/nft-marketplace.git
cd nft-marketplace
```

2. Install dependencies:
```bash
npm install
```

3. Create a `.env` file and add your configuration:
```bash
cp .env.example .env
# Edit .env with your private key and other configurations
```

4. Compile the contracts:
```bash
npm run compile
```

5. Run tests:
```bash
npm run test
```

6. Deploy to Core Testnet 2:
```bash
npm run deploy
```

## Usage

### Deployment
The contract can be deployed to Core Testnet 2 using the provided deployment script:

```bash
npx hardhat run scripts/deploy.js --network core_testnet2
```

### Interacting with the Contract

#### Minting and Listing NFTs
```javascript
// Mint a new NFT and list it for sale
await nftMarketplace.createToken("ipfs://your-metadata-uri", ethers.utils.parseEther("1"), {
  value: listingPrice
});
```

#### Purchasing NFTs
```javascript
// Buy an NFT from the marketplace
await nftMarketplace.createMarketSale(tokenId, {
  value: itemPrice
});
```

#### Reselling NFTs
```javascript
// List an owned NFT for resale
await nftMarketplace.resellToken(tokenId, ethers.utils.parseEther("2"), {
  value: listingPrice
});
```

## Contract Architecture

The NFTMarketplace contract inherits from:
- `ERC721URIStorage`: For NFT functionality with metadata
- `ReentrancyGuard`: For security against reentrancy attacks
- `Ownable`: For administrative functions

## Network Information

- **Network**: Core Testnet 2
- **RPC URL**: https://rpc.test2.btcs.network
- **Chain ID**: 1115
- **Block Explorer**: https://scan.test2.btcs.network

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions:
- Create an issue in the GitHub repository
- Join our community discussions
- Check the documentation

---

**Built with ❤️ for the decentralized future**
