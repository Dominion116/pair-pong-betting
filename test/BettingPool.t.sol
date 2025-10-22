// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BettingPool.sol";
import "../src/Vault.sol";
import "../src/InsureBets.sol";
import "../src/interfaces/IBettingPool.sol";

contract BettingPoolTest is Test {
    Vault vault;
    BettingPool pool;
    InsureBets insure;

    address alice = address(0x1);
    address bob = address(0x2);
    address oracle = address(0x3);
    uint256 matchId = 42;

    function setUp() public {
        vm.deal(address(this), 10 ether);
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);

        // Deploy a Vault with a placeholder bettingPool address
        vault = new Vault(address(1), 5 ether);

        // Deploy BettingPool
        pool = new BettingPool(oracle, address(vault));

        // Link vault -> bettingPool
        vault.setBettingPool(address(pool));

        // Deploy InsureBets and wire into pool
        insure = new InsureBets(address(pool));
        pool.setInsureBetsContract(address(insure));

        // Fund vault so house matching can work if needed
        vm.prank(address(this));
        vault.deposit{value: 5 ether}();
    }

    function test_matchTwoBets_and_settleWinner() public {
        // Oracle approves the match
        vm.prank(oracle);
        pool.approveMatch(matchId, block.timestamp + 1 days);

        // Record starting balances
        uint256 aliceStart = alice.balance;
        uint256 bobStart = bob.balance;

        // Alice places 1 ETH on PlayerA
        vm.prank(alice);
        pool.placeBet{value: 1 ether}(matchId, IBettingPool.BetSide.PlayerA, IBettingPool.InsuranceTier.None);

        // Bob places 1 ETH on PlayerB (should match)
        vm.prank(bob);
        pool.placeBet{value: 1 ether}(matchId, IBettingPool.BetSide.PlayerB, IBettingPool.InsuranceTier.None);

        // Balances after placing
        assertEq(alice.balance, aliceStart - 1 ether);
        assertEq(bob.balance, bobStart - 1 ether);

        // Settle: PlayerA wins
        vm.prank(oracle);
        pool.settleBet(matchId, IBettingPool.BetSide.PlayerA);

        // Compute expected payout:
        // totalPayout = 1 (alice) + 1 (matched) = 2 ETH
        // fee for 2 ETH is 0.5% -> 0.01 ETH
        uint256 expectedTotal = 2 ether;
        uint256 expectedFee = (expectedTotal * 50) / 10000; // FEE_TIER_3 = 50
        uint256 expectedNet = expectedTotal - expectedFee;

        // Alice final balance should be start - 1 + expectedNet
        assertEq(alice.balance, aliceStart - 1 ether + expectedNet);

        // Bob lost his stake, no insurance -> balance should be start - 1
        assertEq(bob.balance, bobStart - 1 ether);

        // Pool balances should have been updated
        assertEq(pool.getPoolBalance(), 0);
    }
}