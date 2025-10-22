# Pair Pong Betting Smart Contract - Complete System

A decentralized betting platform with integrated insurance mechanisms where users stake ETH, select crypto tokens, and have the option to insure their wagers. The frontend determines winners based on token performance, while smart contracts handle secure fund management, peer-to-peer bet matching, insurance claims, and payouts.

## 🎯 Features

- **Betting**: Create and join matches with ETH stakes
- **Token Selection**: Each player selects a different crypto token
- **Peer-to-Peer Matching**: Automatic bet matching with flexible 1-to-N scenarios
- **House Backup**: Fallback matching against vault if no peer match found
- **Insurance Coverage**: Optional tiered insurance (Gold, Silver, Bronze) for loss protection
- **Secure Settlements**: Oracle-verified match finalization with winner verification
- **Platform Fees**: Configurable fee system (default 2%)
- **Access Control**: Owner, admin, and oracle role management
- **Match Management**: View active, pending, completed, and user-specific matches
- **Refund System**: Cancel matches and refund participants
- **Liquidity Management**: Vault replenishment and reserve monitoring

## 📁 Project Structure

```
pair-pong-betting/
├── src/
│   ├── PairPong.sol                 # Main 1v1 betting contract
│   ├── BettingPool.sol              # Peer-to-peer bet matching engine
│   ├── InsureBets.sol               # Insurance contract for bet protection
│   ├── Vault.sol                    # House liquidity management
│   └── interfaces/
│       ├── IPairPong.sol            # PairPong interface
│       ├── IPool.sol                # BettingPool interface
│       ├── IInsureBet.sol           # InsureBets interface
│       └── IVault.sol               # Vault interface
├── test/
│   ├── PairPong.t.sol               # Base integration tests
│   ├── PairPongAccessControl.t.sol  # Access control tests
│   ├── PairPongBetting.t.sol        # Betting logic tests
│   ├── BettingPool.t.sol            # BettingPool matching tests
│   ├── InsureBets.t.sol             # Insurance claim tests
│   ├── Vault.t.sol                  # Liquidity management tests
│   └── mocks/
│       └── MockERC20.sol            # Mock token for testing
│       └── MockOracle.sol           # Mock oracle for testing
├── utilsl/
├   ├── Oracle.sol                   # Oracle contract for off chain data integration
├── script/
│   ├── DeployPairPong.s.sol         # Main contract deployment
│   ├── DeployBettingPool.s.sol      # BettingPool deployment
│   ├── DeployInsureBets.s.sol       # InsureBets deployment
│   └── DeployVault.s.sol            # Vault deployment
└── foundry.toml                     # Foundry configuration
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
forge test --match-path test/BettingPool.t.sol

# Run with gas reporting
forge test --gas-report
```

## 📝 Contract Usage

### Creating a Match (PairPong)

```solidity
// User stakes 0.1 ETH and selects WETH token
uint256 matchId = pairPong.createMatch{value: 0.1 ether}(WETH_ADDRESS);
```

### Placing a Bet with Optional Insurance (BettingPool)

```solidity
// User places 0.1 ETH bet on Player A with Gold tier insurance
// Gold tier: 10% premium, 50% loss payout
uint256 betId = bettingPool.placeBet{value: 0.1 ether}(
    matchId,
    SIDE_PLAYER_A,
    InsureBets.InsuranceTier.Gold
);
```

### Joining a Match (PairPong)

```solidity
// Another user joins with same stake amount and selects USDC token
pairPong.joinMatch{value: 0.1 ether}(matchId, USDC_ADDRESS);
```

### Settling a Match with Insurance Processing (Oracle)

```solidity
// Oracle verifies winner and triggers settlement
// This automatically processes insurance claims for losing insured bets
pairPong.finalizeMatch(matchId, winnerAddress);
```

### Viewing Matches and Bets

```solidity
// Get match details
IPairPong.Match memory matchData = pairPong.getMatch(matchId);

// Get all pending matches
uint256[] memory pending = pairPong.getPendingMatches();

// Get user's matches
uint256[] memory userMatches = pairPong.getUserMatches(userAddress);

// Get active bets in pool
IPool.Bet[] memory userBets = bettingPool.getUserBets(userAddress);

// Get insurance details
IInsureBet.InsuranceInfo memory info = insureBets.getInsuranceInfo(betId);
```

## 🎯 System Architecture

### BettingPool - Bet Matching Engine

The BettingPool contract implements a flexible peer-to-peer matching algorithm:

- **1-to-1 Matching**: Direct peer matches lock funds together
- **1-to-N Matching**: Supports ratios like 1-to-2, 1-to-5, 1-to-10
- **House Fallback**: Unmatched portions default to vault counterparty
- **Insurance Integration**: Tracks insured bets separately for claim processing
- **Liquidity Management**: Integrates with Vault for reserve availability

