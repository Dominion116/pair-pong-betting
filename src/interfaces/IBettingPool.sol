// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBettingPool {
    // Enums
    enum BetStatus {
        Pending,
        Matched,
        Won,
        Lost,
        Refunded
    }

    enum BetSide {
        PlayerA,
        PlayerB
    }

    enum InsuranceTier {
        None,
        Bronze,
        Silver,
        Gold
    }

    // Structs
    struct Bet {
        uint256 betId;
        address user;
        uint256 matchId;
        BetSide side;
        uint256 amount;
        uint256 timestamp;
        BetStatus status;
        bool insured;
        InsuranceTier insuranceTier;
        uint256 premiumPaid;
        uint256[] matchedBetIds;
        bool matchedWithHouse;
    }

    struct MatchingResult {
        uint256[] matchedBetIds;
        uint256 matchedAmount;
        uint256 unmatchedAmount;
        bool fullyMatched;
    }

    // Events
    event BetPlaced(
        uint256 indexed betId,
        address indexed user,
        uint256 indexed matchId,
        BetSide side,
        uint256 amount,
        bool insured,
        InsuranceTier insuranceTier
    );

    event BetsMatched(
        uint256 indexed betId1,
        uint256 indexed betId2,
        uint256 matchedAmount
    );

    event BetMatchedWithHouse(
        uint256 indexed betId,
        uint256 amount
    );

    event BetSettled(
        uint256 indexed betId,
        address indexed user,
        uint256 payout,
        BetStatus status
    );

    event BetRefunded(
        uint256 indexed betId,
        address indexed user,
        uint256 amount
    );

    event MatchApproved(
        uint256 indexed matchId,
        uint256 startTime
    );

    event VaultReplenished(
        uint256 amount,
        uint256 newBalance
    );

    // Functions
    function placeBet(
        uint256 matchId,
        BetSide side,
        InsuranceTier insuranceTier
    ) external payable returns (uint256 betId);

    function settleBet(
        uint256 matchId,
        BetSide winningSide
    ) external;

    function refundBet(uint256 betId) external;

    function approveMatch(
        uint256 matchId,
        uint256 startTime
    ) external;

    function getBet(uint256 betId) external view returns (Bet memory);

    function getUserBets(address user) external view returns (Bet[] memory);

    function getMatchBets(uint256 matchId) external view returns (Bet[] memory);

    function getUnmatchedBets(uint256 matchId, BetSide side) external view returns (uint256[] memory);

    function getPoolBalance() external view returns (uint256);

    function getVaultBalance() external view returns (uint256);

    function calculateFee(uint256 amount) external pure returns (uint256);

    function replenishVault() external payable;
}