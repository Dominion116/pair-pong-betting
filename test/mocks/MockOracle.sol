// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../src/interfaces/IBettingPool.sol";

contract MockOracle {
    address public owner;

    event MatchApproved(address indexed pool, uint256 indexed matchId, uint256 startTime);
    event MatchSettled(address indexed pool, uint256 indexed matchId, IBettingPool.BetSide winner);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "MockOracle: not owner");
        _;
    }

    /// @notice Calls BettingPool.approveMatch as the oracle
    function approveMatch(address pool, uint256 matchId, uint256 startTime) external onlyOwner {
        IBettingPool(pool).approveMatch(matchId, startTime);
        emit MatchApproved(pool, matchId, startTime);
    }

    /// @notice Calls BettingPool.settleBet as the oracle
    function settleMatch(address pool, uint256 matchId, IBettingPool.BetSide winner) external onlyOwner {
        IBettingPool(pool).settleBet(matchId, winner);
        emit MatchSettled(pool, matchId, winner);
    }
}