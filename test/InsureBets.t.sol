// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/InsureBets.sol";
import "../src/interfaces/IInsureBet.sol";

contract InsureBetsTest is Test {
    InsureBets insure;

    function setUp() public {
        // Deploy InsureBets with this test contract as the betting pool address
        // so we can call restricted functions directly for testing.
        insure = new InsureBets(address(this));
        vm.deal(address(this), 10 ether);
    }

    function test_replenish_reserves_and_getReserves() public {
        assertEq(insure.getReserves(), 0);

        insure.replenishReserves{value: 5 ether}();
        assertEq(insure.getReserves(), 5 ether);

        insure.replenishReserves{value: 2 ether}();
        assertEq(insure.getReserves(), 7 ether);
    }

    function test_register_and_processClaim_flow() public {
        // Prepare dummy insurance registration args
        uint256 betId = 7;
        address user = address(0xBEEF);
        uint256 matchId = 11;
        uint256 insuredAmount = 1 ether;
        uint256 premiumPaid = (insuredAmount * 300) / 10000; // sample 3% premium (bronze)
        uint8 tier = uint8(IInsureBet.InsuranceTier.Bronze);

        // Ensure reserves available
        insure.replenishReserves{value: 3 ether}();
        assertEq(insure.getReserves(), 3 ether);

        // Call registerInsurance (allowed because this contract was set as bettingPool during deploy)
        insure.registerInsurance(betId, user, matchId, insuredAmount, premiumPaid, tier);

        // processClaim should be callable by betting pool (this contract)
        uint256 payout = insure.processClaim(betId);

        // payout should be <= insuredAmount and <= reserves
        assertTrue(payout <= insuredAmount);
        assertTrue(payout <= 3 ether);

        // reserves should be reduced by payout
        assertEq(insure.getReserves(), 3 ether - payout);
    }
}