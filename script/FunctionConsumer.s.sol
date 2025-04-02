// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/FunctionConsumer.sol";

contract DeployAPIConsumer is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address router = vm.envAddress("CHAINLINK_ROUTER");
        bytes32 donId = vm.envBytes32("CHAINLINK_DON_ID");
        uint64 subscriptionId = uint64(vm.envUint("CHAINLINK_SUBSCRIPTION_ID"));

        vm.startBroadcast(deployerPrivateKey);
        APIConsumer apiConsumer = new APIConsumer(router, donId, subscriptionId);
        vm.stopBroadcast();

        console.log("Deployed APIConsumer at:", address(apiConsumer));
    }
}
