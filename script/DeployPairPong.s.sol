// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/src/Script.sol";
import "../src/PairPong.sol";

/**
 * @title DeployPairPong
 * @notice Deployment script for PairPong betting contract
 * @dev Run with: forge script script/DeployPairPong.s.sol --rpc-url <RPC_URL> --broadcast --verify
 */
contract DeployPairPong is Script {
    // ============ Configuration ============

    // Default values for deployment
    uint256 public constant DEFAULT_PLATFORM_FEE = 200; // 2% in basis points
    uint256 public constant DEFAULT_MIN_BET = 0.001 ether; // 0.001 ETH
    uint256 public constant DEFAULT_MAX_BET = 10 ether; // 10 ETH

    function run() external returns (PairPong) {
        // Load private key from environment variable
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Load admin address (or use deployer as default)
        address admin = vm.envOr("ADMIN_ADDRESS", deployer);

        // Load optional configuration from environment
        uint256 platformFee = vm.envOr("PLATFORM_FEE", DEFAULT_PLATFORM_FEE);
        uint256 minBet = vm.envOr("MIN_BET_AMOUNT", DEFAULT_MIN_BET);
        uint256 maxBet = vm.envOr("MAX_BET_AMOUNT", DEFAULT_MAX_BET);

        console.log("========================================");
        console.log("Deploying PairPong Contract");
        console.log("========================================");
        console.log("Deployer:", deployer);
        console.log("Admin:", admin);
        console.log("Platform Fee:", platformFee, "basis points");
        console.log("Min Bet Amount:", minBet, "wei");
        console.log("Max Bet Amount:", maxBet, "wei");
        console.log("========================================");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy PairPong contract
        PairPong pairPong = new PairPong(admin, platformFee, minBet, maxBet);

        vm.stopBroadcast();

        console.log("PairPong deployed at:", address(pairPong));
        console.log("========================================");
        console.log("Deployment successful!");
        console.log("========================================");

        // Verification commands
        console.log("\nTo verify on Etherscan, run:");
        console.log(
            string.concat(
                "forge verify-contract ",
                vm.toString(address(pairPong)),
                " src/PairPong.sol:PairPong --chain <CHAIN_ID> --constructor-args $(cast abi-encode \"constructor(address,uint256,uint256,uint256)\" ",
                vm.toString(admin),
                " ",
                vm.toString(platformFee),
                " ",
                vm.toString(minBet),
                " ",
                vm.toString(maxBet),
                ")"
            )
        );

        return pairPong;
    }
}

/**
 * @title DeployPairPongLocal
 * @notice Deployment script for local testing (Anvil)
 * @dev Run with: forge script script/DeployPairPong.s.sol:DeployPairPongLocal --rpc-url http://localhost:8545 --broadcast
 */
contract DeployPairPongLocal is Script {
    function run() external returns (PairPong) {
        // Use default Anvil account
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address deployer = vm.addr(deployerPrivateKey);
        address admin = deployer;

        console.log("========================================");
        console.log("Deploying PairPong (LOCAL)");
        console.log("========================================");
        console.log("Deployer:", deployer);
        console.log("Admin:", admin);
        console.log("========================================");

        vm.startBroadcast(deployerPrivateKey);

        PairPong pairPong = new PairPong(
            admin,
            200, // 2% fee
            0.001 ether, // min bet
            10 ether // max bet
        );

        vm.stopBroadcast();

        console.log("PairPong deployed at:", address(pairPong));
        console.log("========================================");

        return pairPong;
    }
}

/**
 * @title DeployPairPongTestnet
 * @notice Deployment script for testnet (Sepolia, Goerli, etc.)
 * @dev Run with: forge script script/DeployPairPong.s.sol:DeployPairPongTestnet --rpc-url <TESTNET_RPC> --broadcast --verify
 */
contract DeployPairPongTestnet is Script {
    function run() external returns (PairPong) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address admin = vm.envOr("ADMIN_ADDRESS", deployer);

        console.log("========================================");
        console.log("Deploying PairPong (TESTNET)");
        console.log("========================================");
        console.log("Deployer:", deployer);
        console.log("Admin:", admin);
        console.log("========================================");

        vm.startBroadcast(deployerPrivateKey);

        PairPong pairPong = new PairPong(
            admin,
            200, // 2% fee
            0.0001 ether, // Lower min bet for testing
            1 ether // Lower max bet for testing
        );

        vm.stopBroadcast();

        console.log("PairPong deployed at:", address(pairPong));
        console.log("========================================");

        return pairPong;
    }
}