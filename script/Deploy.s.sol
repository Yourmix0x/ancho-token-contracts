// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/AnchoToken.sol";
import "../src/AnchoTimelock.sol";
import "../src/Bridge.sol";
import "../src/Lottery.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // define addresses
        address deployer = vm.addr(deployerPrivateKey);
        address treasury = vm.envOr("TREASURY_ADDRESS", deployer);
        address vault = vm.envOr("VAULT_ADDRESS", deployer);
        address emergencyAdmin = vm.envOr("EMERGENCY_ADMIN", deployer);

        console.log("Deploying with:");
        console.log("Deployer:", deployer);
        console.log("Treasury:", treasury);
        console.log("Vault:", vault);
        console.log("Emergency Admin:", emergencyAdmin);

        // 1. Deploy Timelock
        AnchoTimelock timelock = new AnchoTimelock(deployer);
        console.log("AnchoTimelock deployed:", address(timelock));

        // 2. Deploy Token
        AnchoToken token = new AnchoToken(
            deployer,
            treasury,
            vault,
            emergencyAdmin
        );
        console.log("AnchoToken deployed:", address(token));

        // 3. Deploy Bridge
        Bridge bridge = new Bridge(address(token), deployer);
        console.log("Bridge deployed:", address(bridge));

        // 4. Deploy Lottery (Sepolia VRF configuration)
        // Sepolia
        address vrfCoordinator = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
        bytes32 keyHash = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
        uint64 subscriptionId = uint64(vm.envUint("VRF_SUBSCRIPTION_ID"));

        console.log("VRF Subscription ID:", subscriptionId);

        Lottery lottery = new Lottery(
            vrfCoordinator,
            keyHash,
            subscriptionId,
            address(token),
            vault,
            deployer
        );
        console.log("Lottery deployed:", address(lottery));

        // 5. Setup connections
        token.setTimelock(address(timelock));
        console.log("Timelock connected to token");

        vm.stopBroadcast();

        console.log("\n=== Deployment Complete ===");
        console.log("AnchoToken:", address(token));
        console.log("AnchoTimelock:", address(timelock));
        console.log("Bridge:", address(bridge));
        console.log("Lottery:", address(lottery));
    }
}
