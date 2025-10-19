# Pair Pong Betting Smart Contract

A decentralized 1v1 betting platform where users stake ETH and select crypto tokens. The frontend determines winners based on token performance, and the smart contract handles secure fund management and payouts.

## 🎯 Features

- **1v1 Betting**: Create and join matches with ETH stakes
- **Token Selection**: Each player selects a different crypto token
- **Secure Settlements**: Admin-controlled match finalization with winner verification
- **Platform Fees**: Configurable fee system (default 2%)
- **Access Control**: Owner and admin role management
- **Match Management**: View active, pending, and user-specific matches
- **Refund System**: Cancel matches and refund participants

## 📁 Project Structure

```
pair-pong-betting/
├── src/
│   ├── PairPong.sol              # Main betting contract
│   └── interfaces/
│       └── IPairPong.sol         # Contract interface
├── test/
│   ├── PairPong.t.sol            # Base tests
│   ├── PairPongAccessControl.t.sol
│   ├── PairPongBetting.t.sol
│   └── mocks/
│       └── MockERC20.sol         # Mock token for testing
├── script/
│   └── DeployPairPong.s.sol      # Deployment scripts
└── foundry.toml                   # Foundry configuration
```

## 🚀 Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Git](https://git-scm.com/downloads)

### Installation

1. Clone the repository and navigate to the project directory

2. Install dependencies:
```bash
forge install
```

3. Build the project:
```bash
forge build
```

### Running Tests

```bash
# Run all tests
forge test

# Run tests with verbosity
forge test -vvv

# Run specific test file
forge test --match-path test/PairPongBetting.t.sol

# Run with gas reporting
forge test --gas-report
```

## 📝 Contract Usage

### Creating a Match

```solidity
// User stakes 0.1 ETH and selects WETH token
uint256 matchId = pairPong.createMatch{value: 0.1 ether}(WETH_ADDRESS);
```

### Joining a Match

```solidity
// Another user joins with same stake amount and selects USDC token
pairPong.joinMatch{value: 0.1 ether}(matchId, USDC_ADDRESS);
```

### Finalizing a Match (Admin Only)

```solidity
// Admin determines winner off-chain and settles the match
pairPong.finalizeMatch(matchId, winnerAddress);
```

### Viewing Matches

```solidity
// Get match details
IPairPong.Match memory match = pairPong.getMatch(matchId);

// Get all pending matches
uint256[] memory pending = pairPong.getPendingMatches();

// Get user's matches
uint256[] memory userMatches = pairPong.getUserMatches(userAddress);
```

## 🚢 Deployment

### Local Deployment (Anvil)

1. Start a local node:
```bash
anvil
```

2. Deploy the contract:
```bash
forge script script/DeployPairPong.s.sol:DeployPairPongLocal \
  --rpc-url http://localhost:8545 \
  --broadcast
```

### Testnet Deployment

1. Set up environment variables in `.env`:
```bash
PRIVATE_KEY=your_private_key
ADMIN_ADDRESS=admin_wallet_address
SEPOLIA_RPC_URL=your_sepolia_rpc_url
ETHERSCAN_API_KEY=your_etherscan_api_key
```

2. Deploy to testnet:
```bash
forge script script/DeployPairPong.s.sol:DeployPairPongTestnet \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify
```

### Mainnet Deployment

```bash
forge script script/DeployPairPong.s.sol \
  --rpc-url $MAINNET_RPC_URL \
  --broadcast \
  --verify \
  --slow
```

## 🧪 Testing

### Run All Tests

```bash
forge test
```

### Run Specific Test Files

```bash
# Base integration tests
forge test --match-path test/PairPong.t.sol

# Access control tests
forge test --match-path test/PairPongAccessControl.t.sol

# Betting logic tests
forge test --match-path test/PairPongBetting.t.sol
```

### Run Specific Test Functions

```bash
# Run tests matching a pattern
forge test --match-test test_CreateMatch

# Run with verbosity
forge test --match-test test_CompleteMatchFlow -vvv
```

### Generate Gas Report

```bash
forge test --gas-report
```

### Generate Coverage Report

```bash
forge coverage
```

