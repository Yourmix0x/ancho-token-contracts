## AnchoToken - Advanced DeFi Token Ecosystem

A comprehensive ERC-20 token ecosystem featuring automated taxes, holder reflections, provably-fair lottery system, and cross-chain functionality.

## 🎯 **Features**

### **Core Token Mechanics**

- **Fixed Supply**: 777,777,777 ANCHO tokens (never inflates)
- **Tax System**: 2% tax on all transfers (1% to treasury, 1% to lottery vault)
- **Reflection Rewards**: 0.5% of each transaction redistributed to all holders
- **Deflationary**: Tax mechanism reduces circulating supply over time

### **Provably-Fair Lottery**

- **Chainlink VRF**: Cryptographically secure random winner selection
- **Scheduled Draws**: Automatic draws on 7th, 17th, and 27th of each month
- **Prize Pool**: 25% of vault balance (capped at 7M tokens)
- **Entry Requirement**: Hold minimum 777 ANCHO tokens

### **Governance & Security**

- **48-Hour Timelock**: All critical parameter changes require 2-day delay
- **Emergency Controls**: Circuit breaker and blacklist functionality
- **Multi-Role Access**: Owner, emergency admin, and timelock controls
- **Pausable Transfers**: Emergency stop functionality

### **Cross-Chain Ready**

- **Bridge Contract**: Token locking mechanism for cross-chain transfers
- **Multi-Network**: Designed for Base, Ethereum, and Arbitrum deployment
- **7M Token Bridge Limit**: Controlled cross-chain migration

## 📊 **Tokenomics Breakdown**

```
Every Transfer (Example: 1,000 ANCHO):
├── Recipient receives: 975 ANCHO (97.5%)
├── Treasury gets: 10 ANCHO (1%)
├── Lottery Vault gets: 10 ANCHO (1%)
└── All Holders get: 5 ANCHO (0.5% reflection)

Total Tax: 2.5% (2% explicit + 0.5% reflection)
```

## 🏗️ **Architecture**

### **Smart Contracts**

- **AnchoToken.sol**: Main ERC-20 token with tax and reflection
- **Lottery.sol**: Chainlink VRF-powered lottery system
- **Bridge.sol**: Cross-chain token bridge
- **AnchoTimelock.sol**: Governance timelock for security

## 🚀 **Deployment**

### **Prerequisites**

- [Foundry](https://getfoundry.sh/) installed
- Sepolia/Mainnet ETH for gas
- [Chainlink VRF Subscription](https://vrf.chain.link/)
- RPC URL (Alchemy/Infura)

### **Environment Setup**

```bash
# Copy environment template
cp .env.example .env

# Edit .env with your values:
PRIVATE_KEY=your_private_key_here
VRF_SUBSCRIPTION_ID=your_subscription_id
SEPOLIA_RPC_URL=your_rpc_url
```

### **Deploy to Sepolia**

```bash
# Compile contracts
forge build

# Deploy to Sepolia testnet
forge script script/Deploy.s.sol:DeployScript --rpc-url sepolia --broadcast

# Verify contracts (optional)
forge script script/Deploy.s.sol:DeployScript --rpc-url sepolia --broadcast --verify
```

## 🧪 **Testing**

```bash
# Run all tests
forge test

# Run specific test contract
forge test --match-contract AnchoTokenTest

# Run with verbose output
forge test -vvv

# Generate gas report
forge test --gas-report
```

## 📱 **Usage Examples**

### **Basic Token Operations**

```solidity
// Transfer tokens (includes automatic tax and reflection)
token.transfer(recipient, 1000 * 10**18);

// Check reflection balance
uint256 reflectedBalance = token.getReflectionBalance(user);
```

### **Lottery Participation**

```solidity
// Owner opens lottery
lottery.openLottery();

// Users enter (requires 777+ tokens)
lottery.enterLottery();

// Anyone can start draw on valid dates (7th, 17th, 27th)
lottery.startDraw();
```

### **Governance Operations**

```solidity
// Schedule tax rate change (requires 48-hour delay)
bytes32 opId = timelock.scheduleTaxChange(150); // 1.5%

// Execute after delay
timelock.executeTaxChange(tokenAddress, 150);
```

## 🔒 **Security Features**

- **OpenZeppelin Contracts**: Built on battle-tested libraries
- **Reentrancy Protection**: SafeERC20 patterns throughout
- **Access Control**: Multi-layered permission system
- **Emergency Pause**: Circuit breaker for critical issues
- **Timelock Governance**: Prevents sudden parameter changes

## 🌐 **Network Support**

| Network      | Status      | Chain ID |
| ------------ | ----------- | -------- |
| Base Sepolia | ✅ Deployed | 84532    |
| Base Mainnet | 🔄 Planned  | 8453     |
| Ethereum     | 🔄 Planned  | 1        |
| Arbitrum     | 🔄 Planned  | 42161    |

## 📈 **Roadmap**

- [x] Core token with tax and reflection
- [x] Chainlink VRF lottery integration
- [x] Governance timelock system
- [x] Sepolia testnet deployment
- [ ] LayerZero OFT cross-chain bridge
- [ ] NFT integration for enhanced lottery tickets
- [ ] Mainnet deployment on Base
- [ ] Multi-chain expansion

## 🤝 **Contributing**

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📄 **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ **Disclaimer**

This is experimental software. Use at your own risk. Always conduct thorough testing and security audits before mainnet deployment.

---

**Built with ❤️ using Foundry and OpenZeppelin**
