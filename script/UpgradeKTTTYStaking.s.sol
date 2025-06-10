
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {KTTYStaking} from "../src/KTTYStaking.sol";
import {KTTYStakingProxyAdmin} from "../src/KTTYStakingProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract UpgradeKTTYStaking is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");
        address proxyAdminAddress = vm.envAddress("PROXY_ADMIN_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy new implementation
        KTTYStaking newImplementation = new KTTYStaking();
        
        // Get ProxyAdmin instance
        KTTYStakingProxyAdmin proxyAdmin = KTTYStakingProxyAdmin(proxyAdminAddress);

        KTTYStaking proxy = KTTYStaking(proxyAddress);
        proxy.grantRole(proxy.UPGRADER_ROLE(), proxyAdminAddress);
        
        // Upgrade the proxy to the new implementation
        proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(proxyAddress),
            address(newImplementation),
            new bytes(0)
        );
        
        console.log("Upgraded KTTYStaking proxy at: %s", proxyAddress);
        console.log("New implementation deployed at: %s", address(newImplementation));
        
        vm.stopBroadcast();
    }
}