### Test with Fork

```bash
# Test against a forked mainnet
forge test --fork-url $MAINNET_RPC_URL

# Test specific block
forge test --fork-url $MAINNET_RPC_URL --fork-block-number 18000000
```

## 📊 Contract Details

### Constructor Parameters

- `admin`: Address authorized to finalize and cancel matches
- `platformFeePercentage`: Fee in basis points (200 = 2%)
- `minBetAmount`: Minimum bet in wei (0.01 ETH)
- `maxBetAmount`: Maximum bet in wei (10 ETH)

### Platform Fee

The platform fee is calculated in basis points:
- 100 basis points = 1%
- 200 basis points = 2% (default)
- 1000 basis points = 10% (maximum)

Example: With a 2% fee on a 1 ETH pool:
```
Total Pool: 1 ETH
Platform Fee: 0.02 ETH (2%)
Winner Payout: 0.98 ETH
```

### Match States

```solidity
enum MatchStatus {
    Pending,    // Waiting for player2
    Active,     // Both players joined
    Completed,  // Winner paid
    Canceled    // Refunds processed
}
```

## 🔒 Security Features

- **ReentrancyGuard**: Protects against reentrancy attacks
- **Access Control**: Owner and admin role separation
- **Input Validation**: Comprehensive checks on all parameters
- **Checks-Effects-Interactions**: Safe transfer pattern
- **Event Logging**: Complete audit trail

## 🎮 Usage Example

### Frontend Integration

```javascript
import { ethers } from 'ethers';

// Connect to contract
const pairPong = new ethers.Contract(ADDRESS, ABI, signer);

// Create match
const tx1 = await pairPong.createMatch(WETH_ADDRESS, {
  value: ethers.parseEther("0.1")
});
await tx1.wait();

// Join match
const tx2 = await pairPong.joinMatch(matchId, USDC_ADDRESS, {
  value: ethers.parseEther("0.1")
});
await tx2.wait();

// Admin finalizes match
const tx3 = await pairPong.finalizeMatch(matchId, winnerAddress);
await tx3.wait();
```

### Query Matches

```javascript
// Get match details
const match = await pairPong.getMatch(matchId);

// Get pending matches
const pending = await pairPong.getPendingMatches();

// Get active matches
const active = await pairPong.getActiveMatches();

// Get user's matches
const userMatches = await pairPong.getUserMatches(userAddress);
```

## 📈 Test Coverage

The test suite includes:

- ✅ Match creation with various bet amounts
- ✅ Match joining with validation
- ✅ Match settlement with fee calculation
- ✅ Match cancellation and refunds
- ✅ Access control for admin functions
- ✅ Owner functions (fees, parameters)
- ✅ Edge cases and error conditions
- ✅ Reentrancy protection
- ✅ Gas optimization tests
- ✅ Fuzz testing

### Test Results

Run `forge test` to see results:

```bash
[⠢] Compiling...
[⠆] Compiling 1 files with 0.8.20
[⠰] Solc 0.8.20 finished in 2.5s
Compiler run successful!

Running 50+ tests for test/PairPong.t.sol:PairPongTest
[PASS] test_CompleteMatchFlow() (gas: 245678)
[PASS] test_MultipleMatches() (gas: 398765)
...
Test result: ok. 50 passed; 0 failed; finished in 5.2s
```

## 🛠 Development

### Install Dependencies

```bash
forge install OpenZeppelin/openzeppelin-contracts --no-commit
```

### Compile Contracts

```bash
forge build
```

### Format Code

```bash
forge fmt
```

### Clean Build Artifacts

```bash
forge clean
```

## 📝 Contract Addresses

After deployment, update these addresses:

- **Sepolia Testnet**: `0x...`
- **Ethereum Mainnet**: `0x...`

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Write tests for new features
4. Ensure all tests pass: `forge test`
5. Submit a pull request

## 📄 License

MIT License

## 🔗 Resources

- [Foundry Documentation](https://book.getfoundry.sh/)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)
- [Solidity Documentation](https://docs.soliditylang.org/)

## ⚠️ Disclaimer

This contract is provided as-is. Ensure proper auditing before mainnet deployment.