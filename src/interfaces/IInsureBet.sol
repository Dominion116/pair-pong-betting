// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IInsureBet {
    // Enums
    enum InsuranceTier {
        None,
        Bronze,
        Silver,
        Gold
    }

    enum ClaimStatus {
        None,
        Pending,
        Approved,
        Paid,
        Rejected
    }

    // Structs
    struct InsuranceInfo {
        uint256 betId;
        address user;
        uint256 matchId;
        uint256 insuredAmount;
        uint256 premiumPaid;
        InsuranceTier tier;
        uint256 timestamp;
        bool claimProcessed;
        uint256 payoutAmount;
    }

    struct TierConfig {
        uint256 premiumPercentage; // in basis points
        uint256 payoutPercentage;  // in basis points
    }

    // Events
    event InsurancePurchased(
        uint256 indexed betId,
        address indexed user,
        uint256 indexed matchId,
        InsuranceTier tier,
        uint256 premiumPaid,
        uint256 insuredAmount
    );

    event ClaimProcessed(
        uint256 indexed betId,
        address indexed user,
        uint256 payoutAmount,
        ClaimStatus status
    );

    event ReservesReplenished(
        uint256 amount,
        uint256 newBalance
    );

    event TierConfigUpdated(
        InsuranceTier tier,
        uint256 premiumPercentage,
        uint256 payoutPercentage
    );

    // Functions
    function registerInsurance(
        uint256 betId,
        address user,
        uint256 matchId,
        uint256 insuredAmount,
        uint256 premiumPaid,
        InsuranceTier tier
    ) external;

    function processClaim(
        uint256 betId
    ) external returns (uint256 payoutAmount);

    function getInsuranceInfo(uint256 betId) external view returns (InsuranceInfo memory);

    function getClaimStatus(uint256 betId) external view returns (ClaimStatus);

    function getUserInsurances(address user) external view returns (InsuranceInfo[] memory);

    function getReserves() external view returns (uint256);

    function getTierConfig(InsuranceTier tier) external view returns (TierConfig memory);

    function calculatePremium(uint256 amount, InsuranceTier tier) external view returns (uint256);

    function calculatePayout(uint256 amount, InsuranceTier tier) external view returns (uint256);

    function replenishReserves() external payable;
}