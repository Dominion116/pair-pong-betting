// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/PairPong.sol";
import "./mocks/MockERC20.sol";

/**
 * @title PairPongTest
 * @notice Base test contract with common setup and helper functions
 * @dev Extended by specific test contracts
 */
contract PairPongTest is Test {
    // ============ Contracts ============
    PairPong public pairPong;
    MockERC20 public token1;
    MockERC20 public token2;
    MockERC20 public token3;

    // ============ Test Accounts ============
    address public owner;
    address public admin;
    address public player1;
    address public player2;
    address public player3;
    address public feeRecipient;

    // ============ Constants ============
    uint256 public constant PLATFORM_FEE = 200; // 2%
    uint256 public constant MIN_BET = 0.01 ether;
    uint256 public constant MAX_BET = 10 ether;
    uint256 public constant DEFAULT_BET = 0.1 ether;

    // ============ Events for Testing ============
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

    // ============ Setup ============

    function setUp() public virtual {
        // Setup accounts
        owner = makeAddr("owner");
        admin = makeAddr("admin");
        player1 = makeAddr("player1");
        player2 = makeAddr("player2");
        player3 = makeAddr("player3");
        feeRecipient = makeAddr("feeRecipient");

        // Fund accounts
        vm.deal(owner, 100 ether);
        vm.deal(admin, 100 ether);
        vm.deal(player1, 100 ether);
        vm.deal(player2, 100 ether);
        vm.deal(player3, 100 ether);

        // Deploy contract as owner
        vm.prank(owner);
        pairPong = new PairPong(admin, PLATFORM_FEE, MIN_BET, MAX_BET);

        // Deploy mock tokens
        token1 = new MockERC20("Token1", "TK1", 18);
        token2 = new MockERC20("Token2", "TK2", 18);
        token3 = new MockERC20("Token3", "TK3", 18);

        // Label addresses for better trace output
        vm.label(address(pairPong), "PairPong");
        vm.label(address(token1), "Token1");
        vm.label(address(token2), "Token2");
        vm.label(address(token3), "Token3");
        vm.label(owner, "Owner");
        vm.label(admin, "Admin");
        vm.label(player1, "Player1");
        vm.label(player2, "Player2");
        vm.label(player3, "Player3");
    }

    // ============ Helper Functions ============

    /**
     * @notice Helper to create a match
     * @param creator Address creating the match
     * @param token Token address to bet on
     * @param amount Bet amount
     * @return matchId ID of created match
     */
    function createMatch(address creator, address token, uint256 amount)
        internal
        returns (uint256 matchId)
    {
        vm.prank(creator);
        matchId = pairPong.createMatch{value: amount}(token);
    }

    /**
     * @notice Helper to join a match
     * @param joiner Address joining the match
     * @param matchId Match ID to join
     * @param token Token address to bet on
     * @param amount Bet amount
     */
    function joinMatch(address joiner, uint256 matchId, address token, uint256 amount) internal {
        vm.prank(joiner);
        pairPong.joinMatch{value: amount}(matchId, token);
    }

    /**
     * @notice Helper to finalize a match
     * @param matchId Match ID to finalize
     * @param winner Winner address
     */
    function finalizeMatch(uint256 matchId, address winner) internal {
        vm.prank(admin);
        pairPong.finalizeMatch(matchId, winner);
    }

    /**
     * @notice Helper to cancel a match
     * @param matchId Match ID to cancel
     */
    function cancelMatch(uint256 matchId) internal {
        vm.prank(admin);
        pairPong.cancelMatch(matchId);
    }

    /**
     * @notice Helper to create and join a complete match
     * @return matchId ID of the created and joined match
     */
    function createCompleteMatch() internal returns (uint256 matchId) {
        matchId = createMatch(player1, address(token1), DEFAULT_BET);
        joinMatch(player2, matchId, address(token2), DEFAULT_BET);
    }

    /**
     * @notice Calculate expected platform fee
     * @param totalPool Total pool amount
     * @return fee Expected platform fee
     */
    function calculatePlatformFee(uint256 totalPool) internal view returns (uint256 fee) {
        fee = (totalPool * pairPong.platformFeePercentage()) / 10000;
    }

    /**
     * @notice Calculate expected winner payout
     * @param totalPool Total pool amount
     * @return payout Expected winner payout
     */
    function calculateWinnerPayout(uint256 totalPool) internal view returns (uint256 payout) {
        uint256 fee = calculatePlatformFee(totalPool);
        payout = totalPool - fee;
    }
}

/**
 * @title PairPongIntegrationTest
 * @notice Integration tests for complete match flows
 */
