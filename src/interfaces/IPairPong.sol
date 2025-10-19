// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IPairPong
 * @notice Interface for the PairPong betting contract
 * @dev Defines all external functions, events, and custom errors
 */
interface IPairPong {
    // ============ Enums ============

    enum MatchStatus {
        Pending,    // Waiting for player2 to join
        Active,     // Both players joined, awaiting settlement
        Completed,  // Match settled, winner paid
        Canceled    // Match canceled, refunds processed
    }

    // ============ Structs ============

    struct Match {
        uint256 id;
        address player1;
        address player2;
        address token1;         // Token selected by player1
        address token2;         // Token selected by player2
        uint256 amount;         // Bet amount per player
        address winner;
        MatchStatus status;
        uint256 createdAt;
    }

    // ============ Events ============

    event MatchCreated(
        uint256 indexed matchId,
        address indexed player1,
        address token1,
        uint256 amount,
        uint256 timestamp
    );

    event MatchJoined(
        uint256 indexed matchId,
        address indexed player2,
        address token2,
        uint256 timestamp
    );

    event MatchSettled(
        uint256 indexed matchId,
        address indexed winner,
        uint256 amountWon,
        uint256 platformFee,
        uint256 timestamp
    );

    event MatchCanceled(
        uint256 indexed matchId,
        address indexed player1,
        address indexed player2,
        uint256 timestamp
    );

    event AdminUpdated(address indexed oldAdmin, address indexed newAdmin);

    event PlatformFeeUpdated(uint256 oldFee, uint256 newFee);

    event FeesWithdrawn(address indexed to, uint256 amount);

    // ============ Custom Errors ============

    error InvalidBetAmount();
    error InvalidMatchId();
    error MatchNotPending();
    error MatchNotActive();
    error PlayerAlreadyInMatch();
    error SameTokenSelected();
    error InvalidTokenAddress();
    error TransferFailed();
    error UnauthorizedAccess();
    error InvalidFeePercentage();
    error NoFeesToWithdraw();
    error InvalidAddress();

    // ============ External Functions ============

    function createMatch(address tokenSelected) external payable returns (uint256 matchId);

    function joinMatch(uint256 matchId, address tokenSelected) external payable;

    function finalizeMatch(uint256 matchId, address winner) external;

    function cancelMatch(uint256 matchId) external;

    function setAdmin(address newAdmin) external;

    function setPlatformFee(uint256 newFeePercentage) external;

    function withdrawFees(address payable to) external;

    // ============ View Functions ============

    function getMatch(uint256 matchId) external view returns (Match memory);

    function getActiveMatches() external view returns (uint256[] memory);

    function getPendingMatches() external view returns (uint256[] memory);

    function getUserMatches(address user) external view returns (uint256[] memory);

    function accumulatedFees() external view returns (uint256);

    function platformFeePercentage() external view returns (uint256);

    function minBetAmount() external view returns (uint256);

    function maxBetAmount() external view returns (uint256);
}