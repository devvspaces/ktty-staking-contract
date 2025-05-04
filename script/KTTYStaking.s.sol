// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {KTTYStaking} from "../src/KTTYStaking.sol";

contract KTTYStakingScript is Script {
    KTTYStaking public stakingContract;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // Load values from .env file
        address ktty = vm.envAddress("KTTY_ADDRESS");

        stakingContract = new KTTYStaking(ktty);

        vm.stopBroadcast();
    }
}
