// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Vault.sol";
import "../src/BettingPool.sol";
import "../src/InsureBets.sol";

/**
 * @title DeployAll
 * @notice Deploys entire betting system with proper linking
 */
contract DeployAll is Script {
    function run() external returns (Vault vault, BettingPool bettingPool, InsureBets insureBets) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address oracle = vm.envAddress("ORACLE_ADDRESS");
        uint256 initialReserveThreshold = vm.envUint("INITIAL_RESERVE_THRESHOLD");
        if (initialReserveThreshold == 0) {
            initialReserveThreshold = 5 ether;
        }

        uint256 initialInsuranceFunding = vm.envUint("INITIAL_INSURANCE_FUNDING");
        if (initialInsuranceFunding == 0) {
            initialInsuranceFunding = 10 ether;
        }

        uint256 initialVaultFunding = vm.envUint("INITIAL_VAULT_FUNDING");
        if (initialVaultFunding == 0) {
            initialVaultFunding = 20 ether;
        }

        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Deploy Vault with placeholder
        console.log("\n=== Step 1: Deploying Vault ===");
        vault = new Vault(address(1), initialReserveThreshold);
        console.log("Vault deployed at:", address(vault));

        // Step 2: Deploy BettingPool
        console.log("\n=== Step 2: Deploying BettingPool ===");
        bettingPool = new BettingPool(oracle, address(vault));
        console.log("BettingPool deployed at:", address(bettingPool));
        console.log("Oracle:", oracle);

        // Step 3: Update Vault with BettingPool address
        console.log("\n=== Step 3: Linking Vault to BettingPool ===");
        vault.setBettingPool(address(bettingPool));
        console.log("Vault linked to BettingPool");

        // Step 4: Deploy InsureBets
        console.log("\n=== Step 4: Deploying InsureBets ===");
        insureBets = new InsureBets(address(bettingPool));
        console.log("InsureBets deployed at:", address(insureBets));

        // Step 5: Link InsureBets to BettingPool
        console.log("\n=== Step 5: Linking InsureBets to BettingPool ===");
        bettingPool.setInsureBetsContract(address(insureBets));
        console.log("InsureBets linked to BettingPool");

        // Step 6: Fund contracts
        console.log("\n=== Step 6: Funding Contracts ===");
        if (initialVaultFunding > 0) {
            vault.deposit{value: initialVaultFunding}();
            console.log("Vault funded with:", initialVaultFunding);
        }
        
        if (initialInsuranceFunding > 0) {
            insureBets.replenishReserves{value: initialInsuranceFunding}();
            console.log("Insurance pool funded with:", initialInsuranceFunding);
        }

        // Final summary
        console.log("\n=== Deployment Summary ===");
        console.log("Vault:", address(vault));
        console.log("BettingPool:", address(bettingPool));
        console.log("InsureBets:", address(insureBets));
        console.log("Oracle:", oracle);
        console.log("Vault Balance:", vault.getBalance());
        console.log("Insurance Reserves:", insureBets.getReserves());
        console.log("Owner:", bettingPool.owner());

        vm.stopBroadcast();

        return (vault, bettingPool, insureBets);
    }
}

contract DeployAllLocal is Script {
    function run() external returns (Vault vault, BettingPool bettingPool, InsureBets insureBets) {
        // Use default test account as oracle
        address oracle = 0x1234567890123456789012345678901234567890;
        uint256 initialReserveThreshold = 5 ether;

        vm.startBroadcast();

        // Deploy Vault
        console.log("\n=== Deploying Vault ===");
        vault = new Vault(address(1), initialReserveThreshold);
        console.log("Vault:", address(vault));

        // Deploy BettingPool
        console.log("\n=== Deploying BettingPool ===");
        bettingPool = new BettingPool(oracle, address(vault));
        console.log("BettingPool:", address(bettingPool));

        // Link Vault to BettingPool
        vault.setBettingPool(address(bettingPool));

        // Deploy InsureBets
        console.log("\n=== Deploying InsureBets ===");
        insureBets = new InsureBets(address(bettingPool));
        console.log("InsureBets:", address(insureBets));

        // Link InsureBets to BettingPool
        bettingPool.setInsureBetsContract(address(insureBets));

        // Fund with test amounts
        vault.deposit{value: 10 ether}();
        insureBets.replenishReserves{value: 5 ether}();

        console.log("\n=== Local Deployment Complete ===");
        console.log("Vault Balance:", vault.getBalance());
        console.log("Insurance Reserves:", insureBets.getReserves());

        vm.stopBroadcast();

        return (vault, bettingPool, insureBets);
    }
}

contract DeployAllTestnet is Script {
    function run() external returns (Vault vault, BettingPool bettingPool, InsureBets insureBets) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address oracle = vm.envAddress("ORACLE_ADDRESS");
        uint256 initialReserveThreshold = 5 ether;
        uint256 initialInsuranceFunding = 2 ether;
        uint256 initialVaultFunding = 3 ether;

        vm.startBroadcast(deployerPrivateKey);

        console.log("\n=== Deploying to Testnet ===");

        // Deploy Vault
        vault = new Vault(address(1), initialReserveThreshold);
        console.log("Vault deployed:", address(vault));

        // Deploy BettingPool
        bettingPool = new BettingPool(oracle, address(vault));
        console.log("BettingPool deployed:", address(bettingPool));

        // Link Vault
        vault.setBettingPool(address(bettingPool));

        // Deploy InsureBets
        insureBets = new InsureBets(address(bettingPool));
        console.log("InsureBets deployed:", address(insureBets));

        // Link InsureBets
        bettingPool.setInsureBetsContract(address(insureBets));

        // Fund contracts
        vault.deposit{value: initialVaultFunding}();
        insureBets.replenishReserves{value: initialInsuranceFunding}();

        console.log("\n=== Testnet Deployment Complete ===");
        console.log("Save these addresses:");
        console.log("VAULT_ADDRESS=%s", address(vault));
        console.log("BETTING_POOL_ADDRESS=%s", address(bettingPool));
        console.log("INSURE_BETS_ADDRESS=%s", address(insureBets));
        console.log("ORACLE_ADDRESS=%s", oracle);

        vm.stopBroadcast();

        return (vault, bettingPool, insureBets);
    }
}