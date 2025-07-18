// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";

import { SubscriptionModule } from "src/SubscriptionModule.sol";

// forge script --chain gnosis script/DeployModule.s.sol:Deploy --rpc-url gnosis --broadcast --verify -vvv
contract Deploy is Script {
    function run() public returns (SubscriptionModule module) {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        module = new SubscriptionModule();

        vm.stopBroadcast();
    }
}