contract PairPongIntegrationTest is PairPongTest {
    function test_CompleteMatchFlow() public {
        // Create match
        uint256 matchId = createMatch(player1, address(token1), DEFAULT_BET);

        // Verify match created
        IPairPong.MatchData memory matchData = pairPong.getMatch(matchId);
        assertEq(matchData.player1, player1);
        assertEq(matchData.token1, address(token1));
        assertEq(matchData.amount, DEFAULT_BET);
        assertEq(uint8(matchData.status), uint8(IPairPong.MatchStatus.Pending));

        // Join match
        joinMatch(player2, matchId, address(token2), DEFAULT_BET);

        // Verify match joined
        matchData = pairPong.getMatch(matchId);
        assertEq(matchData.player2, player2);
        assertEq(matchData.token2, address(token2));
        assertEq(uint8(matchData.status), uint8(IPairPong.MatchStatus.Active));

        // Record balances before finalization
        uint256 player1BalanceBefore = player1.balance;
        uint256 contractBalanceBefore = address(pairPong).balance;

        // Finalize match with player1 as winner
        finalizeMatch(matchId, player1);

        // Verify match finalized
        matchData = pairPong.getMatch(matchId);
        assertEq(matchData.winner, player1);
        assertEq(uint8(matchData.status), uint8(IPairPong.MatchStatus.Completed));

        // Verify payouts
        uint256 totalPool = DEFAULT_BET * 2;
        uint256 expectedPayout = calculateWinnerPayout(totalPool);
        uint256 expectedFee = calculatePlatformFee(totalPool);

        assertEq(player1.balance, player1BalanceBefore + expectedPayout);
        assertEq(pairPong.accumulatedFees(), expectedFee);
        assertEq(address(pairPong).balance, contractBalanceBefore - expectedPayout);
    }

    function test_MultipleMatches() public {
        // Create 3 matches
        uint256 match1 = createMatch(player1, address(token1), DEFAULT_BET);
        uint256 match2 = createMatch(player2, address(token2), DEFAULT_BET);
        uint256 match3 = createMatch(player3, address(token3), DEFAULT_BET);

        // Verify match IDs are sequential
        assertEq(match1, 1);
        assertEq(match2, 2);
        assertEq(match3, 3);

        // Join matches
        joinMatch(player2, match1, address(token2), DEFAULT_BET);
        joinMatch(player3, match2, address(token3), DEFAULT_BET);

        // Verify pending and active matches
        uint256[] memory activeMatches = pairPong.getActiveMatches();
        uint256[] memory pendingMatches = pairPong.getPendingMatches();

        assertEq(activeMatches.length, 2);
        assertEq(pendingMatches.length, 1);
        assertEq(pendingMatches[0], match3);
    }

    function test_GetUserMatches() public {
        // Player1 creates 2 matches
        createMatch(player1, address(token1), DEFAULT_BET);
        createMatch(player1, address(token2), DEFAULT_BET);

        // Player2 joins first match and creates one
        joinMatch(player2, 1, address(token2), DEFAULT_BET);
        createMatch(player2, address(token3), DEFAULT_BET);

        // Verify user matches
        uint256[] memory player1Matches = pairPong.getUserMatches(player1);
        uint256[] memory player2Matches = pairPong.getUserMatches(player2);

        assertEq(player1Matches.length, 2);
        assertEq(player2Matches.length, 2);
        assertEq(player1Matches[0], 1);
        assertEq(player1Matches[1], 2);
        assertEq(player2Matches[0], 1);
        assertEq(player2Matches[1], 3);
    }

    function test_ContractBalance() public {
        // Create and join multiple matches
        createCompleteMatch();
        createCompleteMatch();

        uint256 expectedBalance = DEFAULT_BET * 4;
        assertEq(pairPong.getContractBalance(), expectedBalance);
    }
}

/**
 * @title PairPongViewFunctionsTest
 * @notice Tests for view functions
 */
contract PairPongViewFunctionsTest is PairPongTest {
    function test_GetMatch() public {
        uint256 matchId = createMatch(player1, address(token1), DEFAULT_BET);

        IPairPong.MatchData memory matchData = pairPong.getMatch(matchId);

        assertEq(matchData.id, matchId);
        assertEq(matchData.player1, player1);
        assertEq(matchData.token1, address(token1));
        assertEq(matchData.amount, DEFAULT_BET);
        assertEq(matchData.player2, address(0));
        assertEq(matchData.winner, address(0));
        assertEq(uint8(matchData.status), uint8(IPairPong.MatchStatus.Pending));
    }

    function test_GetMatch_RevertsForInvalidId() public {
        vm.expectRevert(IPairPong.InvalidMatchId.selector);
        pairPong.getMatch(999);

        vm.expectRevert(IPairPong.InvalidMatchId.selector);
        pairPong.getMatch(0);
    }

    function test_GetActiveMatches() public {
        // Create pending matches
        createMatch(player1, address(token1), DEFAULT_BET);
        createMatch(player2, address(token2), DEFAULT_BET);

        // No active matches yet
        uint256[] memory activeMatches = pairPong.getActiveMatches();
        assertEq(activeMatches.length, 0);

        // Join first match
        joinMatch(player2, 1, address(token2), DEFAULT_BET);

        // Should have 1 active match
        activeMatches = pairPong.getActiveMatches();
        assertEq(activeMatches.length, 1);
        assertEq(activeMatches[0], 1);
    }

    function test_GetPendingMatches() public {
        createMatch(player1, address(token1), DEFAULT_BET);
        createMatch(player2, address(token2), DEFAULT_BET);

        uint256[] memory pendingMatches = pairPong.getPendingMatches();
        assertEq(pendingMatches.length, 2);
        assertEq(pendingMatches[0], 1);
        assertEq(pendingMatches[1], 2);

        // Join first match
        joinMatch(player2, 1, address(token2), DEFAULT_BET);

        // Should have 1 pending match
        pendingMatches = pairPong.getPendingMatches();
        assertEq(pendingMatches.length, 1);
        assertEq(pendingMatches[0], 2);
    }

    function test_GetTotalMatches() public {
        assertEq(pairPong.getTotalMatches(), 0);

        createMatch(player1, address(token1), DEFAULT_BET);
        assertEq(pairPong.getTotalMatches(), 1);

        createMatch(player2, address(token2), DEFAULT_BET);
        assertEq(pairPong.getTotalMatches(), 2);
    }
}