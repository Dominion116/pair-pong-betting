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

        // ... place bets ...
        vm.prank(alice);
        pool.placeBet{value: 1 ether}(
            matchId,
            IBettingPool.BetSide.PlayerA,
            IBettingPool.InsuranceTier.None
        );

        vm.prank(bob);
        pool.placeBet{value: 1 ether}(
            matchId,
            IBettingPool.BetSide.PlayerB,
            IBettingPool.InsuranceTier.None
        );

        // Advance time to after the approved start time
        vm.warp(block.timestamp + 1 days + 1);

        // Settle: PlayerA wins
        vm.prank(oracle);
        pool.settleBet(matchId, IBettingPool.BetSide.PlayerA);

        // ... assertions ...
    }
}
