// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IVault {
    // Events
    event Deposited(
        address indexed depositor,
        uint256 amount,
        uint256 newBalance
    );

    event Withdrawn(
        address indexed recipient,
        uint256 amount,
        uint256 newBalance
    );

    event PayoutProcessed(
        uint256 indexed betId,
        address indexed recipient,
        uint256 amount
    );

    event ReserveThresholdUpdated(
        uint256 oldThreshold,
        uint256 newThreshold
    );

    event EmergencyWithdrawal(
        address indexed recipient,
        uint256 amount
    );

    event BettingPoolUpdated(
        address indexed oldPool,
        address indexed newPool
    );

    // Functions
    function deposit() external payable;

    function processHousePayout(
        uint256 betId,
        address recipient,
        uint256 amount
    ) external returns (bool success);

    function withdraw(uint256 amount) external;

    function emergencyWithdraw() external;

    function getBalance() external view returns (uint256);

    function getReserveThreshold() external view returns (uint256);

    function isAboveThreshold() external view returns (bool);

    function getAvailableLiquidity() external view returns (uint256);

    function setReserveThreshold(uint256 newThreshold) external;

    function setBettingPool(address newBettingPool) external;
}