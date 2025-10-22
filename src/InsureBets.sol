// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/IInsureBet.sol";

/**
 * @title InsureBets
 * @notice Manages insurance coverage for bets placed in the BettingPool
 * @dev Provides tiered insurance with configurable premiums and payouts
 * @author Pair Pong Team
 */
contract InsureBets is IInsureBet, Ownable, ReentrancyGuard, Pausable {
    // Constants
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MIN_RESERVE_THRESHOLD = 1 ether;
    
    // State variables
    address public bettingPool;
    uint256 public insuranceReserves;
    uint256 public totalPremiumsCollected;
    uint256 public totalPayoutsDisbursed;
    
    // Mappings
    mapping(uint256 => InsuranceInfo) public insurances;
    mapping(address => uint256[]) public userInsurances;
    mapping(InsuranceTier => TierConfig) public tierConfigs;
    mapping(uint256 => ClaimStatus) public claimStatuses;
    
    // Modifiers
    modifier onlyBettingPool() {
        require(msg.sender == bettingPool, "Only BettingPool");
        _;
    }
    
    constructor(address _bettingPool) Ownable(msg.sender) {
        require(_bettingPool != address(0), "Invalid BettingPool address");
        bettingPool = _bettingPool;
        
        // Initialize default tier configurations
        tierConfigs[InsuranceTier.Bronze] = TierConfig({
            premiumPercentage: 300,  // 3%
            payoutPercentage: 1500   // 15%
        });
        
        tierConfigs[InsuranceTier.Silver] = TierConfig({
            premiumPercentage: 600,  // 6%
            payoutPercentage: 3000   // 30%
        });
        
        tierConfigs[InsuranceTier.Gold] = TierConfig({
            premiumPercentage: 1000, // 10%
            payoutPercentage: 5000   // 50%
        });
    }
    
    /**
     * @notice Register insurance for a bet (called by BettingPool)
     * @param betId The bet identifier
     * @param user The user address
     * @param matchId The match identifier
     * @param insuredAmount The amount being insured
     * @param premiumPaid The premium amount paid
     * @param tier The insurance tier
     */
    function registerInsurance(
        uint256 betId,
        address user,
        uint256 matchId,
        uint256 insuredAmount,
        uint256 premiumPaid,
        InsuranceTier tier
    ) external onlyBettingPool {
        require(tier != InsuranceTier.None, "Invalid tier");
        require(insurances[betId].betId == 0, "Insurance already registered");
        require(insuredAmount > 0, "Invalid insured amount");
        
        insurances[betId] = InsuranceInfo({
            betId: betId,
            user: user,
            matchId: matchId,
            insuredAmount: insuredAmount,
            premiumPaid: premiumPaid,
            tier: tier,
            timestamp: block.timestamp,
            claimProcessed: false,
            payoutAmount: 0
        });
        
        userInsurances[user].push(betId);
        claimStatuses[betId] = ClaimStatus.Pending;
        
        insuranceReserves += premiumPaid;
        totalPremiumsCollected += premiumPaid;
        
        emit InsurancePurchased(betId, user, matchId, tier, premiumPaid, insuredAmount);
    }
    
    /**
     * @notice Process insurance claim for a lost bet (called by BettingPool)
     * @param betId The bet identifier
     * @return payoutAmount The amount paid to the user
     */
    function processClaim(uint256 betId) external nonReentrant onlyBettingPool whenNotPaused returns (uint256 payoutAmount) {
        InsuranceInfo storage insurance = insurances[betId];
        
        require(insurance.betId != 0, "Insurance not found");
        require(!insurance.claimProcessed, "Claim already processed");
        require(claimStatuses[betId] == ClaimStatus.Pending, "Invalid claim status");
        
        // Calculate payout based on tier
        payoutAmount = calculatePayout(insurance.insuredAmount, insurance.tier);
        
        require(insuranceReserves >= payoutAmount, "Insufficient reserves");
        
        // Update insurance info
        insurance.claimProcessed = true;
        insurance.payoutAmount = payoutAmount;
        claimStatuses[betId] = ClaimStatus.Approved;
        
        // Update reserves
        insuranceReserves -= payoutAmount;
        totalPayoutsDisbursed += payoutAmount;
        
        // Transfer payout to user
        (bool success, ) = insurance.user.call{value: payoutAmount}("");
        require(success, "Payout transfer failed");
        
        claimStatuses[betId] = ClaimStatus.Paid;
        
        emit ClaimProcessed(betId, insurance.user, payoutAmount, ClaimStatus.Paid);
        
        // Pause if reserves drop below threshold
        if (insuranceReserves < MIN_RESERVE_THRESHOLD) {
            _pause();
        }
        
        return payoutAmount;
    }
    
    /**
     * @notice Reject a claim (owner only, for disputed cases)
     * @param betId The bet identifier
     */
    function rejectClaim(uint256 betId) external onlyOwner {
        InsuranceInfo storage insurance = insurances[betId];
        
        require(insurance.betId != 0, "Insurance not found");
        require(!insurance.claimProcessed, "Claim already processed");
        
        insurance.claimProcessed = true;
        claimStatuses[betId] = ClaimStatus.Rejected;
        
        emit ClaimProcessed(betId, insurance.user, 0, ClaimStatus.Rejected);
    }
    
    /**
     * @notice Calculate premium for a given amount and tier
     * @param amount The bet amount
     * @param tier The insurance tier
     * @return premium The premium amount
     */
    function calculatePremium(uint256 amount, InsuranceTier tier) public view returns (uint256) {
        if (tier == InsuranceTier.None) return 0;
        
        TierConfig memory config = tierConfigs[tier];
        return (amount * config.premiumPercentage) / BASIS_POINTS;
    }
    
    /**
     * @notice Calculate payout for a given amount and tier
     * @param amount The insured amount
     * @param tier The insurance tier
     * @return payout The payout amount
     */
    function calculatePayout(uint256 amount, InsuranceTier tier) public view returns (uint256) {
        if (tier == InsuranceTier.None) return 0;
        
        TierConfig memory config = tierConfigs[tier];
        return (amount * config.payoutPercentage) / BASIS_POINTS;
    }
    
    /**
     * @notice Update tier configuration (owner only)
     * @param tier The tier to update
     * @param premiumPercentage New premium percentage in basis points
     * @param payoutPercentage New payout percentage in basis points
     */
    function updateTierConfig(
        InsuranceTier tier,
        uint256 premiumPercentage,
        uint256 payoutPercentage
    ) external onlyOwner {
        require(tier != InsuranceTier.None, "Cannot update None tier");
        require(premiumPercentage <= 2000, "Premium too high"); // Max 20%
        require(payoutPercentage <= 10000, "Payout exceeds 100%");
        require(payoutPercentage > premiumPercentage, "Payout must exceed premium");
        
        tierConfigs[tier] = TierConfig({
            premiumPercentage: premiumPercentage,
            payoutPercentage: payoutPercentage
        });
        
        emit TierConfigUpdated(tier, premiumPercentage, payoutPercentage);
    }
    
    /**
     * @notice Replenish insurance reserves
     */
    function replenishReserves() external payable onlyOwner {
        require(msg.value > 0, "Must send ETH");
        
        insuranceReserves += msg.value;
        
        emit ReservesReplenished(msg.value, insuranceReserves);
    }
    
    /**
     * @notice Set BettingPool address (owner only)
     * @param _bettingPool New BettingPool address
     */
    function setBettingPool(address _bettingPool) external onlyOwner {
        require(_bettingPool != address(0), "Invalid address");
        bettingPool = _bettingPool;
    }
    
    /**
     * @notice Withdraw excess reserves (owner only)
     * @param amount Amount to withdraw
     */
    function withdrawExcess(uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0, "Invalid amount");
        require(insuranceReserves >= MIN_RESERVE_THRESHOLD + amount, "Must maintain minimum reserves");
        
        insuranceReserves -= amount;
        
        (bool success, ) = owner().call{value: amount}("");
        require(success, "Withdrawal failed");
    }
    
    /**
     * @notice Emergency pause for claims processing (owner only)
     */
    function pauseClaims() external onlyOwner {
        _pause();
    }
    
    /**
     * @notice Resume claims processing (owner only)
     */
    function unpauseClaims() external onlyOwner {
        _unpause();
    }
    
    /**
     * @notice Refund premium for canceled bets (called by BettingPool)
     * @param betId The bet identifier
     */
    function refundPremium(uint256 betId) external payable onlyBettingPool {
        InsuranceInfo storage insurance = insurances[betId];
        
        require(insurance.betId != 0, "Insurance not found");
        require(!insurance.claimProcessed, "Already processed");
        
        insurance.claimProcessed = true;
        claimStatuses[betId] = ClaimStatus.Rejected;
        
        // Premium already sent back by BettingPool via msg.value
        insuranceReserves += msg.value;
    }
    
    // View functions
    
    function getInsuranceInfo(uint256 betId) external view returns (InsuranceInfo memory) {
        return insurances[betId];
    }
    
    function getClaimStatus(uint256 betId) external view returns (ClaimStatus) {
        return claimStatuses[betId];
    }
    
    function getUserInsurances(address user) external view returns (InsuranceInfo[] memory) {
        uint256[] memory betIds = userInsurances[user];
        InsuranceInfo[] memory userInsurancesList = new InsuranceInfo[](betIds.length);
        
        for (uint256 i = 0; i < betIds.length; i++) {
            userInsurancesList[i] = insurances[betIds[i]];
        }
        
        return userInsurancesList;
    }
    
    function getReserves() external view returns (uint256) {
        return insuranceReserves;
    }
    
    function getTierConfig(InsuranceTier tier) external view returns (TierConfig memory) {
        return tierConfigs[tier];
    }
    
    /**
     * @notice Get reserve health metrics
     * @return reserves Current reserves
     * @return collected Total premiums collected
     * @return disbursed Total payouts disbursed
     * @return ratio Reserve ratio (reserves / total insured)
     */
    function getReserveHealth() external view returns (
        uint256 reserves,
        uint256 collected,
        uint256 disbursed,
        uint256 ratio
    ) {
        reserves = insuranceReserves;
        collected = totalPremiumsCollected;
        disbursed = totalPayoutsDisbursed;
        
        if (collected > 0) {
            ratio = (reserves * BASIS_POINTS) / collected;
        } else {
            ratio = 0;
        }
    }
    
    /**
     * @notice Check if reserves are sufficient for potential claims
     * @return isSufficient Whether reserves meet minimum threshold
     */
    function checkReserveSufficiency() external view returns (bool isSufficient) {
        return insuranceReserves >= MIN_RESERVE_THRESHOLD;
    }
    
    receive() external payable {
        insuranceReserves += msg.value;
        emit ReservesReplenished(msg.value, insuranceReserves);
        
        // Auto-unpause if reserves restored
        if (paused() && insuranceReserves >= MIN_RESERVE_THRESHOLD) {
            _unpause();
        }
    }
}