Match flow: User places bet → System searches for counterparties → If found, pair immediately → If not, add to queue and match against house → Lock funds until settlement.

### InsureBets - Insurance Layer

Provides optional risk mitigation for users:

- **Tiered Premiums**: Gold (10%), Silver (5%), Bronze (2.5%)
- **Loss Payouts**: Gold (50%), Silver (25%), Bronze (12.5%)
- **Upfront Payment**: Premium collected during bet placement
- **Claim Processing**: Automatic upon loss verification
- **Reserve Management**: Maintains separate insurance pool

Insurance economics: Premiums accumulate in insurance pool → Claims disbursed on verified losses → Surplus grows if loss rate < premium collection rate.

### Vault - Liquidity Management

Manages house liquidity and fallback matching:

- **Reserve Tracking**: Monitor vault balance
- **Payout Distribution**: Fund house-matched bet payouts
- **Replenishment Triggers**: Alert when reserves drop below threshold
- **Emergency Pause**: Halt new house matches if reserves insufficient

## 📊 Contract Details

### Constructor Parameters

**PairPong:**
- `admin`: Address authorized to finalize and cancel matches
- `platformFeePercentage`: Fee in basis points (200 = 2%)
- `minBetAmount`: Minimum bet in wei (0.01 ETH)
- `maxBetAmount`: Maximum bet in wei (10 ETH)

**BettingPool:**
- `vaultAddress`: Address of Vault contract
- `oracleAddress`: Authorized oracle for match verification
- `platformFeePercentage`: Fee in basis points

**InsureBets:**
- `bettingPoolAddress`: Address of BettingPool contract
- `premiumPercentages`: Array of percentages for each tier
- `payoutPercentages`: Array of payouts for each tier

### Insurance Tiers

```solidity
enum InsuranceTier {
    None,    // No insurance
    Bronze,  // 3% premium, 15% payout
    Silver,  // 6% premium, 30% payout
    Gold     // 10% premium, 50% payout
}
```

### Match and Bet States

```solidity
enum MatchStatus {
    Pending,    // Waiting for player2
    Active,     // Both players joined
    Completed,  // Winner paid
    Canceled    // Refunds processed
}

enum BetStatus {
    Pending,    // Waiting for settlement
    Matched,    // Paired with counterparty
    Won,        // Winner paid
    Lost,       // Settled, insured users get claim
    Refunded    // Match canceled
}
```

### Platform Fee Calculation

The platform fee is calculated in basis points:
- 100 basis points = 1%
- 200 basis points = 2% (default)
- 1000 basis points = 10% (maximum)

Example with 2% fee on a 1 ETH pool:
```
Total Pool: 1 ETH
Platform Fee: 0.02 ETH (2%)
Winner Payout: 0.98 ETH
```

Example with Gold insurance on 0.1 ETH bet:
```
Bet Amount: 0.1 ETH
Gold Premium (10%): 0.01 ETH
Insured Bet Amount: 0.09 ETH
Loss Payout (50%): 0.045 ETH (from insurance pool)
```

## 🔒 Security Features

- **ReentrancyGuard**: Protects against reentrancy attacks on all contracts
- **Access Control**: Owner, admin, and oracle role separation
- **Oracle Verification**: Match results verified before settlement
- **Insurance Pool Validation**: Claims processed only for verified losses
- **Input Validation**: Comprehensive checks on all parameters
- **Double-Betting Prevention**: Users cannot bet both sides of same match
- **Time Locks**: Bets blocked after match start time
- **Checks-Effects-Interactions**: Safe transfer pattern throughout
- **Event Logging**: Complete audit trail for all state changes
- **Emergency Pause**: Owner can halt operations during anomalies

## 🚢 Deployment

### Local Deployment (Anvil)

1. Start a local node:
```bash
anvil
```

2. Deploy all contracts:
```bash
forge script script/DeployVault.s.sol:DeployVaultLocal \
  --rpc-url http://localhost:8545 \
  --broadcast

forge script script/DeployBettingPool.s.sol:DeployBettingPoolLocal \
  --rpc-url http://localhost:8545 \
  --broadcast

forge script script/DeployInsureBets.s.sol:DeployInsureBetsLocal \
  --rpc-url http://localhost:8545 \
  --broadcast

forge script script/DeployPairPong.s.sol:DeployPairPongLocal \
  --rpc-url http://localhost:8545 \
  --broadcast
```

### Testnet Deployment

1. Set up environment variables in `.env`:
```bash
PRIVATE_KEY=your_private_key
ADMIN_ADDRESS=admin_wallet_address
ORACLE_ADDRESS=oracle_wallet_address
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

### Run Specific Test Suites

```bash
# Main contract tests
forge test --match-path test/PairPong.t.sol

