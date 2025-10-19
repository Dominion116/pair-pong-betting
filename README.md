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

###