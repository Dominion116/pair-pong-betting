// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Vault.sol";

contract DeployVault is Script {
    function run() external returns (Vault) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address bettingPool = vm.envAddress("BETTING_POOL_ADDRESS");
        uint256 initialReserveThreshold = vm.envUint("INITIAL_RESERVE_THRESHOLD");
        if(initialReserveThreshold == 0) {
            initialReserveThreshold = 5 ether;
        }

        vm.startBroadcast(deployerPrivateKey);

        Vault vault = new Vault(bettingPool, initialReserveThreshold);

        console.log("Vault deployed at:", address(vault));
        console.log("BettingPool:", bettingPool);
        console.log("Reserve Threshold:", initialReserveThreshold);

        vm.stopBroadcast();

        return vault;
    }
}

contract DeployVaultLocal is Script {
    function run() external returns (Vault) {
        // For local deployment, use placeholder address that will be updated
        address placeholderBettingPool = address(1);
        uint256 initialReserveThreshold = 5 ether;

        vm.startBroadcast();

        Vault vault = new Vault(placeholderBettingPool, initialReserveThreshold);

        console.log("Vault deployed at:", address(vault));
        console.log("BettingPool (placeholder):", placeholderBettingPool);
        console.log("Reserve Threshold:", initialReserveThreshold);
        console.log("NOTE: Update BettingPool address after deployment");

        vm.stopBroadcast();

        return vault;
    }
}

contract DeployVaultTestnet is Script {
    function run() external returns (Vault) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address bettingPool = vm.envOr("BETTING_POOL_ADDRESS", address(1));
        uint256 initialReserveThreshold = 5 ether;

        vm.startBroadcast(deployerPrivateKey);

        Vault vault = new Vault(bettingPool, initialReserveThreshold);

        console.log("Vault deployed to testnet at:", address(vault));
        console.log("BettingPool:", bettingPool);
        console.log("Reserve Threshold:", initialReserveThreshold);

        vm.stopBroadcast();

        return vault;
    }
}