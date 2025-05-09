// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

/**
 * @title KTTYStakingProxyAdmin
 * @dev ProxyAdmin specifically for KTTYStaking contract
 */
contract KTTYStakingProxyAdmin is ProxyAdmin {
    constructor(address owner) ProxyAdmin(owner) {
    }
}
