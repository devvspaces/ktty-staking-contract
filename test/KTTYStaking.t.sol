// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {KTTYStaking} from "../src/KTTYStaking.sol";
import {KTTYStakingProxyAdmin} from "../src/KTTYStakingProxyAdmin.sol";
import {TransparentUpgradeableProxy, ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MockERC20} from "../src/MockERC.sol";

contract KTTYStakingUpgradeableTest is Test {
    KTTYStaking implementation;
    KTTYStaking proxy;
    KTTYStakingProxyAdmin proxyAdmin;
    TransparentUpgradeableProxy transparentProxy;
    MockERC20 kttyToken;
    MockERC20 rewardToken1;
    MockERC20 rewardToken2;
    
    address admin = address(1);
    address user1 = address(2);
    address user2 = address(3);
    address emergencyAdmin = address(4);
    address tierManager = address(5);
    address fundManager = address(6);
    
    uint256 initialSupply = 1_000_000 * 1e18;
    
    function setUp() public {
        // Deploy mock tokens and mint some tokens
        kttyToken = new MockERC20("Kitty Token", "KTTY");
        rewardToken1 = new MockERC20("Reward Token 1", "RWD1");
        rewardToken2 = new MockERC20("Reward Token 2", "RWD2");
        
        // Mint tokens to various addresses
        kttyToken.mint(admin, initialSupply);
        kttyToken.mint(user1, initialSupply);
        kttyToken.mint(user2, initialSupply);
        
        rewardToken1.mint(admin, initialSupply);
        rewardToken2.mint(admin, initialSupply);
        
        vm.startPrank(admin);
        
        // Deploy implementation
        implementation = new KTTYStaking();
        
        // Deploy proxy admin
        proxyAdmin = new KTTYStakingProxyAdmin(admin);
        
        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            KTTYStaking.initialize.selector,
            address(kttyToken)
        );
        
        // Deploy proxy
        transparentProxy = new TransparentUpgradeableProxy(
            address(implementation),
            address(proxyAdmin),
            initData
        );
        
        // Deploy UUPS proxy
        // ERC1967Proxy uupsProxy = new ERC1967Proxy(
        //     address(implementation),
        //     initData
        // );
        
        // Create a proxy instance for easy interaction
        proxy = KTTYStaking(address(transparentProxy));
        // proxy = KTTYStaking(address(uupsProxy));
        
        // Setup roles
        proxy.grantRole(proxy.EMERGENCY_ROLE(), emergencyAdmin);
        proxy.grantRole(proxy.TIER_MANAGER_ROLE(), tierManager);
        proxy.grantRole(proxy.FUND_MANAGER_ROLE(), fundManager);
        proxy.grantRole(proxy.UPGRADER_ROLE(), address(proxyAdmin));
        
        // Transfer some reward tokens to the contract
        rewardToken1.transfer(address(proxy), 10_000 * 1e18);
        rewardToken2.transfer(address(proxy), 10_000 * 1e18);
        kttyToken.transfer(address(proxy), 10_000 * 1e18);
        
        vm.stopPrank();
    }
    
    function test_ProxyInitialization() public {
        assertEq(address(proxy.kttyToken()), address(kttyToken));
        assertTrue(proxy.hasRole(proxy.ADMIN_ROLE(), admin));
        assertTrue(proxy.hasRole(proxy.TIER_MANAGER_ROLE(), admin));
        assertTrue(proxy.hasRole(proxy.TIER_MANAGER_ROLE(), tierManager));
        assertTrue(proxy.hasRole(proxy.FUND_MANAGER_ROLE(), admin));
        assertTrue(proxy.hasRole(proxy.FUND_MANAGER_ROLE(), fundManager));
        assertTrue(proxy.hasRole(proxy.EMERGENCY_ROLE(), admin));
        assertTrue(proxy.hasRole(proxy.EMERGENCY_ROLE(), emergencyAdmin));
        assertTrue(proxy.hasRole(proxy.UPGRADER_ROLE(), admin));
    }
    
    function test_AddTier() public {
        vm.startPrank(tierManager);
        
        // Add a tier
        proxy.addTier("Bronze", 100 * 1e18, 1000 * 1e18, 30, 50000); // 5% APY
        
        // Check if tier was added correctly
        (uint256 id, string memory name, uint256 minStake, uint256 maxStake, uint256 lockupPeriod, uint256 apy, bool isActive ) = proxy.tiers(1);
        
        assertEq(id, 1);
        assertEq(name, "Bronze");
        assertEq(minStake, 100 * 1e18);
        assertEq(maxStake, 1000 * 1e18);
        assertEq(lockupPeriod, 30 days);
        assertEq(apy, 50000);
        assertTrue(isActive);
        
        vm.stopPrank();
    }
    
    function test_AddMultipleTiers() public {
        vm.startPrank(tierManager);
        
        // Add multiple tiers
        proxy.addTier("Bronze", 100 * 1e18, 1000 * 1e18, 30, 50000); // 5% APY
        proxy.addTier("Silver", 1000 * 1e18, 5000 * 1e18, 60, 80000); // 8% APY
        proxy.addTier("Gold", 5000 * 1e18, 0, 90, 120000); // 12% APY, no max
        
        assertEq(proxy.getTierCount(), 3);
        
        vm.stopPrank();
    }
    
    function test_UpdateTier() public {
        vm.startPrank(tierManager);
        
        // Add a tier
        proxy.addTier("Bronze", 100 * 1e18, 1000 * 1e18, 30, 50000);
        
        // Update the tier
        proxy.updateTier(1, "Bronze Plus", 150 * 1e18, 1500 * 1e18, 45, 60000, true);
        
        // Check if tier was updated correctly
        (uint256 id, string memory name, uint256 minStake, uint256 maxStake, uint256 lockupPeriod, uint256 apy, bool isActive ) = proxy.tiers(1);
        
        assertEq(id, 1);
        assertEq(name, "Bronze Plus");
        assertEq(minStake, 150 * 1e18);
        assertEq(maxStake, 1500 * 1e18);
        assertEq(lockupPeriod, 45 days);
        assertEq(apy, 60000);
        assertTrue(isActive);
        
        vm.stopPrank();
    }
    
    function test_RegisterRewardToken() public {
        vm.startPrank(fundManager);
        
        // Register reward tokens
        proxy.registerRewardToken(address(rewardToken1), "RWD1", 500000); // 50% of KTTY reward rate
        proxy.registerRewardToken(address(rewardToken2), "RWD2", 250000); // 25% of KTTY reward rate
        
        assertEq(proxy.getRewardTokenCount(), 2);
        
        vm.stopPrank();
    }
    
    function test_AddRewardTokenToTier() public {
        vm.startPrank(tierManager);
        
        // Add a tier
        proxy.addTier("Bronze", 100 * 1e18, 1000 * 1e18, 30, 50000);
        
        vm.stopPrank();
        
        vm.startPrank(fundManager);
        
        // Register reward token
        proxy.registerRewardToken(address(rewardToken1), "RWD1", 500000);
        
        vm.stopPrank();
        
        vm.startPrank(tierManager);
        
        // Add reward token to tier
        proxy.addRewardTokenToTier(1, address(rewardToken1));
        
        // Check if reward token was added to tier
        address[] memory tierRewardTokens = proxy.getTierRewardTokens(1);
        assertEq(tierRewardTokens.length, 1);
        assertEq(tierRewardTokens[0], address(rewardToken1));
        
        vm.stopPrank();
    }
    
    function test_StakeAndWithdraw() public {
        vm.startPrank(tierManager);
        
        // Add a tier
        proxy.addTier("Bronze", 100 * 1e18, 1000 * 1e18, 30, 50000); // 0.5% APY
        
        vm.stopPrank();
        
        vm.startPrank(user1);
        
        // Approve tokens for staking
        uint256 stakeAmount = 200 * 1e18;
        kttyToken.approve(address(proxy), stakeAmount);

        uint256 oldBalance = kttyToken.balanceOf(user1);
        
        // Stake tokens
        proxy.stake(stakeAmount, 1);
        
        // Check user's stake
        uint256[] memory userStakes = proxy.getUserStakes(user1);
        assertEq(userStakes.length, 1);
        assertEq(userStakes[0], 1);
        
        // Get stake details
        (uint256 id, address owner, uint256 amount, uint256 tierId, uint256 startTime, uint256 endTime, bool hasWithdrawn, bool hasClaimedRewards) = proxy.getStake(1);
        
        assertEq(id, 1);
        assertEq(owner, user1);
        assertEq(amount, stakeAmount);
        assertEq(tierId, 1);
        assertGt(startTime, 0);
        assertEq(endTime, startTime + 30 days);
        assertFalse(hasWithdrawn);
        assertFalse(hasClaimedRewards);
        
        // Fast forward time past lockup period
        vm.warp(block.timestamp + 31 days);
        
        // Withdraw stake
        proxy.withdraw(1);
        
        // Check that stake is marked as withdrawn
        (, , , , , , hasWithdrawn, ) = proxy.getStake(1);
        assertTrue(hasWithdrawn);

        uint256 newBalance = kttyToken.balanceOf(user1);
        assertEq(newBalance, oldBalance);
        
        vm.stopPrank();
    }
    
    function test_ClaimRewardsAndWithdraw() public {
        vm.startPrank(tierManager);
        
        // Add a tier
        proxy.addTier("Bronze", 100 * 1e18, 1000 * 1e18, 30, 50000); // 5% APY
        
        vm.stopPrank();
        
        vm.startPrank(fundManager);
        
        // Register reward token and add it to the tier
        proxy.registerRewardToken(address(rewardToken1), "RWD1", 500000);
        
        vm.stopPrank();
        
        vm.startPrank(tierManager);
        
        // Add reward token to tier
        proxy.addRewardTokenToTier(1, address(rewardToken1));
        
        vm.stopPrank();
        
        vm.startPrank(user1);
        
        // Approve tokens for staking
        uint256 stakeAmount = 200 * 1e18;
        kttyToken.approve(address(proxy), stakeAmount);
        
        // Stake tokens
        proxy.stake(stakeAmount, 1);
        
        // Fast forward time past lockup period
        vm.warp(block.timestamp + 31 days);
        
        // Check reward calculation
        uint256 expectedKttyReward = ((stakeAmount * 50000) / 1e6) / 100; // 5% APY
        assertEq(proxy.calculateReward(1, address(0)), expectedKttyReward);
        
        uint256 expectedRwd1Reward = ((stakeAmount * 50000) / 1e6) / 100; // Same formula as in the contract
        assertEq(proxy.calculateReward(1, address(rewardToken1)), expectedRwd1Reward);
        
        // Get balance before claiming
        uint256 kttyBalanceBefore = kttyToken.balanceOf(user1);
        uint256 rwd1BalanceBefore = rewardToken1.balanceOf(user1);
        uint256 proxyRwd1BalanceBefore = rewardToken1.balanceOf(address(proxy));
        
        // Claim rewards and withdraw
        proxy.claimRewardsAndWithdraw(1);
        
        // Check balances after claiming
        uint256 kttyBalanceAfter = kttyToken.balanceOf(user1);
        uint256 rwd1BalanceAfter = rewardToken1.balanceOf(user1);
        
        // Verify user received their stake back plus rewards
        assertEq(kttyBalanceAfter, kttyBalanceBefore + stakeAmount + expectedKttyReward);
        assertEq(rwd1BalanceAfter, rwd1BalanceBefore + expectedRwd1Reward);
        
        // Check that stake is marked as withdrawn and rewards claimed
        (, , , , , , bool hasWithdrawn, bool hasClaimedRewards) = proxy.getStake(1);
        assertTrue(hasWithdrawn);
        assertTrue(hasClaimedRewards);
        
        vm.stopPrank();
    }
    
    function test_EmergencyWithdrawal() public {
        vm.startPrank(emergencyAdmin);
        
        // Get initial balance
        uint256 initialBalance = rewardToken1.balanceOf(emergencyAdmin);
        
        // Emergency withdraw some tokens
        uint256 withdrawAmount = 100 * 1e18;
        proxy.emergencyWithdraw(address(rewardToken1), emergencyAdmin, withdrawAmount);
        
        // Check that tokens were withdrawn
        uint256 finalBalance = rewardToken1.balanceOf(emergencyAdmin);
        assertEq(finalBalance, initialBalance + withdrawAmount);
        
        vm.stopPrank();
    }
    
    function test_Pause() public {
        vm.startPrank(admin);
        
        // Add a tier
        proxy.addTier("Bronze", 100 * 1e18, 1000 * 1e18, 30, 50000);
        
        // Pause the contract
        proxy.pause();
        
        vm.stopPrank();
        
        vm.startPrank(user1);
        
        // Approve tokens for staking
        uint256 stakeAmount = 200 * 1e18;
        kttyToken.approve(address(proxy), stakeAmount);
        
        // Try to stake tokens while paused (should fail)
        vm.expectRevert(); // This will pass if any revert happens
        proxy.stake(stakeAmount, 1);
        
        vm.stopPrank();
        
        vm.startPrank(admin);
        
        // Unpause the contract
        proxy.unpause();
        
        vm.stopPrank();
        
        vm.startPrank(user1);
        
        // Try to stake tokens after unpausing (should succeed)
        proxy.stake(stakeAmount, 1);
        
        // Verify the stake was created
        (uint256 id, address owner, , , , , , ) = proxy.getStake(1);
        assertEq(id, 1);
        assertEq(owner, user1);
        
        vm.stopPrank();
    }
    
    function test_UpgradeContract() public {
        // Test that the proxy admin can upgrade the implementation
        vm.startPrank(admin);
        
        // Deploy a new implementation
        KTTYStaking newImplementation = new KTTYStaking();
        
        // Upgrade the proxy with empty data (no function call)
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(address(transparentProxy)), address(newImplementation), new bytes(0));
        
        // Verify the contract still works after upgrade by creating a tier
        proxy.addTier("Bronze", 100 * 1e18, 1000 * 1e18, 30, 50000);
        
        // Check tier was created successfully
        (uint256 id, string memory name, , , , , ) = proxy.tiers(1);
        assertEq(id, 1);
        assertEq(name, "Bronze");
        
        vm.stopPrank();
    }
    
    function test_UnauthorizedUpgrade() public {
        // Test that only admin can upgrade the implementation
        vm.startPrank(user1);
        
        // Deploy a new implementation
        KTTYStaking newImplementation = new KTTYStaking();
        
        // Try to upgrade the proxy (should fail)
        vm.expectRevert(); // This will pass if any revert happens
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(address(transparentProxy)), address(newImplementation), new bytes(0));
        
        vm.stopPrank();
    }
    
    // function test_UpgradeContract() public {
    //     vm.startPrank(admin);
        
    //     // Deploy a new implementation
    //     KTTYStaking newImplementation = new KTTYStaking();
        
    //     // Upgrade using UUPS pattern (admin has UPGRADER_ROLE)
    //     proxy.upgradeToAndCall(address(newImplementation), new bytes(0));
        
    //     // Verify the contract still works after upgrade by creating a tier
    //     proxy.addTier("Bronze", 100 * 1e18, 1000 * 1e18, 30, 50000);
        
    //     // Check tier was created successfully
    //     (uint256 id, string memory name, , , , , ) = proxy.tiers(1);
    //     assertEq(id, 1);
    //     assertEq(name, "Bronze");
        
    //     vm.stopPrank();
    // }
    
    // function test_UnauthorizedUpgrade() public {
    //     vm.startPrank(user1);
        
    //     // Deploy a new implementation
    //     KTTYStaking newImplementation = new KTTYStaking();
        
    //     // Try to upgrade without UPGRADER_ROLE (should fail)
    //     vm.expectRevert();
    //     proxy.upgradeToAndCall(address(newImplementation), new bytes(0));
        
    //     vm.stopPrank();
    // }
    
    function test_RemoveRewardToken() public {
        vm.startPrank(tierManager);
        
        // Add multiple tiers
        proxy.addTier("Bronze", 100 * 1e18, 1000 * 1e18, 30, 50000);
        proxy.addTier("Silver", 1000 * 1e18, 5000 * 1e18, 60, 80000);
        
        vm.stopPrank();
        
        vm.startPrank(fundManager);
        
        // Register reward token
        proxy.registerRewardToken(address(rewardToken1), "RWD1", 500000);
        
        vm.stopPrank();
        
        vm.startPrank(tierManager);
        
        // Add reward token to both tiers
        proxy.addRewardTokenToTier(1, address(rewardToken1));
        proxy.addRewardTokenToTier(2, address(rewardToken1));
        
        // Verify token is in both tiers
        address[] memory tier1Tokens = proxy.getTierRewardTokens(1);
        address[] memory tier2Tokens = proxy.getTierRewardTokens(2);
        assertEq(tier1Tokens.length, 1);
        assertEq(tier2Tokens.length, 1);
        assertEq(tier1Tokens[0], address(rewardToken1));
        assertEq(tier2Tokens[0], address(rewardToken1));
        
        vm.stopPrank();
        
        vm.startPrank(fundManager);
        
        // Get initial balances
        uint256 contractBalanceBefore = rewardToken1.balanceOf(address(proxy));
        uint256 recipientBalanceBefore = rewardToken1.balanceOf(user2);
        
        // Verify token is active before removal
        (, , , bool isActiveBefore) = proxy.rewardTokens(address(rewardToken1));
        assertTrue(isActiveBefore);
        
        // Remove reward token completely
        vm.expectEmit(true, true, false, true);
        emit KTTYStaking.TierRewardTokenRemoved(1, address(rewardToken1));
        vm.expectEmit(true, true, false, true);
        emit KTTYStaking.TierRewardTokenRemoved(2, address(rewardToken1));
        vm.expectEmit(true, true, false, true);
        emit KTTYStaking.RewardTokenCompletelyRemoved(address(rewardToken1), user2, contractBalanceBefore);
        
        proxy.removeRewardToken(address(rewardToken1), user2);
        
        // Verify token removed from both tiers
        tier1Tokens = proxy.getTierRewardTokens(1);
        tier2Tokens = proxy.getTierRewardTokens(2);
        assertEq(tier1Tokens.length, 0);
        assertEq(tier2Tokens.length, 0);
        
        // Verify token is deactivated
        (, , , bool isActiveAfter) = proxy.rewardTokens(address(rewardToken1));
        assertFalse(isActiveAfter);
        
        // Verify balance was transferred
        uint256 contractBalanceAfter = rewardToken1.balanceOf(address(proxy));
        uint256 recipientBalanceAfter = rewardToken1.balanceOf(user2);
        assertEq(contractBalanceAfter, 0);
        assertEq(recipientBalanceAfter, recipientBalanceBefore + contractBalanceBefore);
        
        vm.stopPrank();
    }
    
    function test_RemoveRewardTokenMultipleTiers() public {
        vm.startPrank(tierManager);
        
        // Add 3 tiers
        proxy.addTier("Bronze", 100 * 1e18, 1000 * 1e18, 30, 50000);
        proxy.addTier("Silver", 1000 * 1e18, 5000 * 1e18, 60, 80000);
        proxy.addTier("Gold", 5000 * 1e18, 0, 90, 120000);
        
        vm.stopPrank();
        
        vm.startPrank(fundManager);
        
        // Register reward token
        proxy.registerRewardToken(address(rewardToken1), "RWD1", 500000);
        
        vm.stopPrank();
        
        vm.startPrank(tierManager);
        
        // Add reward token to all 3 tiers
        proxy.addRewardTokenToTier(1, address(rewardToken1));
        proxy.addRewardTokenToTier(2, address(rewardToken1));
        proxy.addRewardTokenToTier(3, address(rewardToken1));
        
        vm.stopPrank();
        
        vm.startPrank(fundManager);
        
        // Remove reward token and expect 3 tier removal events
        vm.expectEmit(true, true, false, true);
        emit KTTYStaking.TierRewardTokenRemoved(1, address(rewardToken1));
        vm.expectEmit(true, true, false, true);
        emit KTTYStaking.TierRewardTokenRemoved(2, address(rewardToken1));
        vm.expectEmit(true, true, false, true);
        emit KTTYStaking.TierRewardTokenRemoved(3, address(rewardToken1));
        
        proxy.removeRewardToken(address(rewardToken1), user2);
        
        // Verify token removed from all tiers
        assertEq(proxy.getTierRewardTokens(1).length, 0);
        assertEq(proxy.getTierRewardTokens(2).length, 0);
        assertEq(proxy.getTierRewardTokens(3).length, 0);
        
        vm.stopPrank();
    }
    
    function test_RemoveRewardTokenBalanceTransfer() public {
        vm.startPrank(fundManager);
        
        // Register reward token
        proxy.registerRewardToken(address(rewardToken1), "RWD1", 500000);
        
        // Get exact contract balance
        uint256 exactBalance = rewardToken1.balanceOf(address(proxy));
        uint256 recipientBalanceBefore = rewardToken1.balanceOf(user2);
        
        // Remove reward token
        proxy.removeRewardToken(address(rewardToken1), user2);
        
        // Verify exact balance was transferred
        assertEq(rewardToken1.balanceOf(address(proxy)), 0);
        assertEq(rewardToken1.balanceOf(user2), recipientBalanceBefore + exactBalance);
        
        vm.stopPrank();
    }
    
    function test_RemoveRewardTokenPartialTiers() public {
        vm.startPrank(tierManager);
        
        // Add 3 tiers
        proxy.addTier("Bronze", 100 * 1e18, 1000 * 1e18, 30, 50000);
        proxy.addTier("Silver", 1000 * 1e18, 5000 * 1e18, 60, 80000);
        proxy.addTier("Gold", 5000 * 1e18, 0, 90, 120000);
        
        vm.stopPrank();
        
        vm.startPrank(fundManager);
        
        // Register reward tokens
        proxy.registerRewardToken(address(rewardToken1), "RWD1", 500000);
        proxy.registerRewardToken(address(rewardToken2), "RWD2", 250000);
        
        vm.stopPrank();
        
        vm.startPrank(tierManager);
        
        // Add rewardToken1 to only 2 tiers, rewardToken2 to all tiers
        proxy.addRewardTokenToTier(1, address(rewardToken1));
        proxy.addRewardTokenToTier(2, address(rewardToken1));
        proxy.addRewardTokenToTier(1, address(rewardToken2));
        proxy.addRewardTokenToTier(2, address(rewardToken2));
        proxy.addRewardTokenToTier(3, address(rewardToken2));
        
        vm.stopPrank();
        
        vm.startPrank(fundManager);
        
        // Remove rewardToken1 - should only affect tiers 1 and 2
        vm.expectEmit(true, true, false, true);
        emit KTTYStaking.TierRewardTokenRemoved(1, address(rewardToken1));
        vm.expectEmit(true, true, false, true);
        emit KTTYStaking.TierRewardTokenRemoved(2, address(rewardToken1));
        // No event for tier 3 since token wasn't there
        
        proxy.removeRewardToken(address(rewardToken1), user2);
        
        // Verify rewardToken1 removed from tiers 1&2, rewardToken2 still in all tiers
        assertEq(proxy.getTierRewardTokens(1).length, 1); // Only rewardToken2
        assertEq(proxy.getTierRewardTokens(2).length, 1); // Only rewardToken2
        assertEq(proxy.getTierRewardTokens(3).length, 1); // Only rewardToken2
        assertEq(proxy.getTierRewardTokens(1)[0], address(rewardToken2));
        assertEq(proxy.getTierRewardTokens(2)[0], address(rewardToken2));
        assertEq(proxy.getTierRewardTokens(3)[0], address(rewardToken2));
        
        vm.stopPrank();
    }
    
    function test_RemoveRewardTokenNotInAnyTier() public {
        vm.startPrank(fundManager);
        
        // Register reward token but don't add to any tier
        proxy.registerRewardToken(address(rewardToken1), "RWD1", 500000);
        
        uint256 contractBalance = rewardToken1.balanceOf(address(proxy));
        uint256 recipientBalanceBefore = rewardToken1.balanceOf(user2);
        
        // Remove reward token - should only deactivate and transfer balance
        vm.expectEmit(true, true, false, true);
        emit KTTYStaking.RewardTokenCompletelyRemoved(address(rewardToken1), user2, contractBalance);
        // No TierRewardTokenRemoved events should be emitted
        
        proxy.removeRewardToken(address(rewardToken1), user2);
        
        // Verify token is deactivated
        (, , , bool isActive) = proxy.rewardTokens(address(rewardToken1));
        assertFalse(isActive);
        
        // Verify balance was transferred
        assertEq(rewardToken1.balanceOf(address(proxy)), 0);
        assertEq(rewardToken1.balanceOf(user2), recipientBalanceBefore + contractBalance);
        
        vm.stopPrank();
    }
    
    function test_RemoveRewardTokenUnauthorized() public {
        vm.startPrank(fundManager);
        
        // Register reward token
        proxy.registerRewardToken(address(rewardToken1), "RWD1", 500000);
        
        vm.stopPrank();
        
        vm.startPrank(user1); // Not a fund manager
        
        // Try to remove reward token (should fail)
        vm.expectRevert();
        proxy.removeRewardToken(address(rewardToken1), user2);
        
        vm.stopPrank();
    }
    
    function test_RemoveRewardTokenZeroTokenAddress() public {
        vm.startPrank(fundManager);
        
        // Try to remove with zero token address (should fail)
        vm.expectRevert();
        proxy.removeRewardToken(address(0), user2);
        
        vm.stopPrank();
    }
    
    function test_RemoveRewardTokenZeroRecipientAddress() public {
        vm.startPrank(fundManager);
        
        // Register reward token
        proxy.registerRewardToken(address(rewardToken1), "RWD1", 500000);
        
        // Try to remove with zero recipient address (should fail)
        vm.expectRevert();
        proxy.removeRewardToken(address(rewardToken1), address(0));
        
        vm.stopPrank();
    }
    
    function test_RemoveRewardTokenNotRegistered() public {
        vm.startPrank(fundManager);
        
        // Try to remove unregistered token (should fail)
        vm.expectRevert();
        proxy.removeRewardToken(address(rewardToken1), user2);
        
        vm.stopPrank();
    }
    
    function test_GetAllRewardTokens() public {
        vm.startPrank(fundManager);
        
        // Initially should return empty arrays
        (address[] memory addresses, string[] memory symbols) = proxy.getAllRewardTokens();
        assertEq(addresses.length, 0);
        assertEq(symbols.length, 0);
        
        // Register reward tokens
        proxy.registerRewardToken(address(rewardToken1), "RWD1", 500000);
        proxy.registerRewardToken(address(rewardToken2), "RWD2", 250000);
        
        // Get all reward tokens
        (addresses, symbols) = proxy.getAllRewardTokens();
        
        // Verify arrays have correct length
        assertEq(addresses.length, 2);
        assertEq(symbols.length, 2);
        
        // Verify first token
        assertEq(addresses[0], address(rewardToken1));
        assertEq(symbols[0], "RWD1");
        
        // Verify second token
        assertEq(addresses[1], address(rewardToken2));
        assertEq(symbols[1], "RWD2");
        
        vm.stopPrank();
    }
    
    function test_GetAllRewardTokensAfterRemoval() public {
        vm.startPrank(fundManager);
        
        // Register multiple reward tokens
        proxy.registerRewardToken(address(rewardToken1), "RWD1", 500000);
        proxy.registerRewardToken(address(rewardToken2), "RWD2", 250000);
        
        // Verify both tokens are returned
        (address[] memory addresses, string[] memory symbols) = proxy.getAllRewardTokens();
        assertEq(addresses.length, 2);
        assertEq(symbols.length, 2);
        
        // Remove one token (should still be in the list but deactivated)
        proxy.removeRewardToken(address(rewardToken1), user2);
        
        // Get all reward tokens again - should still show both (removal doesn't delete from rewardTokenAddresses)
        (addresses, symbols) = proxy.getAllRewardTokens();
        assertEq(addresses.length, 2);
        assertEq(symbols.length, 2);
        
        // Verify the symbols are still correct
        bool foundRwd1 = false;
        bool foundRwd2 = false;
        for (uint256 i = 0; i < addresses.length; i++) {
            if (addresses[i] == address(rewardToken1) && keccak256(bytes(symbols[i])) == keccak256(bytes("RWD1"))) {
                foundRwd1 = true;
            }
            if (addresses[i] == address(rewardToken2) && keccak256(bytes(symbols[i])) == keccak256(bytes("RWD2"))) {
                foundRwd2 = true;
            }
        }
        assertTrue(foundRwd1);
        assertTrue(foundRwd2);
        
        vm.stopPrank();
    }
}