# Bet matching engine tests
forge test --match-path test/BettingPool.t.sol

# Insurance tests
forge test --match-path test/InsureBets.t.sol

# Access control tests
forge test --match-path test/PairPongAccessControl.t.sol

# Betting logic tests
forge test --match-path test/PairPongBetting.t.sol

# Vault tests
forge test --match-path test/Vault.t.sol
```

### Run Specific Test Functions

```bash
# Bet matching tests
forge test --match-test test_PeerToPeerMatching -vvv

# Insurance claim tests
forge test --match-test test_InsuranceClaimProcessing -vvv

# Settlement tests
forge test --match-test test_CompleteMatchFlow -vvv
```

### Generate Reports

```bash
# Gas report
forge test --gas-report

# Coverage report
forge coverage

# Coverage for specific file
forge coverage --match-path src/BettingPool.sol
```

### Test with Fork

```bash
# Test against forked mainnet
forge test --fork-url $MAINNET_RPC_URL

# Test specific block
forge test --fork-url $MAINNET_RPC_URL --fork-block-number 18000000
```

## 📈 Test Coverage

The comprehensive test suite includes:

**PairPong Tests:**
- ✅ Match creation with various bet amounts
- ✅ Match joining with validation
- ✅ Match settlement with fee calculation
- ✅ Match cancellation and refunds

**BettingPool Tests:**
- ✅ Peer-to-peer bet matching (1-to-1)
- ✅ Multi-opponent matching (1-to-N)
- ✅ House fallback matching
- ✅ Unmatched bet queue management
- ✅ Insurance-aware matching
- ✅ Settlement and payout distribution

**InsureBets Tests:**
- ✅ Insurance tier selection and premium calculation
- ✅ Claim eligibility verification
- ✅ Loss payout distribution
- ✅ Insurance pool reserve tracking
- ✅ Retroactive insurance prevention

**Integration Tests:**
- ✅ Complete flow with insurance
- ✅ Multiple concurrent matches
- ✅ Access control for admin/oracle functions
- ✅ Owner parameter management
- ✅ Reentrancy protection
- ✅ Gas optimization
- ✅ Edge cases and error conditions
- ✅ Fuzz testing

## 🎮 Usage Example

### Complete Betting Flow with Insurance

```javascript
import { ethers } from 'ethers';

// Connect to contracts
const pairPong = new ethers.Contract(PAIR_PONG_ADDRESS, PAIR_PONG_ABI, signer);
const bettingPool = new ethers.Contract(BETTING_POOL_ADDRESS, POOL_ABI, signer);
const insureBets = new ethers.Contract(INSURE_BETS_ADDRESS, INSURANCE_ABI, signer);

// User 1: Create match
const tx1 = await pairPong.createMatch(WETH_ADDRESS, {
  value: ethers.parseEther("0.1")
});
const receipt1 = await tx1.wait();
const matchId = receipt1.events[0].args.matchId;

// User 2: Join match
const tx2 = await pairPong.joinMatch(matchId, USDC_ADDRESS, {
  value: ethers.parseEther("0.1")
});
await tx2.wait();

// User 1: Place insured bet in pool (Gold tier = 10% premium, 50% payout)
const tx3 = await bettingPool.placeBet(matchId, SIDE_PLAYER_A, 2, { // 2 = Gold tier
  value: ethers.parseEther("0.1")
});
const receipt3 = await tx3.wait();
const betId = receipt3.events[0].args.betId;

// Check insurance details
const insurance = await insureBets.getInsuranceInfo(betId);
console.log("Premium Paid:", insurance.premiumPaid);
console.log("Payout Percentage:", insurance.payoutPercentage);

// Oracle: Finalize match with winner
const tx4 = await pairPong.finalizeMatch(matchId, userAddress1);
await tx4.wait();

// Check if insurance claim was processed
const claimStatus = await insureBets.getClaimStatus(betId);
console.log("Claim Processed:", claimStatus.processed);
console.log("Claim Amount:", claimStatus.amount);
```

### Query System State

```javascript
// Get all pending matches
const pending = await pairPong.getPendingMatches();

// Get user's active matches
const userMatches = await pairPong.getUserMatches(userAddress);

// Get vault balance
const vaultBalance = await vault.getBalance();

// Get insurance pool reserves
const insuranceReserves = await insureBets.getReserves();

// Get unmatched bets in queue
const unmatchedBets = await bettingPool.getUnmatchedBets(SIDE_PLAYER_A);
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

- **Sepolia Testnet**:
  - PairPong: `0x...`
  - BettingPool: `0x...`
  - InsureBets: `0x...`
  - Vault: `0x...`

- **Ethereum Mainnet**:
  - PairPong: `0x...`
  - BettingPool: `0x...`
  - InsureBets: `0x...`
  - Vault: `0x...`

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