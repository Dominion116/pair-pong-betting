// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts/contracts/access/Ownable.sol" as OZAccess;
import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol" as OZUtils;
import "openzeppelin-contracts/contracts/access/Ownable2Step.sol" as OZOwnership;
import "./interfaces/IPairPong.sol" as IPP;

/**
 * @title PairPong
 * @notice A 1v1 betting contract where users bet on crypto token performance
 * @dev Users stake ETH and select tokens. Frontend determines winner and calls finalizeMatch().
 *      Fees are stored and expressed in BPS (basis points). MAX cap is inclusive.
 */
contract PairPong is IPP.IPairPong, OZOwnership.Ownable2Step, OZUtils.ReentrancyGuard {
    // ============ State Variables ============
    address public admin;
    uint256 public matchCounter;

    // Fee is stored as BPS (e.g., 300 = 3.00%)
    uint256 public platformFeePercentage;

    uint256 public accumulatedFees;
    uint256 public minBetAmount;
    uint256 public maxBetAmount;

    mapping(uint256 => MatchData) public matches;
    mapping(address => uint256[]) public userMatches;
    uint256[] private allMatchIds;

    // ============ Constants ============
    uint256 private constant BASIS_POINTS = 10_000;            // 100.00%
    uint256 public constant MAX_FEE_PERCENTAGE = 1_000;        // 10.00% max (inclusive)

    // ============ Constructor ============
    constructor(
        address _admin,
        uint256 _platformFeePercentage, // in BPS
        uint256 _minBetAmount,
        uint256 _maxBetAmount
    ) OZAccess.Ownable(msg.sender) {
        if (_admin == address(0)) revert InvalidAddress();
        if (_platformFeePercentage > MAX_FEE_PERCENTAGE) revert InvalidFeePercentage();
        if (_minBetAmount == 0 || _maxBetAmount <= _minBetAmount) revert InvalidBetAmount();

        admin = _admin;
        platformFeePercentage = _platformFeePercentage;
        minBetAmount = _minBetAmount;
        maxBetAmount = _maxBetAmount;
    }

    // ============ Receive ============
    // Optional: accept direct ETH sends (not used for matches, but harmless)
    receive() external payable {}

    // ============ Internal Access Checks ============
    function _onlyAdmin() internal view {
        if (msg.sender != admin) revert UnauthorizedAccess();
    }

    function _onlyOwnerOrAdmin() internal view {
        if (msg.sender != owner() && msg.sender != admin) revert UnauthorizedAccess();
    }

    // ============ Modifiers ============
    modifier onlyAdmin() {
        _onlyAdmin();
        _;
    }

    modifier onlyOwnerOrAdmin() {
        _onlyOwnerOrAdmin();
        _;
    }

    // ============ Betting Functions ============
    function createMatch(address tokenSelected)
        external
        payable
        nonReentrant
        override
        returns (uint256 matchId)
    {
        if (msg.value < minBetAmount || msg.value > maxBetAmount) revert InvalidBetAmount();
        if (tokenSelected == address(0)) revert InvalidTokenAddress();

        matchId = ++matchCounter;

        matches[matchId] = MatchData({
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

        emit MatchCreated(matchId, msg.sender, tokenSelected, msg.value, block.timestamp);
    }

    function joinMatch(uint256 matchId, address tokenSelected)
        external
        payable
        nonReentrant
        override
    {
        if (matchId == 0 || matchId > matchCounter) revert InvalidMatchId();
        MatchData storage matchData = matches[matchId];

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

    // ============ Settlement Functions ============
    function finalizeMatch(uint256 matchId, address winner)
        external
        onlyAdmin
        nonReentrant
        override
    {
        if (matchId == 0 || matchId > matchCounter) revert InvalidMatchId();
        MatchData storage matchData = matches[matchId];

        if (matchData.status != MatchStatus.Active) revert MatchNotActive();
        if (winner != matchData.player1 && winner != matchData.player2) revert InvalidAddress();

        matchData.status = MatchStatus.Completed;
        matchData.winner = winner;

        uint256 totalPool = matchData.amount * 2;
        uint256 platformFee = (totalPool * platformFeePercentage) / BASIS_POINTS;
        uint256 winnerPayout = totalPool - platformFee;
        accumulatedFees += platformFee;

        (bool success, ) = payable(winner).call{value: winnerPayout}("");
        if (!success) revert TransferFailed();

        emit MatchSettled(matchId, winner, winnerPayout, platformFee, block.timestamp);
    }

    function cancelMatch(uint256 matchId)
        external
        onlyOwnerOrAdmin
        nonReentrant
        override
    {
        if (matchId == 0 || matchId > matchCounter) revert InvalidMatchId();
        MatchData storage matchData = matches[matchId];

        if (
            matchData.status != MatchStatus.Pending &&
            matchData.status != MatchStatus.Active
        ) revert MatchNotPending();

        address player1 = matchData.player1;
        address player2 = matchData.player2;
        uint256 refundAmount = matchData.amount;

        matchData.status = MatchStatus.Canceled;

        (bool success1, ) = payable(player1).call{value: refundAmount}("");
        if (!success1) revert TransferFailed();

        if (player2 != address(0)) {
            (bool success2, ) = payable(player2).call{value: refundAmount}("");
            if (!success2) revert TransferFailed();
        }

        emit MatchCanceled(matchId, player1, player2, block.timestamp);
    }

    // ============ Admin Functions ============
    function setAdmin(address newAdmin) external onlyOwner override {
        if (newAdmin == address(0)) revert InvalidAddress();
        address oldAdmin = admin;
        admin = newAdmin;
        emit AdminUpdated(oldAdmin, newAdmin);
    }

    /// @notice Set platform fee in BPS (max is inclusive)
    function setPlatformFee(uint256 newFeePercentage) external onlyOwner override {
        if (newFeePercentage > MAX_FEE_PERCENTAGE) revert InvalidFeePercentage();
        uint256 oldFee = platformFeePercentage;
        platformFeePercentage = newFeePercentage;
        emit PlatformFeeUpdated(oldFee, newFeePercentage);
    }

    function withdrawFees(address payable to) external onlyOwner nonReentrant override {
        if (to == address(0)) revert InvalidAddress();
        uint256 amount = accumulatedFees;
        if (amount == 0) revert NoFeesToWithdraw();

        accumulatedFees = 0;
        (bool success, ) = to.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit FeesWithdrawn(to, amount);
    }

    function setMinBetAmount(uint256 _minBetAmount) external onlyOwner {
        if (_minBetAmount == 0 || _minBetAmount >= maxBetAmount) revert InvalidBetAmount();
        minBetAmount = _minBetAmount;
    }

    function setMaxBetAmount(uint256 _maxBetAmount) external onlyOwner {
        if (_maxBetAmount <= minBetAmount) revert InvalidBetAmount();
        maxBetAmount = _maxBetAmount;
    }

    // ============ View Functions ============
    function getMatch(uint256 matchId) external view override returns (MatchData memory) {
        if (matchId == 0 || matchId > matchCounter) revert InvalidMatchId();
        return matches[matchId];
    }

    function getActiveMatches() external view override returns (uint256[] memory) {
        uint256 activeCount;
        for (uint256 i; i < allMatchIds.length; i++) {
            if (matches[allMatchIds[i]].status == MatchStatus.Active) activeCount++;
        }

        uint256[] memory activeMatches = new uint256[](activeCount);
        uint256 index;
        for (uint256 i; i < allMatchIds.length; i++) {
            if (matches[allMatchIds[i]].status == MatchStatus.Active) {
                activeMatches[index++] = allMatchIds[i];
            }
        }
        return activeMatches;
    }

    function getPendingMatches() external view override returns (uint256[] memory) {
        uint256 pendingCount;
        for (uint256 i; i < allMatchIds.length; i++) {
            if (matches[allMatchIds[i]].status == MatchStatus.Pending) pendingCount++;
        }

        uint256[] memory pendingMatches = new uint256[](pendingCount);
        uint256 index;
        for (uint256 i; i < allMatchIds.length; i++) {
            if (matches[allMatchIds[i]].status == MatchStatus.Pending) {
                pendingMatches[index++] = allMatchIds[i];
            }
        }
        return pendingMatches;
    }

    function getUserMatches(address user) external view override returns (uint256[] memory) {
        return userMatches[user];
    }

    // --------- Extra helpers (optional) ---------
    function getTotalMatches() external view returns (uint256) {
        return matchCounter;
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
