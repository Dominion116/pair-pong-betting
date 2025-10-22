// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IBettingPool.sol";

/**
 * @title BettingPool
 * @notice Manages peer-to-peer bet matching with house fallback and insurance integration
 * @author Pair Pong Team
 */
contract BettingPool is IBettingPool, Ownable, ReentrancyGuard {
    // State variables
    uint256 private betCounter;
    address public insureBetsContract;
    address public oracle;
    address public vault;
    
    uint256 public constant MIN_BET_AMOUNT = 0.01 ether;
    uint256 public constant MAX_BET_AMOUNT = 10 ether;
    uint256 public constant BASIS_POINTS = 10000;
    
    // Fee tiers (in basis points)
    uint256 public constant FEE_TIER_1 = 200; // 2% for bets < 0.1 ETH
    uint256 public constant FEE_TIER_2 = 100; // 1% for bets 0.1 - 1 ETH
    uint256 public constant FEE_TIER_3 = 50;  // 0.5% for bets > 1 ETH
    
    uint256 public poolBalance;
    uint256 public vaultBalance;
    
    // Mappings
    mapping(uint256 => Bet) public bets;
    mapping(address => uint256[]) public userBets;
    mapping(uint256 => uint256[]) public matchBets;
    mapping(uint256 => mapping(BetSide => uint256[])) public unmatchedBets;
    mapping(uint256 => bool) public approvedMatches;
    mapping(uint256 => uint256) public matchStartTimes;
    mapping(address => mapping(uint256 => BetSide[])) public userMatchSides;
    
    // Modifiers
    modifier onlyOracle() {
        require(msg.sender == oracle, "Only oracle");
        _;
    }
    
    modifier onlyInsureBets() {
        require(msg.sender == insureBetsContract, "Only InsureBets contract");
        _;
    }
    
    modifier validBetAmount() {
        require(msg.value >= MIN_BET_AMOUNT && msg.value <= MAX_BET_AMOUNT, "Invalid bet amount");
        _;
    }
    
    constructor(address _oracle, address _vault) Ownable(msg.sender) {
        require(_oracle != address(0), "Invalid oracle");
        require(_vault != address(0), "Invalid vault");
        oracle = _oracle;
        vault = _vault;
    }
    
    /**
     * @notice Place a bet on a match with optional insurance
     * @param matchId The match identifier
     * @param side The side to bet on (PlayerA or PlayerB)
     * @param insuranceTier The insurance tier to purchase
     * @return betId The unique bet identifier
     */
    function placeBet(
        uint256 matchId,
        BetSide side,
        InsuranceTier insuranceTier
    ) external payable nonReentrant validBetAmount returns (uint256 betId) {
        require(approvedMatches[matchId], "Match not approved");
        require(block.timestamp < matchStartTimes[matchId], "Match already started");
        
        // Prevent double-betting on same match
        BetSide[] memory userSides = userMatchSides[msg.sender][matchId];
        for (uint256 i = 0; i < userSides.length; i++) {
            require(userSides[i] != side, "Already bet on this side");
        }
        
        betId = ++betCounter;
        
        uint256 betAmount = msg.value;
        uint256 premiumPaid = 0;
        
        // Handle insurance premium if applicable
        if (insuranceTier != InsuranceTier.None) {
            require(insureBetsContract != address(0), "Insurance not available");
            premiumPaid = _calculateInsurancePremium(betAmount, insuranceTier);
            betAmount -= premiumPaid;
        }
        
        // Create bet
        bets[betId] = Bet({
            betId: betId,
            user: msg.sender,
            matchId: matchId,
            side: side,
            amount: betAmount,
            timestamp: block.timestamp,
            status: BetStatus.Pending,
            insured: insuranceTier != InsuranceTier.None,
            insuranceTier: insuranceTier,
            premiumPaid: premiumPaid,
            matchedBetIds: new uint256[](0),
            matchedWithHouse: false
        });
        
        userBets[msg.sender].push(betId);
        matchBets[matchId].push(betId);
        userMatchSides[msg.sender][matchId].push(side);
        
        // Register insurance if applicable
        if (insuranceTier != InsuranceTier.None && insureBetsContract != address(0)) {
            // Transfer premium and register insurance
            (bool success, ) = insureBetsContract.call{value: premiumPaid}(
                abi.encodeWithSignature(
                    "registerInsurance(uint256,address,uint256,uint256,uint256,uint8)",
                    betId,
                    msg.sender,
                    matchId,
                    betAmount,
                    premiumPaid,
                    uint8(insuranceTier)
                )
            );
            require(success, "Insurance registration failed");
        }
        
        // Attempt to match bet
        _matchBet(betId);
        
        poolBalance += betAmount;
        
        emit BetPlaced(betId, msg.sender, matchId, side, betAmount, bets[betId].insured, insuranceTier);
    }
    
    /**
     * @notice Internal function to match a bet with counterparties
     */
    function _matchBet(uint256 betId) internal {
        Bet storage bet = bets[betId];
        BetSide oppositeSide = bet.side == BetSide.PlayerA ? BetSide.PlayerB : BetSide.PlayerA;
        uint256[] storage opposingBets = unmatchedBets[bet.matchId][oppositeSide];
        
        uint256 remainingAmount = bet.amount;
        
        // Try to match with opposing bets
        uint256 i = 0;
        while (i < opposingBets.length && remainingAmount > 0) {
            uint256 opposingBetId = opposingBets[i];
            Bet storage opposingBet = bets[opposingBetId];
            
            if (opposingBet.status == BetStatus.Pending) {
                uint256 matchAmount = remainingAmount < opposingBet.amount 
                    ? remainingAmount 
                    : opposingBet.amount;
                
                // Record the match
                bet.matchedBetIds.push(opposingBetId);
                opposingBet.matchedBetIds.push(betId);
                
                remainingAmount -= matchAmount;
                
                if (matchAmount == opposingBet.amount) {
                    opposingBet.status = BetStatus.Matched;
                    // Remove from unmatched queue
                    opposingBets[i] = opposingBets[opposingBets.length - 1];
                    opposingBets.pop();
                } else {
                    opposingBet.amount -= matchAmount;
                    i++;
                }
                
                emit BetsMatched(betId, opposingBetId, matchAmount);
            } else {
                i++;
            }
        }
        
        // Update bet status
        if (remainingAmount == 0) {
            bet.status = BetStatus.Matched;
        } else {
            // Add to unmatched queue for potential future matches
            unmatchedBets[bet.matchId][bet.side].push(betId);
            
            // Match remaining with house if vault has liquidity
            if (vaultBalance >= remainingAmount) {
                bet.matchedWithHouse = true;
                vaultBalance -= remainingAmount; // Lock vault funds
                
                emit BetMatchedWithHouse(betId, remainingAmount);
            }
        }
    }
    
    /**
     * @notice Settle all bets for a match (oracle only)
     * @param matchId The match identifier
     * @param winningSide The winning side
     */
    function settleBet(uint256 matchId, BetSide winningSide) external onlyOracle nonReentrant {
        require(approvedMatches[matchId], "Match not approved");
        require(block.timestamp >= matchStartTimes[matchId], "Match not started");
        
        uint256[] memory betsToSettle = matchBets[matchId];
        
        for (uint256 i = 0; i < betsToSettle.length; i++) {
            uint256 betId = betsToSettle[i];
            Bet storage bet = bets[betId];
            
            if (bet.status == BetStatus.Pending || bet.status == BetStatus.Matched) {
                if (bet.side == winningSide) {
                    _payoutWinner(betId);
                } else {
                    _processLoss(betId);
                }
            }
        }
        
        // Clean up unmatched queues
        delete unmatchedBets[matchId][BetSide.PlayerA];
        delete unmatchedBets[matchId][BetSide.PlayerB];
    }
    
    /**
     * @notice Process winner payout
     */
    function _payoutWinner(uint256 betId) internal {
        Bet storage bet = bets[betId];
        uint256 totalPayout = bet.amount;
        uint256 originalBetAmount = bet.amount;
        
        // Calculate payout from matched bets
        for (uint256 i = 0; i < bet.matchedBetIds.length; i++) {
            uint256 matchedBetId = bet.matchedBetIds[i];
            Bet storage matchedBet = bets[matchedBetId];
            
            // Calculate proportional share from matched bet
            uint256 matchedAmount = matchedBet.amount;
            totalPayout += matchedAmount;
        }
        
        // Add house payout if matched with house
        if (bet.matchedWithHouse) {
            uint256 housePayout = originalBetAmount; // 1:1 from house
            totalPayout += housePayout;
            
            // Release locked vault funds
            require(vaultBalance >= housePayout, "Insufficient vault balance");
            vaultBalance -= housePayout;
        }
        
        // Calculate and deduct fee
        uint256 fee = calculateFee(totalPayout);
        uint256 netPayout = totalPayout - fee;
        
        bet.status = BetStatus.Won;
        poolBalance -= bet.amount; // Remove original bet from pool
        
        // Transfer payout
        (bool success, ) = bet.user.call{value: netPayout}("");
        require(success, "Payout failed");
        
        emit BetSettled(betId, bet.user, netPayout, BetStatus.Won);
    }
    
    /**
     * @notice Process losing bet
     */
    function _processLoss(uint256 betId) internal {
        Bet storage bet = bets[betId];
        bet.status = BetStatus.Lost;
        
        // Deduct lost amount from pool
        poolBalance -= bet.amount;
        
        // If matched with house, release house winnings
        if (bet.matchedWithHouse) {
            uint256 houseWinnings = bet.amount;
            vaultBalance += houseWinnings; // House keeps the locked funds plus winnings
        }
        
        // If insured, trigger insurance claim via InsureBets contract
        if (bet.insured && insureBetsContract != address(0)) {
            // Call insurance contract to process claim
            (bool success, bytes memory returnData) = insureBetsContract.call(
                abi.encodeWithSignature("processClaim(uint256)", betId)
            );
            
            if (success) {
                // Decode payout amount from return data
                uint256 insurancePayout = abi.decode(returnData, (uint256));
                emit BetSettled(betId, bet.user, insurancePayout, BetStatus.Lost);
            } else {
                // Insurance claim failed, just emit regular loss
                emit BetSettled(betId, bet.user, 0, BetStatus.Lost);
            }
        } else {
            emit BetSettled(betId, bet.user, 0, BetStatus.Lost);
        }
    }
    
    /**
     * @notice Refund a bet (owner or oracle only, for canceled matches)
     */
    function refundBet(uint256 betId) external nonReentrant {
        require(msg.sender == owner() || msg.sender == oracle, "Unauthorized");
        
        Bet storage bet = bets[betId];
        require(bet.status == BetStatus.Pending || bet.status == BetStatus.Matched, "Cannot refund");
        
        uint256 refundAmount = bet.amount;
        
        // Handle house-matched bets
        if (bet.matchedWithHouse) {
            vaultBalance += refundAmount; // Return locked vault funds
        }
        
        // Update matched bets status
        for (uint256 i = 0; i < bet.matchedBetIds.length; i++) {
            uint256 matchedBetId = bet.matchedBetIds[i];
            Bet storage matchedBet = bets[matchedBetId];
            if (matchedBet.status != BetStatus.Refunded) {
                matchedBet.status = BetStatus.Refunded;
            }
        }
        
        bet.status = BetStatus.Refunded;
        poolBalance -= refundAmount;
        
        // Include premium in refund if insured
        uint256 totalRefund = refundAmount + bet.premiumPaid;
        
        // If premium was paid, request refund from insurance contract
        if (bet.premiumPaid > 0 && insureBetsContract != address(0)) {
            (bool insurancePaid, ) = insureBetsContract.call{value: bet.premiumPaid}(
                abi.encodeWithSignature("refundPremium(uint256)", betId)
            );
            if (!insurancePaid) {
                totalRefund = refundAmount; // Only refund bet amount if premium refund fails
            }
        }
        
        (bool refundSent, ) = bet.user.call{value: totalRefund}("");
        require(refundSent, "Refund failed");
        
        emit BetRefunded(betId, bet.user, totalRefund);
    }
    
    /**
     * @notice Approve a match for betting (oracle only)
     * @param matchId The match identifier
     * @param startTime The match start timestamp
     */
    function approveMatch(uint256 matchId, uint256 startTime) external onlyOracle {
        require(!approvedMatches[matchId], "Already approved");
        require(startTime > block.timestamp, "Invalid start time");
        
        approvedMatches[matchId] = true;
        matchStartTimes[matchId] = startTime;
        
        emit MatchApproved(matchId, startTime);
    }
    
    /**
     * @notice Calculate insurance premium based on tier
     */
    function _calculateInsurancePremium(uint256 amount, InsuranceTier tier) internal pure returns (uint256) {
        if (tier == InsuranceTier.Bronze) {
            return (amount * 300) / BASIS_POINTS; // 3%
        } else if (tier == InsuranceTier.Silver) {
            return (amount * 600) / BASIS_POINTS; // 6%
        } else if (tier == InsuranceTier.Gold) {
            return (amount * 1000) / BASIS_POINTS; // 10%
        }
        return 0;
    }
    
    /**
     * @notice Calculate platform fee based on bet amount
     */
    function calculateFee(uint256 amount) public pure returns (uint256) {
        if (amount < 0.1 ether) {
            return (amount * FEE_TIER_1) / BASIS_POINTS; // 2%
        } else if (amount <= 1 ether) {
            return (amount * FEE_TIER_2) / BASIS_POINTS; // 1%
        } else {
            return (amount * FEE_TIER_3) / BASIS_POINTS; // 0.5%
        }
    }
    
    /**
     * @notice Replenish vault with funds
     */
    function replenishVault() external payable onlyOwner {
        vaultBalance += msg.value;
        emit VaultReplenished(msg.value, vaultBalance);
    }
    
    /**
     * @notice Set insurance contract address (owner only)
     */
    function setInsureBetsContract(address _insureBetsContract) external onlyOwner {
        require(_insureBetsContract != address(0), "Invalid address");
        insureBetsContract = _insureBetsContract;
    }
    
    /**
     * @notice Set oracle address (owner only)
     */
    function setOracle(address _oracle) external onlyOwner {
        require(_oracle != address(0), "Invalid oracle");
        oracle = _oracle;
    }
    
    /**
     * @notice Withdraw accumulated fees (owner only)
     */
    function withdrawFees() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance - poolBalance - vaultBalance;
        require(balance > 0, "No fees to withdraw");
        
        (bool success, ) = owner().call{value: balance}("");
        require(success, "Withdrawal failed");
    }
    
    // View functions
    function getBet(uint256 betId) external view returns (Bet memory) {
        return bets[betId];
    }
    
    function getUserBets(address user) external view returns (Bet[] memory) {
        uint256[] memory betIds = userBets[user];
        Bet[] memory userBetsList = new Bet[](betIds.length);
        
        for (uint256 i = 0; i < betIds.length; i++) {
            userBetsList[i] = bets[betIds[i]];
        }
        
        return userBetsList;
    }
    
    function getMatchBets(uint256 matchId) external view returns (Bet[] memory) {
        uint256[] memory betIds = matchBets[matchId];
        Bet[] memory matchBetsList = new Bet[](betIds.length);
        
        for (uint256 i = 0; i < betIds.length; i++) {
            matchBetsList[i] = bets[betIds[i]];
        }
        
        return matchBetsList;
    }
    
    function getUnmatchedBets(uint256 matchId, BetSide side) external view returns (uint256[] memory) {
        return unmatchedBets[matchId][side];
    }
    
    function getPoolBalance() external view returns (uint256) {
        return poolBalance;
    }
    
    function getVaultBalance() external view returns (uint256) {
        return vaultBalance;
    }
    
    receive() external payable {
        // Accept ETH for vault replenishment
    }
}