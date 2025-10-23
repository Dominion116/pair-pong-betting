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
    uint256 betId = 7;
    address user = address(0xBEEF);
    uint256 matchId = 11;
    uint256 insuredAmount = 1 ether;

    // If Bronze = 3% in your contract logic
    uint256 premiumPaid = (insuredAmount * 300) / 10000;

    // ✅ Use the enum type, not uint8
    IInsureBet.InsuranceTier tier = IInsureBet.InsuranceTier.Bronze;

    // Ensure reserves available
    insure.replenishReserves{value: 3 ether}();
    assertEq(insure.getReserves(), 3 ether);

    // If registerInsurance requires msg.value == premium, add {value: premiumPaid}
    // insure.registerInsurance{value: premiumPaid}(betId, user, matchId, insuredAmount, premiumPaid, tier);
    insure.registerInsurance(betId, user, matchId, insuredAmount, premiumPaid, tier);

    uint256 payout = insure.processClaim(betId);

    assertTrue(payout <= insuredAmount);
    assertTrue(payout <= 3 ether);
    assertEq(insure.getReserves(), 3 ether - payout);
}

}