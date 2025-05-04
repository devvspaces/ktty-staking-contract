// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {KTTYStaking} from "../src/KTTYStaking.sol";

contract KTTYStakingScript is Script {
    KTTYStaking public stakingContract;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        stakingContract = new KTTYStaking(address(0));

        vm.stopBroadcast();
    }
}
