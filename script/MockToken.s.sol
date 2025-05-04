// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MockERC20} from "../src/MockERC.sol";

contract RoninNFTScript is Script {
    MockERC20 public ron;
    MockERC20 public nativeToken;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // Deploy mock tokens
        new MockERC20("Kitty Token", "KTTY");
        new MockERC20("Zee Token", "ZEE");
        new MockERC20("Kev AI Token", "KEV-AI");
        new MockERC20("Real Token", "REAL");
        new MockERC20("Paw Token", "PAW");

        vm.stopBroadcast();
    }
}