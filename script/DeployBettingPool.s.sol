// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/BettingPool.sol";

contract DeployBettingPool is Script {
    function run() external returns (BettingPool) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address oracle = vm.envAddress("ORACLE_ADDRESS");
        address vault = vm.envAddress("VAULT_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        BettingPool bettingPool = new BettingPool(oracle, vault);

        console.log("BettingPool deployed at:", address(bettingPool));
        console.log("Oracle:", oracle);
        console.log("Vault:", vault);
        console.log("Owner:", bettingPool.owner());

        vm.stopBroadcast();

        return bettingPool;
    }
}

contract DeployBettingPoolLocal is Script {
    function run() external returns (BettingPool) {
        address oracle = vm.envOr("ORACLE_ADDRESS", address(0x1234567890123456789012345678901234567890));
        address vault = vm.envOr("VAULT_ADDRESS", address(0x0987654321098765432109876543210987654321));

        vm.startBroadcast();

        BettingPool bettingPool = new BettingPool(oracle, vault);

        console.log("BettingPool deployed locally at:", address(bettingPool));
        console.log("Oracle:", oracle);
        console.log("Vault:", vault);
        console.log("Owner:", bettingPool.owner());

        vm.stopBroadcast();

        return bettingPool;
    }
}

contract DeployBettingPoolTestnet is Script {
    function run() external returns (BettingPool) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address oracle = vm.envAddress("ORACLE_ADDRESS");
        address vault = vm.envAddress("VAULT_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        BettingPool bettingPool = new BettingPool(oracle, vault);

        console.log("BettingPool deployed to testnet at:", address(bettingPool));
        console.log("Oracle:", oracle);
        console.log("Vault:", vault);
        console.log("Owner:", bettingPool.owner());

        vm.stopBroadcast();

        return bettingPool;
    }
}

contract DeployBettingPoolWithSetup is Script {
    function run() external returns (BettingPool) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address oracle = vm.envAddress("ORACLE_ADDRESS");
        address vault = vm.envAddress("VAULT_ADDRESS");
        address insureBets = vm.envOr("INSURE_BETS_ADDRESS", address(0));

        vm.startBroadcast(deployerPrivateKey);

        BettingPool bettingPool = new BettingPool(oracle, vault);

        // Set insurance contract if provided
        if (insureBets != address(0)) {
            bettingPool.setInsureBetsContract(insureBets);
            console.log("InsureBets contract set:", insureBets);
        }

        console.log("BettingPool deployed at:", address(bettingPool));
        console.log("Oracle:", oracle);
        console.log("Vault:", vault);
        console.log("Owner:", bettingPool.owner());

        vm.stopBroadcast();

        return bettingPool;
    }
}