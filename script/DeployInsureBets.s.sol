// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/InsureBets.sol";

contract DeployInsureBets is Script {
    function run() external returns (InsureBets) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address bettingPool = vm.envAddress("BETTING_POOL_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        InsureBets insureBets = new InsureBets(bettingPool);

        console.log("InsureBets deployed at:", address(insureBets));
        console.log("BettingPool:", bettingPool);
        console.log("Owner:", insureBets.owner());
        
        // Log tier configurations
        IInsureBet.TierConfig memory bronze = insureBets.getTierConfig(IInsureBet.InsuranceTier.Bronze);
        IInsureBet.TierConfig memory silver = insureBets.getTierConfig(IInsureBet.InsuranceTier.Silver);
        IInsureBet.TierConfig memory gold = insureBets.getTierConfig(IInsureBet.InsuranceTier.Gold);
        
        console.log("Bronze - Premium: %s bps, Payout: %s bps", bronze.premiumPercentage, bronze.payoutPercentage);
        console.log("Silver - Premium: %s bps, Payout: %s bps", silver.premiumPercentage, silver.payoutPercentage);
        console.log("Gold - Premium: %s bps, Payout: %s bps", gold.premiumPercentage, gold.payoutPercentage);

        vm.stopBroadcast();

        return insureBets;
    }
}

contract DeployInsureBetsLocal is Script {
    function run() external returns (InsureBets) {
        address bettingPool = vm.envOr("BETTING_POOL_ADDRESS", address(0x1111111111111111111111111111111111111111));

        vm.startBroadcast();

        InsureBets insureBets = new InsureBets(bettingPool);

        console.log("InsureBets deployed locally at:", address(insureBets));
        console.log("BettingPool:", bettingPool);
        console.log("Owner:", insureBets.owner());

        vm.stopBroadcast();

        return insureBets;
    }
}

contract DeployInsureBetsTestnet is Script {
    function run() external returns (InsureBets) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address bettingPool = vm.envAddress("BETTING_POOL_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        InsureBets insureBets = new InsureBets(bettingPool);

        console.log("InsureBets deployed to testnet at:", address(insureBets));
        console.log("BettingPool:", bettingPool);
        console.log("Owner:", insureBets.owner());

        vm.stopBroadcast();

        return insureBets;
    }
}

contract DeployInsureBetsWithFunding is Script {
    function run() external returns (InsureBets) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address bettingPool = vm.envAddress("BETTING_POOL_ADDRESS");
        uint256 initialFunding = vm.envUint("INITIAL_INSURANCE_FUNDING");
        if(initialFunding == 0) {
            initialFunding = 10 ether;
        }

        vm.startBroadcast(deployerPrivateKey);

        InsureBets insureBets = new InsureBets(bettingPool);

        // Fund the insurance pool
        if (initialFunding > 0) {
            insureBets.replenishReserves{value: initialFunding}();
            console.log("Insurance pool funded with:", initialFunding);
        }

        console.log("InsureBets deployed at:", address(insureBets));
        console.log("BettingPool:", bettingPool);
        console.log("Owner:", insureBets.owner());
        console.log("Initial Reserves:", insureBets.getReserves());

        vm.stopBroadcast();

        return insureBets;
    }
}