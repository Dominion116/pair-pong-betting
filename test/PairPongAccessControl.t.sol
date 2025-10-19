// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./PairPong.t.sol";

/**
 * @title PairPongAccessControlTest
 * @notice Tests for admin and owner access control
 */
contract PairPongAccessControlTest is PairPongTest {
    // ============ Admin Tests ============

    function test_SetAdmin() public {
        address newAdmin = makeAddr("newAdmin");

        vm.expectEmit(true, true, false, false);
        emit AdminUpdated(admin, newAdmin);

        vm.prank(owner);
        pairPong.setAdmin(newAdmin);

        assertEq(pairPong.admin(), newAdmin);
    }

    function test_SetAdmin_RevertsIfNotOwner() public {
        address newAdmin = makeAddr("newAdmin");

        vm.prank(player1);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", player1));
        pairPong.setAdmin(newAdmin);
    }

    function test_SetAdmin_RevertsForZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(IPairPong.InvalidAddress.selector);
        pairPong.setAdmin(address(0));
    }

    function test_AdminCanFinalizeMatch() public {
        uint256 matchId = createCompleteMatch();

        vm.prank(admin);
        pairPong.finalizeMatch(matchId, player1);

        IPairPong.Match memory matchData = pairPong.getMatch(matchId);
        assertEq(uint8(matchData.status), uint8(IPairPong.MatchStatus.Completed));
    }

    function test_FinalizeMatch_RevertsIfNotAdmin() public {
        uint256 matchId = createCompleteMatch();

        vm.prank(player1);
        vm.expectRevert(IPairPong.UnauthorizedAccess.selector);
        pairPong.finalizeMatch(matchId, player1);
    }

    function test_AdminCanCancelMatch() public {
        uint256 matchId = createMatch(player1, address(token1), DEFAULT_BET);

        vm.prank(admin);
        pairPong.cancelMatch(matchId);

        IPairPong.Match memory matchData = pairPong.getMatch(matchId);
        assertEq(uint8(matchData.status), uint8(IPairPong.MatchStatus.Canceled));
    }

    function test_CancelMatch_RevertsIfNotAdminOrOwner() public {
        uint256 matchId = createMatch(player1, address(token1), DEFAULT_BET);

        vm.prank(player2);
        vm.expectRevert(IPairPong.UnauthorizedAccess.selector);
        pairPong.cancelMatch(matchId);
    }

    function test_OwnerCanCancelMatch() public {
        uint256 matchId = createMatch(player1, address(token1), DEFAULT_BET);

        vm.prank(owner);
        pairPong.cancelMatch(matchId);

        IPairPong.Match memory matchData = pairPong.getMatch(matchId);
        assertEq(uint8(matchData.status), uint8(IPairPong.MatchStatus.Canceled));
    }

    // ============ Owner Tests ============

    function test_SetPlatformFee() public {
        uint256 newFee = 500; // 5%

        vm.expectEmit(false, false, false, true);
        emit PlatformFeeUpdated(PLATFORM_FEE, newFee);

        vm.prank(owner);
        pairPong.setPlatformFee(newFee);

        assertEq(pairPong.platformFeePercentage(), newFee);
    }

    function test_SetPlatformFee_RevertsIfNotOwner() public {
        vm.prank(player1);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", player1));
        pairPong.setPlatformFee(500);
    }

    function test_SetPlatformFee_RevertsIfTooHigh() public {
        vm.prank(owner);
        vm.expectRevert(IPairPong.InvalidFeePercentage.selector);
        pairPong.setPlatformFee(1001); // > 10%
    }

    function test_SetPlatformFee_AcceptsMaxFee() public {
        vm.prank(owner);
        pairPong.setPlatformFee(1000); // Exactly 10%

        assertEq(pairPong.platformFeePercentage(), 1000);
    }

    function test_WithdrawFees() public {
        // Create and finalize a match to accumulate fees
        uint256 matchId = createCompleteMatch();
        finalizeMatch(matchId, player1);

        uint256 expectedFees = calculatePlatformFee(DEFAULT_BET * 2);
        assertEq(pairPong.accumulatedFees(), expectedFees);

        uint256 recipientBalanceBefore = feeRecipient.balance;

        vm.expectEmit(true, false, false, true);
        emit FeesWithdrawn(feeRecipient, expectedFees);

        vm.prank(owner);
        pairPong.withdrawFees(payable(feeRecipient));

        assertEq(feeRecipient.balance, recipientBalanceBefore + expectedFees);
        assertEq(pairPong.accumulatedFees(), 0);
    }

    function test_WithdrawFees_RevertsIfNotOwner() public {
        vm.prank(player1);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", player1));
        pairPong.withdrawFees(payable(feeRecipient));
    }

    function test_WithdrawFees_RevertsIfNoFees() public {
        vm.prank(owner);
        vm.expectRevert(IPairPong.NoFeesToWithdraw.selector);
        pairPong.withdrawFees(payable(feeRecipient));
    }

    function test_WithdrawFees_RevertsForZeroAddress() public {
        // Accumulate some fees first
        uint256 matchId = createCompleteMatch();
        finalizeMatch(matchId, player1);

        vm.prank(owner);
        vm.expectRevert(IPairPong.InvalidAddress.selector);
        pairPong.withdrawFees(payable(address(0)));
    }

    function test_SetMinBetAmount() public {
        uint256 newMinBet = 0.05 ether;

        vm.prank(owner);
        pairPong.setMinBetAmount(newMinBet);

        assertEq(pairPong.minBetAmount(), newMinBet);
    }

    function test_SetMinBetAmount_RevertsIfNotOwner() public {
        vm.prank(player1);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", player1));
        pairPong.setMinBetAmount(0.05 ether);
    }

    function test_SetMinBetAmount_RevertsIfZero() public {
        vm.prank(owner);
        vm.expectRevert(IPairPong.InvalidBetAmount.selector);
        pairPong.setMinBetAmount(0);
    }

    function test_SetMinBetAmount_RevertsIfGreaterThanMax() public {
        vm.prank(owner);
        vm.expectRevert(IPairPong.InvalidBetAmount.selector);
        pairPong.setMinBetAmount(MAX_BET + 1 ether);
    }

    function test_SetMaxBetAmount() public {
        uint256 newMaxBet = 20 ether;

        vm.prank(owner);
        pairPong.setMaxBetAmount(newMaxBet);

        assertEq(pairPong.maxBetAmount(), newMaxBet);
    }

    function test_SetMaxBetAmount_RevertsIfNotOwner() public {
        vm.prank(player1);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", player1));
        pairPong.setMaxBetAmount(20 ether);
    }

    function test_SetMaxBetAmount_RevertsIfLessThanMin() public {
        vm.prank(owner);
        vm.expectRevert(IPairPong.InvalidBetAmount.selector);
        pairPong.setMaxBetAmount(0.001 ether);
    }

    // ============ Owner Transfer Tests ============

    function test_TransferOwnership() public {
        address newOwner = makeAddr("newOwner");

        vm.prank(owner);
        pairPong.transferOwnership(newOwner);

        vm.prank(newOwner);
        pairPong.acceptOwnership();

        assertEq(pairPong.owner(), newOwner);
    }

    function test_TransferOwnership_RevertsIfNotOwner() public {
        address newOwner = makeAddr("newOwner");

        vm.prank(player1);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", player1));
        pairPong.transferOwnership(newOwner);
    }

    function test_NewOwnerCanPerformOwnerFunctions() public {
        address newOwner = makeAddr("newOwner");

        // Transfer ownership
        vm.prank(owner);
        pairPong.transferOwnership(newOwner);

        vm.prank(newOwner);
        pairPong.acceptOwnership();

        // New owner can set platform fee
        vm.prank(newOwner);
        pairPong.setPlatformFee(300);

        assertEq(pairPong.platformFeePercentage(), 300);
    }

    function test_OldOwnerCannotPerformOwnerFunctionsAfterTransfer() public {
        address newOwner = makeAddr("newOwner");

        vm.prank(owner);
        pairPong.transferOwnership(newOwner);

        vm.prank(newOwner);
        pairPong.acceptOwnership();

        // Old owner cannot set platform fee
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", owner));
        pairPong.setPlatformFee(300);
    }

    // ============ Multiple Fee Withdrawals ============

    function test_WithdrawFees_MultipleTimes() public {
        // First match
        uint256 match1 = createCompleteMatch();
        finalizeMatch(match1, player1);

        uint256 fees1 = pairPong.accumulatedFees();

        vm.prank(owner);
        pairPong.withdrawFees(payable(feeRecipient));

        assertEq(pairPong.accumulatedFees(), 0);

        // Second match
        uint256 match2 = createCompleteMatch();
        finalizeMatch(match2, player2);

        uint256 fees2 = pairPong.accumulatedFees();

        vm.prank(owner);
        pairPong.withdrawFees(payable(feeRecipient));

        assertEq(pairPong.accumulatedFees(), 0);

        // Verify total fees withdrawn
        uint256 totalFees = fees1 + fees2;
        uint256 expectedTotalFees = calculatePlatformFee(DEFAULT_BET * 2) * 2;
        assertEq(totalFees, expectedTotalFees);
    }

    // ============ Admin and Owner Overlap ============

    function test_AdminCannotPerformOwnerFunctions() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", admin));
        pairPong.setPlatformFee(300);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", admin));
        pairPong.setAdmin(player1);
    }

    function test_OwnerAndAdminCanBothCancelMatches() public {
        uint256 match1 = createMatch(player1, address(token1), DEFAULT_BET);
        uint256 match2 = createMatch(player2, address(token2), DEFAULT_BET);

        // Admin cancels match1
        vm.prank(admin);
        pairPong.cancelMatch(match1);

        // Owner cancels match2
        vm.prank(owner);
        pairPong.cancelMatch(match2);

        IPairPong.Match memory matchData1 = pairPong.getMatch(match1);
        IPairPong.Match memory matchData2 = pairPong.getMatch(match2);

        assertEq(uint8(matchData1.status), uint8(IPairPong.MatchStatus.Canceled));
        assertEq(uint8(matchData2.status), uint8(IPairPong.MatchStatus.Canceled));
    }
}