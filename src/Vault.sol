// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/IVault.sol";

/**
 * @title Vault
 * @notice Manages house liquidity for unmatched bets and fallback payouts
 * @dev Provides secure fund management with threshold monitoring and emergency controls
 * @author Pair Pong Team
 */
contract Vault is IVault, Ownable, ReentrancyGuard, Pausable {
    // State variables
    address public bettingPool;
    uint256 public vaultBalance;
    uint256 public reserveThreshold;
    uint256 public totalDeposits;
    uint256 public totalPayouts;
    
    // Constants
    uint256 public constant MIN_RESERVE_THRESHOLD = 5 ether;
    uint256 public constant CRITICAL_THRESHOLD_MULTIPLIER = 2; // 2x reserve threshold
    
    // Mappings
    mapping(uint256 => bool) public processedPayouts;
    
    // Modifiers
    modifier onlyBettingPool() {
        require(msg.sender == bettingPool, "Only BettingPool");
        _;
    }
    
    constructor(address _bettingPool, uint256 _initialReserveThreshold) Ownable(msg.sender) {
        require(_bettingPool != address(0), "Invalid BettingPool address");
        require(_initialReserveThreshold >= MIN_RESERVE_THRESHOLD, "Threshold too low");
        
        bettingPool = _bettingPool;
        reserveThreshold = _initialReserveThreshold;
    }
    
    /**
     * @notice Deposit funds into the vault
     */
    function deposit() external payable onlyOwner {
        require(msg.value > 0, "Must deposit amount");
        
        vaultBalance += msg.value;
        totalDeposits += msg.value;
        
        emit Deposited(msg.sender, msg.value, vaultBalance);
    }
    
    /**
     * @notice Process house payout for winning bets (called by BettingPool)
     * @param betId The bet identifier
     * @param recipient The recipient address
     * @param amount The payout amount
     * @return success Whether the payout was successful
     */
    function processHousePayout(
        uint256 betId,
        address recipient,
        uint256 amount
    ) external nonReentrant onlyBettingPool whenNotPaused returns (bool success) {
        require(recipient != address(0), "Invalid recipient");
        require(amount > 0, "Invalid amount");
        require(!processedPayouts[betId], "Payout already processed");
        require(vaultBalance >= amount, "Insufficient vault balance");
        
        // Mark payout as processed
        processedPayouts[betId] = true;
        
        // Update balance
        vaultBalance -= amount;
        totalPayouts += amount;
        
        // Transfer funds
        (success, ) = recipient.call{value: amount}("");
        require(success, "Payout transfer failed");
        
        emit PayoutProcessed(betId, recipient, amount);
        
        // Check if reserves are getting low
        if (vaultBalance < reserveThreshold) {
            _pause(); // Pause operations until reserves replenished
        }
        
        return success;
    }
    
    /**
     * @notice Withdraw funds from vault (owner only)
     * @param amount Amount to withdraw
     */
    function withdraw(uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0, "Invalid amount");
        require(vaultBalance >= amount, "Insufficient balance");
        require(
            vaultBalance - amount >= reserveThreshold,
            "Withdrawal would breach reserve threshold"
        );
        
        vaultBalance -= amount;
        
        (bool success, ) = owner().call{value: amount}("");
        require(success, "Withdrawal failed");
        
        emit Withdrawn(owner(), amount, vaultBalance);
    }
    
    /**
     * @notice Emergency withdrawal (owner only, pauses vault)
     */
    function emergencyWithdraw() external onlyOwner nonReentrant {
        uint256 amount = vaultBalance;
        require(amount > 0, "No balance to withdraw");
        
        vaultBalance = 0;
        _pause();
        
        (bool success, ) = owner().call{value: amount}("");
        require(success, "Emergency withdrawal failed");
        
        emit EmergencyWithdrawal(owner(), amount);
    }
    
    /**
     * @notice Set reserve threshold (owner only)
     * @param newThreshold New threshold amount
     */
    function setReserveThreshold(uint256 newThreshold) external onlyOwner {
        require(newThreshold >= MIN_RESERVE_THRESHOLD, "Threshold too low");
        
        uint256 oldThreshold = reserveThreshold;
        reserveThreshold = newThreshold;
        
        emit ReserveThresholdUpdated(oldThreshold, newThreshold);
        
        // Pause if current balance is below new threshold
        if (vaultBalance < newThreshold && !paused()) {
            _pause();
        }
    }
    
    /**
     * @notice Update BettingPool address (owner only)
     * @param newBettingPool New BettingPool address
     */
    function setBettingPool(address newBettingPool) external onlyOwner {
        require(newBettingPool != address(0), "Invalid address");
        
        address oldPool = bettingPool;
        bettingPool = newBettingPool;
        
        emit BettingPoolUpdated(oldPool, newBettingPool);
    }
    
    /**
     * @notice Unpause vault operations (owner only)
     */
    function unpause() external onlyOwner {
        require(vaultBalance >= reserveThreshold, "Reserves below threshold");
        _unpause();
    }
    
    /**
     * @notice Pause vault operations (owner only)
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    // View functions
    
    function getBalance() external view returns (uint256) {
        return vaultBalance;
    }
    
    function getReserveThreshold() external view returns (uint256) {
        return reserveThreshold;
    }
    
    function isAboveThreshold() external view returns (bool) {
        return vaultBalance >= reserveThreshold;
    }
    
    function getAvailableLiquidity() external view returns (uint256) {
        if (vaultBalance <= reserveThreshold) {
            return 0;
        }
        return vaultBalance - reserveThreshold;
    }
    
    /**
     * @notice Get vault health metrics
     * @return balance Current vault balance
     * @return threshold Reserve threshold
     * @return deposits Total deposits made
     * @return payouts Total payouts processed
     * @return healthRatio Balance to threshold ratio (in basis points)
     */
    function getVaultHealth() external view returns (
        uint256 balance,
        uint256 threshold,
        uint256 deposits,
        uint256 payouts,
        uint256 healthRatio
    ) {
        balance = vaultBalance;
        threshold = reserveThreshold;
        deposits = totalDeposits;
        payouts = totalPayouts;
        
        if (threshold > 0) {
            healthRatio = (vaultBalance * 10000) / threshold;
        } else {
            healthRatio = 0;
        }
    }
    
    /**
     * @notice Check if vault is in critical state
     * @return isCritical Whether vault is below critical threshold
     */
    function isCriticalState() external view returns (bool isCritical) {
        uint256 criticalThreshold = reserveThreshold / CRITICAL_THRESHOLD_MULTIPLIER;
        return vaultBalance < criticalThreshold;
    }
    
    /**
     * @notice Calculate maximum safe payout based on reserves
     * @return maxPayout Maximum amount that can be safely paid out
     */
    function getMaxSafePayout() external view returns (uint256 maxPayout) {
        if (vaultBalance <= reserveThreshold) {
            return 0;
        }
        
        // Only payout up to amount that keeps us above threshold
        return vaultBalance - reserveThreshold;
    }
    
    /**
     * @notice Check if a specific payout amount is safe
     * @param amount The payout amount to check
     * @return isSafe Whether the payout is safe
     */
    function isSafePayout(uint256 amount) external view returns (bool isSafe) {
        if (amount == 0) return false;
        if (vaultBalance < amount) return false;
        return (vaultBalance - amount) >= reserveThreshold;
    }
    
    receive() external payable {
        vaultBalance += msg.value;
        totalDeposits += msg.value;
        
        emit Deposited(msg.sender, msg.value, vaultBalance);
        
        // Auto-unpause if reserves restored
        if (paused() && vaultBalance >= reserveThreshold) {
            _unpause();
        }
    }
}