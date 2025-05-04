// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/KTTYStaking.sol"; // Adjust path as needed
import "@openzeppelin/contracts/token/ERC20/ERC20.sol"; // For mock tokens

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        // Mint some tokens to the deployer
        _mint(msg.sender, 1000000 * 10 ** 18);
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract KTTYStakingTest is Test {
    // Constants
    uint256 constant MILLION = 1_000_000 ether;
    uint256 constant TEN_MILLION = 10 * MILLION;
    uint256 constant TWENTY_MILLION = 20 * MILLION;
    uint256 constant FIFTY_MILLION = 50 * MILLION;

    // Roles
    bytes32 constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 constant TIER_MANAGER_ROLE = keccak256("TIER_MANAGER_ROLE");
    bytes32 constant FUND_MANAGER_ROLE = keccak256("FUND_MANAGER_ROLE");
    bytes32 constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    // Contracts
    KTTYStaking stakingContract;
    MockERC20 kttyToken;
    MockERC20 zeeToken;
    MockERC20 kevAIToken;
    MockERC20 realToken;
    MockERC20 pawToken;

    // Actors
    address admin = address(0x1);
    address tierManager = address(0x2);
    address fundManager = address(0x3);
    address emergency = address(0x4);
    address user1 = address(0x5);
    address user2 = address(0x6);
    address user3 = address(0x7);

    // Tier IDs
    uint256 tier1ID;
    uint256 tier2ID;
    uint256 tier3ID;
    uint256 tier4ID;
    uint256 tier5ID;

    // Events for testing
    event TierCreated(
        uint256 indexed tierId,
        string name,
        uint256 minStake,
        uint256 lockupPeriod,
        uint256 apy
    );
    event Staked(
        uint256 indexed stakeId,
        address indexed owner,
        uint256 amount,
        uint256 tierId,
        uint256 startTime,
        uint256 endTime
    );
    event StakeWithdrawn(
        uint256 indexed stakeId,
        address indexed owner,
        uint256 amount
    );
    event RewardClaimed(
        uint256 indexed stakeId,
        address indexed owner,
        address indexed token,
        uint256 amount
    );

    function setUp() public {
        // Start impersonating admin
        vm.startPrank(admin);

        // Deploy mock tokens
        kttyToken = new MockERC20("KTTY Token", "KTTY");
        zeeToken = new MockERC20("ZEE Token", "ZEE");
        kevAIToken = new MockERC20("KEV-AI Token", "KEV");
        realToken = new MockERC20("REAL Token", "REAL");
        pawToken = new MockERC20("PAW Token", "PAW");

        // Deploy staking contract
        stakingContract = new KTTYStaking(address(kttyToken));

        // Grant roles
        stakingContract.grantRole(TIER_MANAGER_ROLE, tierManager);
        stakingContract.grantRole(FUND_MANAGER_ROLE, fundManager);
        stakingContract.grantRole(EMERGENCY_ROLE, emergency);

        // Stop impersonating admin
        vm.stopPrank();

        // Mint tokens to staking contract for rewards
        mintRewardTokens(FIFTY_MILLION);

        // Mint tokens to users for staking
        mintUserTokens(FIFTY_MILLION);

        // Register reward tokens
        registerRewardTokens();

        // Add tiers based on the provided requirements
        setupTiers();
    }

    function mintRewardTokens(uint256 amount) internal {
        vm.startPrank(admin);
        kttyToken.mint(address(stakingContract), amount);
        zeeToken.mint(address(stakingContract), amount);
        kevAIToken.mint(address(stakingContract), amount);
        realToken.mint(address(stakingContract), amount);
        pawToken.mint(address(stakingContract), amount);
        vm.stopPrank();
    }

    function mintUserTokens(uint256 amount) internal {
        vm.startPrank(admin);
        kttyToken.mint(user1, amount);
        kttyToken.mint(user2, amount);
        kttyToken.mint(user3, amount);
        vm.stopPrank();

        // Approve tokens
        vm.prank(user1);
        kttyToken.approve(address(stakingContract), amount);

        vm.prank(user2);
        kttyToken.approve(address(stakingContract), amount);

        vm.prank(user3);
        kttyToken.approve(address(stakingContract), amount);
    }

    function registerRewardTokens() internal {
        vm.startPrank(fundManager);

        // Register additional reward tokens
        stakingContract.registerRewardToken(
            address(zeeToken),
            "ZEE",
            1_000_000
        ); // 100% of KTTY reward
        stakingContract.registerRewardToken(
            address(kevAIToken),
            "KEV",
            1_000_000
        );
        stakingContract.registerRewardToken(
            address(realToken),
            "REAL",
            1_000_000
        );
        stakingContract.registerRewardToken(
            address(pawToken),
            "PAW",
            1_000_000
        );

        vm.stopPrank();
    }

    function setupTiers() internal {
        vm.startPrank(tierManager);

        // APYs in terms of percentage per staking period (not annualized)
        // 0.2% = 2,000, 0.4% = 4,000, 1.0% = 10,000, 1.5% = 15,000, 2.5% = 25,000

        // Tier 1: 1M - 2.9M $KTTY, 30 days lockup, 0.2% fixed in $KTTY
        vm.expectEmit(true, true, true, true);
        emit TierCreated(1, "Tier 1", 1 * MILLION, 30 days, 2_000);
        stakingContract.addTier(
            "Tier 1",
            1 * MILLION, // Min 1M KTTY
            (29 * MILLION) / 10, // Max 2.9M KTTY
            30, // 30 days lockup
            2_000 // 0.2% APY (scaled by 1e6)
        );
        tier1ID = 1;

        // Tier 2: 3M - 5.9M $KTTY, 60 days lockup, 0.4% fixed in $KTTY + $ZEE
        stakingContract.addTier(
            "Tier 2",
            3 * MILLION, // Min 3M KTTY
            (59 * MILLION) / 10, // Max 5.9M KTTY
            60, // 60 days lockup
            4_000 // 0.4% APY (scaled by 1e6)
        );
        tier2ID = 2;

        // Add ZEE token to Tier 2
        stakingContract.addRewardTokenToTier(tier2ID, address(zeeToken));

        // Tier 3: 6M+ $KTTY, 90 days lockup, 1% fixed in all tokens
        stakingContract.addTier(
            "Tier 3",
            6 * MILLION, // Min 6M KTTY
            0, // No max (unlimited)
            90, // 90 days lockup
            10_000 // 1.0% APY (scaled by 1e6)
        );
        tier3ID = 3;

        // Add all reward tokens to Tier 3
        stakingContract.addRewardTokenToTier(tier3ID, address(zeeToken));
        stakingContract.addRewardTokenToTier(tier3ID, address(kevAIToken));
        stakingContract.addRewardTokenToTier(tier3ID, address(realToken));
        stakingContract.addRewardTokenToTier(tier3ID, address(pawToken));

        // Tier 4 (Diamond): 10M+ $KTTY, 90 days lockup, 1.5% fixed APR in KTTY
        stakingContract.addTier(
            "Diamond",
            10 * MILLION, // Min 10M KTTY
            0, // No max (unlimited)
            90, // 90 days lockup
            15_000 // 1.5% APY (scaled by 1e6)
        );
        tier4ID = 4;

        // Tier 5 (Platinum): 20M+ $KTTY, 180 days lockup, 2.5% fixed APR
        stakingContract.addTier(
            "Platinum",
            20 * MILLION, // Min 20M KTTY
            0, // No max (unlimited)
            180, // 180 days lockup
            25_000 // 2.5% APY (scaled by 1e6)
        );
        tier5ID = 5;

        vm.stopPrank();
    }

    /* ------------- Basic Functionality Tests ------------- */

    function testDeployment() public view {
        // Verify roles
        assertTrue(stakingContract.hasRole(ADMIN_ROLE, admin));
        assertTrue(stakingContract.hasRole(TIER_MANAGER_ROLE, tierManager));
        assertTrue(stakingContract.hasRole(FUND_MANAGER_ROLE, fundManager));
        assertTrue(stakingContract.hasRole(EMERGENCY_ROLE, emergency));

        // Verify token
        assertEq(address(stakingContract.kttyToken()), address(kttyToken));

        // Verify tier count
        assertEq(stakingContract.getTierCount(), 5);
    }

    function testTierCreation() public view {
        // Check tier details for tier 1
        (
            uint256 id,
            string memory name,
            uint256 minStake,
            uint256 maxStake,
            uint256 lockupPeriod,
            uint256 apy,
            bool isActive
        ) = stakingContract.tiers(tier1ID);

        assertEq(id, tier1ID);
        assertEq(name, "Tier 1");
        assertEq(minStake, 1 * MILLION);
        assertEq(maxStake, (29 * MILLION) / 10);
        assertEq(lockupPeriod, 30 days);
        assertEq(apy, 2_000);
        assertTrue(isActive);

        // Check tier reward tokens for tier 3
        address[] memory tier3Tokens = stakingContract.getTierRewardTokens(
            tier3ID
        );
        assertEq(tier3Tokens.length, 4);
        assertEq(tier3Tokens[0], address(zeeToken));
        assertEq(tier3Tokens[1], address(kevAIToken));
        assertEq(tier3Tokens[2], address(realToken));
        assertEq(tier3Tokens[3], address(pawToken));
    }

    function testStakingTier1() public {
        uint256 stakeAmount = (15 * MILLION) / 10;

        vm.startPrank(user1);

        vm.expectEmit(true, true, true, true);
        emit Staked(
            1,
            user1,
            stakeAmount,
            tier1ID,
            block.timestamp,
            block.timestamp + 30 days
        );
        stakingContract.stake(stakeAmount, tier1ID);

        vm.stopPrank();

        // Verify stake
        (
            uint256 id,
            address owner,
            uint256 amount,
            uint256 tierId,
            ,
            ,
            bool hasWithdrawn,

        ) = stakingContract.getStake(1);

        assertEq(id, 1);
        assertEq(owner, user1);
        assertEq(amount, stakeAmount);
        assertEq(tierId, tier1ID);
        assertFalse(hasWithdrawn);

        // Verify user stakes
        uint256[] memory userStakes = stakingContract.getUserStakes(user1);
        assertEq(userStakes.length, 1);
        assertEq(userStakes[0], 1);
    }

    function testStakingTier5() public {
        uint256 stakeAmount = 25 * MILLION;

        vm.startPrank(user2);

        stakingContract.stake(stakeAmount, tier5ID);

        vm.stopPrank();

        // Verify stake
        (
            uint256 id,
            address owner,
            uint256 amount,
            uint256 tierId,
            ,
            ,
            bool hasWithdrawn,

        ) = stakingContract.getStake(1);

        assertEq(id, 1);
        assertEq(owner, user2);
        assertEq(amount, stakeAmount);
        assertEq(tierId, tier5ID);
        assertFalse(hasWithdrawn);

        // Check reward calculation
        uint256 kttyReward = stakingContract.calculateReward(1, address(0));
        // Expected: 25M * 2.5% = 625,000 KTTY
        assertEq(kttyReward, 625_000 ether);
    }

    function testWithdrawAfterLockup() public {
        uint256 stakeAmount = (15 * MILLION) / 10;

        // User1 stakes
        vm.prank(user1);
        stakingContract.stake(stakeAmount, tier1ID);

        // Get user1's balance before withdrawal
        uint256 balanceBefore = kttyToken.balanceOf(user1);

        // Fast forward past lockup period
        vm.warp(block.timestamp + 31 days);

        // User1 withdraws
        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit StakeWithdrawn(1, user1, stakeAmount);
        stakingContract.withdraw(1);

        // Verify user1's balance after withdrawal
        uint256 balanceAfter = kttyToken.balanceOf(user1);
        assertEq(balanceAfter - balanceBefore, stakeAmount);

        // Verify stake status
        (, , , , , , bool hasWithdrawn, ) = stakingContract.getStake(1);
        assertTrue(hasWithdrawn);
    }

    function testClaimRewardsAndWithdraw() public {
        uint256 stakeAmount = 3 * MILLION;

        // User2 stakes in tier 2
        vm.prank(user2);
        stakingContract.stake(stakeAmount, tier2ID);

        // Get user2's balance before claim
        uint256 kttyBalanceBefore = kttyToken.balanceOf(user2);
        uint256 zeeBalanceBefore = zeeToken.balanceOf(user2);

        // Fast forward past lockup period
        vm.warp(block.timestamp + 61 days);

        // Calculate expected rewards
        // 3M * 0.4% = 12,000 KTTY and 12,000 ZEE
        uint256 expectedReward = 12_000 ether;

        // User2 claims rewards and withdraws
        vm.prank(user2);
        stakingContract.claimRewardsAndWithdraw(1);

        // Verify user2's balances after claim
        uint256 kttyBalanceAfter = kttyToken.balanceOf(user2);
        uint256 zeeBalanceAfter = zeeToken.balanceOf(user2);

        // Check principal returned
        assertEq(
            kttyBalanceAfter - kttyBalanceBefore,
            stakeAmount + expectedReward
        );

        // Check ZEE reward
        assertEq(zeeBalanceAfter - zeeBalanceBefore, expectedReward);

        // Verify stake status
        (
            ,
            ,
            ,
            ,
            ,
            ,
            bool hasWithdrawn,
            bool hasClaimedRewards
        ) = stakingContract.getStake(1);
        assertTrue(hasWithdrawn);
        assertTrue(hasClaimedRewards);
    }

    /* ------------- Edge Cases and Advanced Tests ------------- */

    function testCannotStakeBeforeApproval() public {
        // Create a new user without approval
        address newUser = address(0x9);

        vm.startPrank(admin);
        kttyToken.mint(newUser, 2 * MILLION);
        vm.stopPrank();

        // Try to stake without approval
        vm.startPrank(newUser);
        vm.expectRevert();
        stakingContract.stake((15 * MILLION) / 10, tier1ID);
        vm.stopPrank();
    }

    function testCannotWithdrawBeforeLockupPeriod() public {
        uint256 stakeAmount = (15 * MILLION) / 10;

        // User1 stakes
        vm.prank(user1);
        stakingContract.stake(stakeAmount, tier1ID);

        // Try to withdraw before lockup period ends
        vm.prank(user1);
        vm.expectRevert(KTTYStaking.LockupNotCompleted.selector);
        stakingContract.withdraw(1);
    }

    function testCannotWithdrawOtherUsersStake() public {
        uint256 stakeAmount = (15 * MILLION) / 10;

        // User1 stakes
        vm.prank(user1);
        stakingContract.stake(stakeAmount, tier1ID);

        // Fast forward past lockup period
        vm.warp(block.timestamp + 31 days);

        // User2 tries to withdraw User1's stake
        vm.prank(user2);
        vm.expectRevert(KTTYStaking.UnauthorizedWithdrawal.selector);
        stakingContract.withdraw(1);
    }

    function testCannotStakeLessThanMinimum() public {
        uint256 stakeAmount = (5 * MILLION) / 10; // Less than tier 1 minimum

        vm.prank(user1);
        vm.expectRevert(KTTYStaking.InvalidAmount.selector);
        stakingContract.stake(stakeAmount, tier1ID);
    }

    function testCannotStakeMoreThanMaximum() public {
        uint256 stakeAmount = 3 * MILLION; // More than tier 1 maximum

        vm.prank(user1);
        vm.expectRevert(KTTYStaking.InvalidAmount.selector);
        stakingContract.stake(stakeAmount, tier1ID);
    }

    function testCannotStakeToInactiveTier() public {
        // Admin deactivates tier 1
        vm.prank(tierManager);
        stakingContract.updateTier(
            tier1ID,
            "Tier 1",
            1 * MILLION,
            (29 * MILLION) / 10,
            30,
            2_000,
            false
        );

        // User1 tries to stake to inactive tier
        vm.prank(user1);
        vm.expectRevert(KTTYStaking.InvalidTier.selector);
        stakingContract.stake((15 * MILLION) / 10, tier1ID);
    }

    function testCannotWithdrawTwice() public {
        uint256 stakeAmount = (15 * MILLION) / 10;

        // User1 stakes
        vm.prank(user1);
        stakingContract.stake(stakeAmount, tier1ID);

        // Fast forward past lockup period
        vm.warp(block.timestamp + 31 days);

        // User1 withdraws
        vm.prank(user1);
        stakingContract.withdraw(1);

        // User1 tries to withdraw again
        vm.prank(user1);
        vm.expectRevert(KTTYStaking.StakingNotLocked.selector);
        stakingContract.withdraw(1);
    }

    function testCannotClaimRewardsTwice() public {
        uint256 stakeAmount = 3 * MILLION;

        // User2 stakes in tier 2
        vm.prank(user2);
        stakingContract.stake(stakeAmount, tier2ID);

        // Fast forward past lockup period
        vm.warp(block.timestamp + 61 days);

        // User2 claims rewards and withdraws
        vm.prank(user2);
        stakingContract.claimRewardsAndWithdraw(1);

        // User2 tries to claim rewards again
        vm.prank(user2);
        vm.expectRevert(KTTYStaking.RewardAlreadyClaimed.selector);
        stakingContract.claimRewardsAndWithdraw(1);
    }

    function testMultipleStakesByOneUser() public {
        // User3 makes multiple stakes
        vm.startPrank(user3);

        // Stake in tier 1
        stakingContract.stake((15 * MILLION) / 10, tier1ID);

        // Stake in tier 2
        stakingContract.stake(4 * MILLION, tier2ID);

        // Stake in tier 3
        stakingContract.stake(8 * MILLION, tier3ID);

        vm.stopPrank();

        // Verify user's stakes
        uint256[] memory userStakes = stakingContract.getUserStakes(user3);
        assertEq(userStakes.length, 3);
        assertEq(userStakes[0], 1);
        assertEq(userStakes[1], 2);
        assertEq(userStakes[2], 3);

        // Verify stake details
        (, , uint256 amount1, uint256 tierId1, , , , ) = stakingContract
            .getStake(1);
        assertEq(amount1, (15 * MILLION) / 10);
        assertEq(tierId1, tier1ID);

        (, , uint256 amount2, uint256 tierId2, , , , ) = stakingContract
            .getStake(2);
        assertEq(amount2, 4 * MILLION);
        assertEq(tierId2, tier2ID);

        (, , uint256 amount3, uint256 tierId3, , , , ) = stakingContract
            .getStake(3);
        assertEq(amount3, 8 * MILLION);
        assertEq(tierId3, tier3ID);
    }

    function testEmergencyWithdraw() public {
        uint256 withdrawAmount = 5 * MILLION;

        // Check initial balance
        uint256 emergencyUserBalance = kttyToken.balanceOf(emergency);

        // Emergency user executes emergency withdrawal
        vm.prank(emergency);
        stakingContract.emergencyWithdraw(
            address(kttyToken),
            emergency,
            withdrawAmount
        );

        // Verify balance after emergency withdrawal
        uint256 newBalance = kttyToken.balanceOf(emergency);
        assertEq(newBalance - emergencyUserBalance, withdrawAmount);
    }

    function testUpdateTier() public {
        // Update tier 1
        vm.prank(tierManager);
        stakingContract.updateTier(
            tier1ID,
            "Updated Tier 1",
            (12 * MILLION) / 10, // Increased min
            3 * MILLION, // Increased max
            40, // Increased lockup days
            2_500, // Increased APY
            true
        );

        // Verify updated tier
        (
            uint256 id,
            string memory name,
            uint256 minStake,
            uint256 maxStake,
            uint256 lockupPeriod,
            uint256 apy,
            bool isActive
        ) = stakingContract.tiers(tier1ID);

        assertEq(id, tier1ID);
        assertEq(name, "Updated Tier 1");
        assertEq(minStake, (12 * MILLION) / 10);
        assertEq(maxStake, 3 * MILLION);
        assertEq(lockupPeriod, 40 days);
        assertEq(apy, 2_500);
        assertTrue(isActive);
    }

    function testUpdateRewardToken() public {
        // Update ZEE token reward rate
        vm.prank(fundManager);
        stakingContract.updateRewardToken(address(zeeToken), 1_500_000, true); // 150%

        // Verify updated reward token
        (
            string memory symbol,
            address tokenAddress,
            uint256 rewardRate,
            bool isActive
        ) = stakingContract.rewardTokens(address(zeeToken));

        assertEq(symbol, "ZEE");
        assertEq(tokenAddress, address(zeeToken));
        assertEq(rewardRate, 1_500_000);
        assertTrue(isActive);
    }

    function testContractPauseAndUnpause() public {
        // First create a stake
        vm.prank(user1);
        stakingContract.stake((15 * MILLION) / 10, tier1ID);

        // Fast forward past lockup period
        vm.warp(block.timestamp + 31 days);

        // Admin pauses the contract
        vm.prank(admin);
        stakingContract.pause();

        // Try to stake while paused (should fail)
        vm.prank(user1);
        vm.expectRevert();
        stakingContract.stake((15 * MILLION) / 10, tier1ID);

        // User should still be able to withdraw while paused (after lockup period)
        vm.prank(user1);
        stakingContract.withdraw(1);

        // Admin unpauses the contract
        vm.prank(admin);
        stakingContract.unpause();

        // Staking should work again after unpausing
        vm.prank(user1);
        stakingContract.stake((15 * MILLION) / 10, tier1ID);
    }

    /* ------------- Fuzz Tests ------------- */

    function testFuzz_StakeWithinValidRange(uint256 amount) public {
        // Bound amount between min and max for tier 1
        amount = bound(amount, 1 * MILLION, (29 * MILLION) / 10);

        vm.prank(user1);
        stakingContract.stake(amount, tier1ID);

        // Verify stake amount
        (, , uint256 stakedAmount, , , , , ) = stakingContract.getStake(1);
        assertEq(stakedAmount, amount);
    }

    function testFuzz_RewardCalculation(uint256 amount) public {
        // Bound amount between min and max for tier 2
        amount = bound(amount, 3 * MILLION, (59 * MILLION) / 10);

        vm.prank(user2);
        stakingContract.stake(amount, tier2ID);

        // Calculate expected KTTY reward: amount * 0.4%
        uint256 expectedReward = (amount * 4_000) / 1_000_000;

        // Check calculated reward
        uint256 calculatedReward = stakingContract.calculateReward(
            1,
            address(0)
        );
        assertEq(calculatedReward, expectedReward);

        // Check ZEE reward calculation
        uint256 zeeReward = stakingContract.calculateReward(
            1,
            address(zeeToken)
        );
        assertEq(zeeReward, expectedReward);
    }

    /* ------------- Invariant Tests ------------- */

    function test_StakeOwnershipInvariant() public {
        // User1 stakes
        vm.prank(user1);
        stakingContract.stake((15 * MILLION) / 10, tier1ID);

        // User2 stakes
        vm.prank(user2);
        stakingContract.stake(4 * MILLION, tier2ID);

        // User3 stakes
        vm.prank(user3);
        stakingContract.stake(8 * MILLION, tier3ID);

        // Verify each stake belongs to the correct owner
        (, address owner1, , , , , , ) = stakingContract.getStake(1);
        assertEq(owner1, user1);

        (, address owner2, , , , , , ) = stakingContract.getStake(2);
        assertEq(owner2, user2);

        (, address owner3, , , , , , ) = stakingContract.getStake(3);
        assertEq(owner3, user3);

        // Verify user's stakes arrays
        uint256[] memory user1Stakes = stakingContract.getUserStakes(user1);
        assertEq(user1Stakes.length, 1);
        assertEq(user1Stakes[0], 1);

        uint256[] memory user2Stakes = stakingContract.getUserStakes(user2);
        assertEq(user2Stakes.length, 1);
        assertEq(user2Stakes[0], 2);

        uint256[] memory user3Stakes = stakingContract.getUserStakes(user3);
        assertEq(user3Stakes.length, 1);
        assertEq(user3Stakes[0], 3);
    }

    function test_ContractBalanceInvariant() public {
        // Initial contract balance
        uint256 initialBalance = kttyToken.balanceOf(address(stakingContract));

        // User1 stakes
        uint256 stakeAmount = (15 * MILLION) / 10;
        vm.prank(user1);
        stakingContract.stake(stakeAmount, tier1ID);

        // Contract balance should increase by stake amount
        uint256 afterStakeBalance = kttyToken.balanceOf(
            address(stakingContract)
        );
        assertEq(afterStakeBalance, initialBalance + stakeAmount);

        // Fast forward past lockup period
        vm.warp(block.timestamp + 31 days);

        // User1 withdraws
        vm.prank(user1);
        stakingContract.withdraw(1);

        // Contract balance should decrease by stake amount
        uint256 afterWithdrawBalance = kttyToken.balanceOf(
            address(stakingContract)
        );
        assertEq(afterWithdrawBalance, initialBalance);
    }
}
