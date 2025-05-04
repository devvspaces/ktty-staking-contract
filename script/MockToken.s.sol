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
        new MockERC20("RON Token", "RON");
        new MockERC20("Kitty Token", "KTTY");

        vm.stopBroadcast();
    }
}