// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./PairPong.t.sol";

/**
 * @title PairPongBettingTest
 * @notice Tests for betting logic including match creation, joining, and settlement
 */
contract PairPongBettingTest is PairPongTest {
    // ============ Match Creation Tests ============

    function test_CreateMatch() public {
        uint256 balanceBefore = player1.balance;

        vm.expectEmit(true, true, false, false);
        emit MatchCreated(1, player1, address(token1), DEFAULT_BET, block.timestamp);

        uint256 matchId = createMatch(player1, address(token1), DEFAULT_BET);

        assertEq(matchId, 1);
        assertEq(pairPong.matchCounter(), 1);
        assertEq(player1.balance, balanceBefore - DEFAULT_BET);

        IPairPong.MatchData memory matchData = pairPong.getMatch(matchId);
        assertEq(matchData.id, matchId);
        assertEq(matchData.player1, player1);
        assertEq(matchData.token1, address(token1));
        assertEq(matchData.amount, DEFAULT_BET);
        assertEq(matchData.player2, address(0));
        assertEq(matchData.winner, address(0));
        assertEq(uint8(matchData.status), uint8(IPairPong.MatchStatus.Pending));
    }

    function test_CreateMatch_RevertsIfBetTooLow() public {
        vm.prank(player1);
        vm.expectRevert(IPairPong.InvalidBetAmount.selector);
        pairPong.createMatch{value: MIN_BET - 1}(address(token1));
    }

    function test_CreateMatch_RevertsIfBetTooHigh() public {
        vm.prank(player1);
        vm.expectRevert(IPairPong.InvalidBetAmount.selector);
        pairPong.createMatch{value: MAX_BET + 1}(address(token1));
    }

    function test_CreateMatch_RevertsForZeroTokenAddress() public {
        vm.prank(player1);
        vm.expectRevert(IPairPong.InvalidTokenAddress.selector);
        pairPong.createMatch{value: DEFAULT_BET}(address(0));
    }

    function test_CreateMatch_AcceptsMinBet() public {
        uint256 matchId = createMatch(player1, address(token1), MIN_BET);
        
        IPairPong.MatchData memory matchData = pairPong.getMatch(matchId);
        assertEq(matchData.amount, MIN_BET);
    }

    function test_CreateMatch_AcceptsMaxBet() public {
        uint256 matchId = createMatch(player1, address(token1), MAX_BET);
        
        IPairPong.MatchData memory matchData = pairPong.getMatch(matchId);
        assertEq(matchData.amount, MAX_BET);
    }

    function test_CreateMatch_IncreasesMatchCounter() public {
        assertEq(pairPong.matchCounter(), 0);
        
        createMatch(player1, address(token1), DEFAULT_BET);
        assertEq(pairPong.matchCounter(), 1);
        
        createMatch(player2, address(token2), DEFAULT_BET);
        assertEq(pairPong.matchCounter(), 2);
    }

    function test_CreateMatch_TransfersETHToContract() public {
        uint256 contractBalanceBefore = address(pairPong).balance;
        
        createMatch(player1, address(token1), DEFAULT_BET);
        
        assertEq(address(pairPong).balance, contractBalanceBefore + DEFAULT_BET);
    }

    // ============ Join Match Tests ============

    function test_JoinMatch() public {
        uint256 matchId = createMatch(player1, address(token1), DEFAULT_BET);
        uint256 balanceBefore = player2.balance;

        vm.expectEmit(true, true, false, false);
        emit MatchJoined(matchId, player2, address(token2), block.timestamp);

        joinMatch(player2, matchId, address(token2), DEFAULT_BET);

        assertEq(player2.balance, balanceBefore - DEFAULT_BET);

        IPairPong.MatchData memory matchData = pairPong.getMatch(matchId);
        assertEq(matchData.player2, player2);
        assertEq(matchData.token2, address(token2));
        assertEq(uint8(matchData.status), uint8(IPairPong.MatchStatus.Active));
    }

    function test_JoinMatch_RevertsForInvalidMatchId() public {
        vm.prank(player2);
        vm.expectRevert(IPairPong.InvalidMatchId.selector);
        pairPong.joinMatch{value: DEFAULT_BET}(999, address(token2));
    }

    function test_JoinMatch_RevertsIfNotPending() public {
        uint256 matchId = createCompleteMatch();

        vm.prank(player3);
        vm.expectRevert(IPairPong.MatchNotPending.selector);
        pairPong.joinMatch{value: DEFAULT_BET}(matchId, address(token3));
    }

    function test_JoinMatch_RevertsIfWrongAmount() public {
        uint256 matchId = createMatch(player1, address(token1), DEFAULT_BET);

        vm.prank(player2);
        vm.expectRevert(IPairPong.InvalidBetAmount.selector);
        pairPong.joinMatch{value: DEFAULT_BET + 0.01 ether}(matchId, address(token2));
    }

    function test_JoinMatch_RevertsIfCreatorTriesToJoin() public {
        uint256 matchId = createMatch(player1, address(token1), DEFAULT_BET);

        vm.prank(player1);
        vm.expectRevert(IPairPong.PlayerAlreadyInMatch.selector);
        pairPong.joinMatch{value: DEFAULT_BET}(matchId, address(token2));
    }

    function test_JoinMatch_RevertsForZeroTokenAddress() public {
        uint256 matchId = createMatch(player1, address(token1), DEFAULT_BET);

        vm.prank(player2);
        vm.expectRevert(IPairPong.InvalidTokenAddress.selector);
        pairPong.joinMatch{value: DEFAULT_BET}(matchId, address(0));
    }

    function test_JoinMatch_RevertsIfSameToken() public {
        uint256 matchId = createMatch(player1, address(token1), DEFAULT_BET);

        vm.prank(player2);
        vm.expectRevert(IPairPong.SameTokenSelected.selector);
        pairPong.joinMatch{value: DEFAULT_BET}(matchId, address(token1));
    }

    function test_JoinMatch_TransfersETHToContract() public {
        uint256 matchId = createMatch(player1, address(token1), DEFAULT_BET);
        uint256 contractBalanceBefore = address(pairPong).balance;

        joinMatch(player2, matchId, address(token2), DEFAULT_BET);

        assertEq(address(pairPong).balance, contractBalanceBefore + DEFAULT_BET);
    }

    // ============ Finalize Match Tests ============

    function test_FinalizeMatch_Player1Wins() public {
        uint256 matchId = createCompleteMatch();
        uint256 player1BalanceBefore = player1.balance;
        uint256 contractBalanceBefore = address(pairPong).balance;

        uint256 totalPool = DEFAULT_BET * 2;
        uint256 expectedFee = calculatePlatformFee(totalPool);
        uint256 expectedPayout = calculateWinnerPayout(totalPool);

        vm.expectEmit(true, true, false, false);
        emit MatchSettled(matchId, player1, expectedPayout, expectedFee, block.timestamp);

        finalizeMatch(matchId, player1);

        IPairPong.MatchData memory matchData = pairPong.getMatch(matchId);
        assertEq(matchData.winner, player1);
        assertEq(uint8(matchData.status), uint8(IPairPong.MatchStatus.Completed));
        assertEq(player1.balance, player1BalanceBefore + expectedPayout);
        assertEq(pairPong.accumulatedFees(), expectedFee);
        assertEq(address(pairPong).balance, contractBalanceBefore - expectedPayout);
    }

    function test_FinalizeMatch_Player2Wins() public {
        uint256 matchId = createCompleteMatch();
        uint256 player2BalanceBefore = player2.balance;

        uint256 expectedPayout = calculateWinnerPayout(DEFAULT_BET * 2);

        finalizeMatch(matchId, player2);

        IPairPong.MatchData memory matchData = pairPong.getMatch(matchId);
        assertEq(matchData.winner, player2);
        assertEq(player2.balance, player2BalanceBefore + expectedPayout);
    }

    function test_FinalizeMatch_RevertsForInvalidMatchId() public {
        vm.prank(admin);
        vm.expectRevert(IPairPong.InvalidMatchId.selector);
        pairPong.finalizeMatch(999, player1);
    }

    function test_FinalizeMatch_RevertsIfNotActive() public {
        uint256 matchId = createMatch(player1, address(token1), DEFAULT_BET);

        vm.prank(admin);
        vm.expectRevert(IPairPong.MatchNotActive.selector);
        pairPong.finalizeMatch(matchId, player1);
    }

    function test_FinalizeMatch_RevertsForInvalidWinner() public {
        uint256 matchId = createCompleteMatch();

        vm.prank(admin);
        vm.expectRevert(IPairPong.InvalidAddress.selector);
        pairPong.finalizeMatch(matchId, player3);
    }

    function test_FinalizeMatch_RevertsIfAlreadyCompleted() public {
        uint256 matchId = createCompleteMatch();
        finalizeMatch(matchId, player1);

        vm.prank(admin);
        vm.expectRevert(IPairPong.MatchNotActive.selector);
        pairPong.finalizeMatch(matchId, player1);
    }

    function test_FinalizeMatch_AccumulatesFees() public {
        // First match
        uint256 match1 = createCompleteMatch();
        finalizeMatch(match1, player1);
        uint256 fee1 = pairPong.accumulatedFees();

        // Second match
        uint256 match2 = createCompleteMatch();
        finalizeMatch(match2, player2);
        uint256 fee2 = pairPong.accumulatedFees();

        uint256 expectedFeePerMatch = calculatePlatformFee(DEFAULT_BET * 2);
        assertEq(fee1, expectedFeePerMatch);
        assertEq(fee2, expectedFeePerMatch * 2);
    }

    function test_FinalizeMatch_CorrectFeeCalculation() public {
        uint256 matchId = createCompleteMatch();
        
        uint256 totalPool = DEFAULT_BET * 2;
        uint256 expectedFee = (totalPool * PLATFORM_FEE) / 10000;
        uint256 expectedPayout = totalPool - expectedFee;

        finalizeMatch(matchId, player1);

        assertEq(pairPong.accumulatedFees(), expectedFee);
        
        // Verify payout calculation
        assertEq(expectedPayout, calculateWinnerPayout(totalPool));
    }

    // ============ Cancel Match Tests ============

    function test_CancelMatch_Pending() public {
        uint256 matchId = createMatch(player1, address(token1), DEFAULT_BET);
        uint256 player1BalanceBefore = player1.balance;

        vm.expectEmit(true, true, true, false);
        emit MatchCanceled(matchId, player1, address(0), block.timestamp);

        cancelMatch(matchId);

        IPairPong.MatchData memory matchData = pairPong.getMatch(matchId);
        assertEq(uint8(matchData.status), uint8(IPairPong.MatchStatus.Canceled));
        assertEq(player1.balance, player1BalanceBefore + DEFAULT_BET);
    }

    function test_CancelMatch_Active() public {
        uint256 matchId = createCompleteMatch();
        uint256 player1BalanceBefore = player1.balance;
        uint256 player2BalanceBefore = player2.balance;

        vm.expectEmit(true, true, true, false);
        emit MatchCanceled(matchId, player1, player2, block.timestamp);

        cancelMatch(matchId);

        IPairPong.MatchData memory matchData = pairPong.getMatch(matchId);
        assertEq(uint8(matchData.status), uint8(IPairPong.MatchStatus.Canceled));
        assertEq(player1.balance, player1BalanceBefore + DEFAULT_BET);
        assertEq(player2.balance, player2BalanceBefore + DEFAULT_BET);
    }

    function test_CancelMatch_RevertsForInvalidMatchId() public {
        vm.prank(admin);
        vm.expectRevert(IPairPong.InvalidMatchId.selector);
        pairPong.cancelMatch(999);
    }

    function test_CancelMatch_RevertsIfCompleted() public {
        uint256 matchId = createCompleteMatch();
        finalizeMatch(matchId, player1);

        vm.prank(admin);
        vm.expectRevert(IPairPong.MatchNotPending.selector);
        pairPong.cancelMatch(matchId);
    }

    function test_CancelMatch_RevertsIfAlreadyCanceled() public {
        uint256 matchId = createMatch(player1, address(token1), DEFAULT_BET);
        cancelMatch(matchId);

        vm.prank(admin);
        vm.expectRevert(IPairPong.MatchNotPending.selector);
        pairPong.cancelMatch(matchId);
    }

    function test_CancelMatch_RefundsOnlyPlayer1IfPending() public {
        uint256 matchId = createMatch(player1, address(token1), DEFAULT_BET);
        uint256 contractBalanceBefore = address(pairPong).balance;

        cancelMatch(matchId);

        assertEq(address(pairPong).balance, contractBalanceBefore - DEFAULT_BET);
    }

    function test_CancelMatch_RefundsBothPlayersIfActive() public {
        uint256 matchId = createCompleteMatch();
        uint256 contractBalanceBefore = address(pairPong).balance;

        cancelMatch(matchId);

        assertEq(address(pairPong).balance, contractBalanceBefore - (DEFAULT_BET * 2));
    }

    // ============ Edge Cases and Reentrancy Tests ============

    function test_MultiplePlayersCannotJoinSameMatch() public {
        uint256 matchId = createMatch(player1, address(token1), DEFAULT_BET);

        joinMatch(player2, matchId, address(token2), DEFAULT_BET);

        vm.prank(player3);
        vm.expectRevert(IPairPong.MatchNotPending.selector);
        pairPong.joinMatch{value: DEFAULT_BET}(matchId, address(token3));
    }

    function test_CannotFinalizeMatchTwice() public {
        uint256 matchId = createCompleteMatch();
        finalizeMatch(matchId, player1);

        vm.prank(admin);
        vm.expectRevert(IPairPong.MatchNotActive.selector);
        pairPong.finalizeMatch(matchId, player2);
    }

    function test_CannotJoinCanceledMatch() public {
        uint256 matchId = createMatch(player1, address(token1), DEFAULT_BET);
        cancelMatch(matchId);

        vm.prank(player2);
        vm.expectRevert(IPairPong.MatchNotPending.selector);
        pairPong.joinMatch{value: DEFAULT_BET}(matchId, address(token2));
    }

    function test_CannotFinalizeCompletedMatch() public {
        uint256 matchId = createCompleteMatch();
        finalizeMatch(matchId, player1);

        vm.prank(admin);
        vm.expectRevert(IPairPong.MatchNotActive.selector);
        pairPong.finalizeMatch(matchId, player1);
    }

    // ============ Fuzz Tests ============

    function testFuzz_CreateMatch(uint256 betAmount) public {
        vm.assume(betAmount >= MIN_BET && betAmount <= MAX_BET);

        uint256 matchId = createMatch(player1, address(token1), betAmount);

        IPairPong.MatchData memory matchData = pairPong.getMatch(matchId);
        assertEq(matchData.amount, betAmount);
    }

    function testFuzz_JoinMatch(uint256 betAmount) public {
        vm.assume(betAmount >= MIN_BET && betAmount <= MAX_BET);

        uint256 matchId = createMatch(player1, address(token1), betAmount);
        joinMatch(player2, matchId, address(token2), betAmount);

        IPairPong.MatchData memory matchData = pairPong.getMatch(matchId);
        assertEq(uint8(matchData.status), uint8(IPairPong.MatchStatus.Active));
        assertEq(matchData.amount, betAmount);
    }

    function testFuzz_FinalizeMatch(uint256 betAmount, bool player1Wins) public {
        vm.assume(betAmount >= MIN_BET && betAmount <= MAX_BET);

        uint256 matchId = createMatch(player1, address(token1), betAmount);
        joinMatch(player2, matchId, address(token2), betAmount);

        address winner = player1Wins ? player1 : player2;
        uint256 winnerBalanceBefore = winner.balance;

        finalizeMatch(matchId, winner);

        uint256 expectedPayout = calculateWinnerPayout(betAmount * 2);
        assertEq(winner.balance, winnerBalanceBefore + expectedPayout);
    }

    function testFuzz_PlatformFee(uint256 feePercentage) public {
        vm.assume(feePercentage <= 1000); // Max 10%

        vm.prank(owner);
        pairPong.setPlatformFee(feePercentage);

        uint256 matchId = createCompleteMatch();
        finalizeMatch(matchId, player1);

        uint256 totalPool = DEFAULT_BET * 2;
        uint256 expectedFee = (totalPool * feePercentage) / 10000;

        assertEq(pairPong.accumulatedFees(), expectedFee);
    }

    // ============ Gas Optimization Tests ============

    function test_Gas_CreateMatch() public {
        uint256 gasBefore = gasleft();
        createMatch(player1, address(token1), DEFAULT_BET);
        uint256 gasUsed = gasBefore - gasleft();

        // Log gas usage for reference
        emit log_named_uint("Gas used for createMatch", gasUsed);
    }

    function test_Gas_JoinMatch() public {
        uint256 matchId = createMatch(player1, address(token1), DEFAULT_BET);
        
        uint256 gasBefore = gasleft();
        joinMatch(player2, matchId, address(token2), DEFAULT_BET);
        uint256 gasUsed = gasBefore - gasleft();

        emit log_named_uint("Gas used for joinMatch", gasUsed);
    }

    function test_Gas_FinalizeMatch() public {
        uint256 matchId = createCompleteMatch();
        
        uint256 gasBefore = gasleft();
        finalizeMatch(matchId, player1);
        uint256 gasUsed = gasBefore - gasleft();

        emit log_named_uint("Gas used for finalizeMatch", gasUsed);
    }
}