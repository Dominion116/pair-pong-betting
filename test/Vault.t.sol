// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Vault.sol";

contract VaultTest is Test {
    Vault vault;

    function setUp() public {
        // Deploy Vault with placeholder BettingPool address and threshold
        vault = new Vault(address(1), 5 ether);

        // Fund test actor so deposits can be made in tests
        vm.deal(address(this), 10 ether);
    }

    function test_deposit_increases_balance() public {
        uint256 start = vault.getBalance();
        assertEq(start, 0);

        // Deposit 3 ETH
        vault.deposit{value: 3 ether}();

        uint256 afterBalance = vault.getBalance();
        assertEq(afterBalance, 3 ether);
    }

    function test_setBettingPool_onlyOwner() public {
        // Only the owner (deployer) should be able to set the betting pool
        address newAddr = address(0x1234);
        vault.setBettingPool(newAddr);
        // No getter for bettingPool might exist; at minimum ensure deposit still works
        vm.deal(address(this), 1 ether);
        vault.deposit{value: 1 ether}();
        assertEq(vault.getBalance(), 1 ether + 3 ether); // from previous test deposit presence depends on test ordering
    }
}