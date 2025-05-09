// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {KTTYStaking} from "../src/KTTYStaking.sol";
import {KTTYStakingProxyAdmin} from "../src/KTTYStakingProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";


contract DeployKTTYStakingUpgradeable is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address kttyTokenAddress = vm.envAddress("KTTY_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy implementation contract
        KTTYStaking implementation = new KTTYStaking();
        
        // Deploy ProxyAdmin
        KTTYStakingProxyAdmin proxyAdmin = new KTTYStakingProxyAdmin(
            vm.addr(deployerPrivateKey)
        );
        
        // Prepare the initialization data
        bytes memory initData = abi.encodeWithSelector(
            KTTYStaking.initialize.selector,
            kttyTokenAddress
        );
        
        // Deploy the proxy, pointing to the implementation and using the proxy admin for ownership
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation),
            address(proxyAdmin),
            initData
        );
        
        // Log the addresses
        console.log("KTTYStaking Implementation deployed at: %s", address(implementation));
        console.log("KTTYStakingProxyAdmin deployed at: %s", address(proxyAdmin));
        console.log("TransparentUpgradeableProxy deployed at: %s", address(proxy));
        console.log("KTTYStaking (proxy) is accessible at: %s", address(proxy));
        
        vm.stopBroadcast();
    }
}
