// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IPairPong.sol";

/**
 * @title PairPong
 * @notice A 1v1 betting contract where users bet on crypto token performance
 * @dev Users stake ETH and select tokens. Frontend determines winner and calls finalizeMatch()
 * @author PairPong Team
 */
contract PairPong is IPairPong, Ownable, ReentrancyGuard {
    // ============ State Variables ============

    /// @notice Admin address authorized to finalize and cancel matches
    address public admin;

    /// @notice Counter for generating unique match IDs
    uint256 public matchCounter;

    /// @notice Platform fee percentage (in basis points, e.g., 200 = 2%)
    uint256 public platformFeePercentage;

    /// @notice Accumulated platform fees available for withdrawal
    uint256 public accumulatedFees;

    /// @notice Minimum bet amount in wei
    uint256 public minBetAmount;

    /// @notice Maximum bet amount in wei
    uint256 public maxBetAmount;

    /// @notice Mapping of match ID to Match struct
    mapping(uint256 => Match) public matches;

    /// @notice Mapping of user address to their match IDs
    mapping(address => uint256[]) public userMatches;

    /// @notice Array of all match IDs (for iteration)
    uint256[] private allMatchIds;

    // ============ Constants ============

    uint256 private constant BASIS_POINTS = 10000; // 100% = 10000 basis points
    uint256 private constant MAX_FEE_PERCENTAGE = 1000; // Max 10% fee

    // ============ Modifiers ============

    /// @notice Restricts function access to admin only
    modifier onlyAdmin() {
        if (msg.sender != admin) revert UnauthorizedAccess();
        _;
    }

    /// @notice Restricts function access to owner or admin
    modifier onlyOwnerOrAdmin() {
        if (msg.sender != owner() && msg.sender != admin)
            revert UnauthorizedAccess();
        _;
    }

    // ============ Constructor ============

    /**
     * @notice Initializes the contract with owner and admin
     * @param _admin Address of the initial admin
     * @param _platformFeePercentage Initial platform fee in basis points
     * @param _minBetAmount Minimum bet amount in wei
     * @param _maxBetAmount Maximum bet amount in wei
     */
    constructor(
        address _admin,
        uint256 _platformFeePercentage,
        uint256 _minBetAmount,
        uint256 _maxBetAmount
    ) Ownable(msg.sender) {
        if (_admin == address(0)) revert InvalidAddress();
        if (_platformFeePercentage > MAX_FEE_PERCENTAGE)
            revert InvalidFeePercentage();
        if (_minBetAmount == 0 || _maxBetAmount <= _minBetAmount)
            revert InvalidBetAmount();

        admin = _admin;
        platformFeePercentage = _platformFeePercentage;
        minBetAmount = _minBetAmount;
        maxBetAmount = _maxBetAmount;
    }

    // ============ Betting Functions ============

    /**
     * @notice Creates a new 1v1 match with a token selection
     * @param tokenSelected Address of the token player1 is betting on
     * @return matchId The ID of the newly created match
     * @dev Requires msg.value to be within min/max bet range
     */
    function createMatch(
        address tokenSelected
    ) external payable nonReentrant returns (uint256 matchId) {
        if (msg.value < minBetAmount || msg.value > maxBetAmount)
            revert InvalidBetAmount();
        if (tokenSelected == address(0)) revert InvalidTokenAddress();

        matchId = ++matchCounter;

        matches[matchId] = Match({
            id: matchId,
            player1: msg.sender,
            player2: address(0),
            token1: tokenSelected,
            token2: address(0),
            amount: msg.value,
            winner: address(0),
            status: MatchStatus.Pending,
            createdAt: block.timestamp
        });

        userMatches[msg.sender].push(matchId);
        allMatchIds.push(matchId);

        emit MatchCreated(
            matchId,
            msg.sender,
            tokenSelected,
            msg.value,
            block.timestamp
        );
    }

    /**
     * @notice Joins an existing pending match with a token selection
     * @param matchId ID of the match to join
     * @param tokenSelected Address of the token player2 is betting on
     * @dev Requires matching bet amount and different token selection
     */
    function joinMatch(
        uint256 matchId,
        address tokenSelected
    ) external payable nonReentrant {
        Match storage matchData = matches[matchId];

        if (matchId == 0 || matchId > matchCounter) revert InvalidMatchId();
        if (matchData.status != MatchStatus.Pending) revert MatchNotPending();
        if (msg.value != matchData.amount) revert InvalidBetAmount();
        if (msg.sender == matchData.player1) revert PlayerAlreadyInMatch();
        if (tokenSelected == address(0)) revert InvalidTokenAddress();
        if (tokenSelected == matchData.token1) revert SameTokenSelected();

        matchData.player2 = msg.sender;
        matchData.token2 = tokenSelected;
        matchData.status = MatchStatus.Active;

        userMatches[msg.sender].push(matchId);

        emit MatchJoined(matchId, msg.sender, tokenSelected, block.timestamp);
    }

    // ============ Settlement Functions (Admin Only) ============

    /**
     * @notice Finalizes a match and pays out the winner
     * @param matchId ID of the match to finalize
     * @param winner Address of the winning player
     * @dev Only callable by admin. Deducts platform fee before payout
     */
    function finalizeMatch(
        uint256 matchId,
        address winner
    ) external onlyAdmin nonReentrant {
        Match storage matchData = matches[matchId];

        if (matchId == 0 || matchId > matchCounter) revert InvalidMatchId();
        if (matchData.status != MatchStatus.Active) revert MatchNotActive();
        if (winner != matchData.player1 && winner != matchData.player2)
            revert InvalidAddress();

        matchData.status = MatchStatus.Completed;
        matchData.winner = winner;

        uint256 totalPool = matchData.amount * 2;
        uint256 platformFee = (totalPool * platformFeePercentage) /
            BASIS_POINTS;
        uint256 winnerPayout = totalPool - platformFee;

        accumulatedFees += platformFee;

        // Transfer winnings to winner
        (bool success, ) = payable(winner).call{value: winnerPayout}("");
        if (!success) revert TransferFailed();

        emit MatchSettled(
            matchId,
            winner,
            winnerPayout,
            platformFee,
            block.timestamp
        );
    }

    /**
     * @notice Cancels a match and refunds participants
     * @param matchId ID of the match to cancel
     * @dev Can cancel Pending or Active matches. Refunds both players if active
     */
    function cancelMatch(
        uint256 matchId
    ) external onlyOwnerOrAdmin nonReentrant {
        Match storage matchData = matches[matchId];

        if (matchId == 0 || matchId > matchCounter) revert InvalidMatchId();
        if (
            matchData.status != MatchStatus.Pending &&
            matchData.status != MatchStatus.Active
        ) {
            revert MatchNotPending();
        }

        address player1 = matchData.player1;
        address player2 = matchData.player2;
        uint256 refundAmount = matchData.amount;

        matchData.status = MatchStatus.Canceled;

        // Refund player1
        (bool success1, ) = payable(player1).call{value: refundAmount}("");
        if (!success1) revert TransferFailed();

        // Refund player2 if match was active
        if (player2 != address(0)) {
            (bool success2, ) = payable(player2).call{value: refundAmount}("");
            if (!success2) revert TransferFailed();
        }

        emit MatchCanceled(matchId, player1, player2, block.timestamp);
    }

    // ============ Admin Functions ============

    /**
     * @notice Updates the admin address
     * @param newAdmin Address of the new admin
     * @dev Only callable by owner
     */
    function setAdmin(address newAdmin) external onlyOwner {
        if (newAdmin == address(0)) revert InvalidAddress();
        address oldAdmin = admin;
        admin = newAdmin;
        emit AdminUpdated(oldAdmin, newAdmin);
    }

    /**
     * @notice Updates the platform fee percentage
     * @param newFeePercentage New fee percentage in basis points
     * @dev Only callable by owner. Max fee is 10%
     */
    function setPlatformFee(uint256 newFeePercentage) external onlyOwner {
        if (newFeePercentage > MAX_FEE_PERCENTAGE)
            revert InvalidFeePercentage();
        uint256 oldFee = platformFeePercentage;
        platformFeePercentage = newFeePercentage;
        emit PlatformFeeUpdated(oldFee, newFeePercentage);
    }

    /**
     * @notice Withdraws accumulated platform fees
     * @param to Address to send fees to
     * @dev Only callable by owner
     */
    function withdrawFees(address payable to) external onlyOwner nonReentrant {
        if (to == address(0)) revert InvalidAddress();
        uint256 amount = accumulatedFees;
        if (amount == 0) revert NoFeesToWithdraw();

        accumulatedFees = 0;

        (bool success, ) = to.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit FeesWithdrawn(to, amount);
    }

    /**
     * @notice Updates minimum bet amount
     * @param _minBetAmount New minimum bet amount in wei
     * @dev Only callable by owner
     */
    function setMinBetAmount(uint256 _minBetAmount) external onlyOwner {
        if (_minBetAmount == 0 || _minBetAmount >= maxBetAmount)
            revert InvalidBetAmount();
        minBetAmount = _minBetAmount;
    }

    /**
     * @notice Updates maximum bet amount
     * @param _maxBetAmount New maximum bet amount in wei
     * @dev Only callable by owner
     */
    function setMaxBetAmount(uint256 _maxBetAmount) external onlyOwner {
        if (_maxBetAmount <= minBetAmount) revert InvalidBetAmount();
        maxBetAmount = _maxBetAmount;
    }

    // ============ View Functions ============

    /**
     * @notice Retrieves match details by ID
     * @param matchId ID of the match
     * @return Match struct containing all match data
     */
    function getMatch(uint256 matchId) external view returns (Match memory) {
        if (matchId == 0 || matchId > matchCounter) revert InvalidMatchId();
        return matches[matchId];
    }

    /**
     * @notice Gets all active match IDs
     * @return Array of active match IDs
     */
    function getActiveMatches() external view returns (uint256[] memory) {
        uint256 activeCount = 0;

        // Count active matches
        for (uint256 i = 0; i < allMatchIds.length; i++) {
            if (matches[allMatchIds[i]].status == MatchStatus.Active) {
                activeCount++;
            }
        }

        // Populate array
        uint256[] memory activeMatches = new uint256[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < allMatchIds.length; i++) {
            if (matches[allMatchIds[i]].status == MatchStatus.Active) {
                activeMatches[index] = allMatchIds[i];
                index++;
            }
        }

        return activeMatches;
    }

    /**
     * @notice Gets all pending match IDs
     * @return Array of pending match IDs
     */
    function getPendingMatches() external view returns (uint256[] memory) {
        uint256 pendingCount = 0;

        // Count pending matches
        for (uint256 i = 0; i < allMatchIds.length; i++) {
            if (matches[allMatchIds[i]].status == MatchStatus.Pending) {
                pendingCount++;
            }
        }

        // Populate array
        uint256[] memory pendingMatches = new uint256[](pendingCount);
        uint256 index = 0;
        for (uint256 i = 0; i < allMatchIds.length; i++) {
            if (matches[allMatchIds[i]].status == MatchStatus.Pending) {
                pendingMatches[index] = allMatchIds[i];
                index++;
            }
        }

        return pendingMatches;
    }

    /**
     * @notice Gets all match IDs for a specific user
     * @param user Address of the user
     * @return Array of match IDs the user participated in
     */
    function getUserMatches(
        address user
    ) external view returns (uint256[] memory) {
        return userMatches[user];
    }

    /**
     * @notice Gets the total number of matches created
     * @return Total match count
     */
    function getTotalMatches() external view returns (uint256) {
        return matchCounter;
    }

    /**
     * @notice Gets contract balance
     * @return Contract ETH balance
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
