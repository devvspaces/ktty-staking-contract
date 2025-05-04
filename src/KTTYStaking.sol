// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title KTTYStaking
 * @dev A staking contract for KTTY token with multiple tiers and reward tokens
 */
contract KTTYStaking is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Math for uint256;

    // Custom errors
    error InvalidTier();
    error InsufficientBalance();
    error StakingLocked();
    error StakingNotLocked();
    error InvalidAmount();
    error StakeNotFound();
    error LockupNotCompleted();
    error UnauthorizedWithdrawal();
    error TokenNotRegistered();
    error InvalidRewardRate();
    error RewardAlreadyClaimed();
    error RewardAmountTooLow();
    error DuplicateRewardToken();
    error InvalidLockupPeriod();
    error EmergencyWithdrawalFailed();
    error InvalidStakeId();
    error InvalidRange();
    error TierAlreadyExists();
    error TierDoesNotExist();

    // Roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant TIER_MANAGER_ROLE = keccak256("TIER_MANAGER_ROLE");
    bytes32 public constant FUND_MANAGER_ROLE = keccak256("FUND_MANAGER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    // Staking tokens and rewards
    IERC20 public kttyToken;

    // Tier structure
    struct Tier {
        uint256 id;
        string name;
        uint256 minStake; // Minimum KTTY required
        uint256 maxStake; // Maximum KTTY allowed (0 = unlimited)
        uint256 lockupPeriod; // In seconds
        uint256 apy; // Annual percentage yield (scaled by 1e6, so 10% = 100000)
        bool isActive;
        address[] rewardTokens; // Additional reward tokens beyond KTTY
    }

    // Stake structure
    struct Stake {
        uint256 id;
        address owner;
        uint256 amount;
        uint256 tierId;
        uint256 startTime;
        uint256 endTime;
        bool hasWithdrawn;
        bool hasClaimedRewards; // Single flag for all rewards
    }

    // Registered reward tokens
    struct RewardToken {
        string symbol;
        address tokenAddress;
        uint256 rewardRate; // Rate relative to KTTY reward (scaled by 1e6)
        bool isActive;
    }

    // Counters
    uint256 private _stakeIdCounter;
    uint256 private _tierIdCounter;

    // Mapping of tier ID to tier details
    mapping(uint256 => Tier) public tiers;

    // Array of tier IDs for iteration
    uint256[] public tierIds;

    // Mapping of token address to reward token details
    mapping(address => RewardToken) public rewardTokens;

    // Array of reward token addresses for iteration
    address[] public rewardTokenAddresses;

    // Mapping from stake ID to stake
    mapping(uint256 => Stake) private _stakes;

    // Mapping from owner to their stake IDs
    mapping(address => uint256[]) private _ownerStakes;

    // Events
    event TierCreated(
        uint256 indexed tierId,
        string name,
        uint256 minStake,
        uint256 lockupPeriod,
        uint256 apy
    );
    event TierUpdated(
        uint256 indexed tierId,
        string name,
        uint256 minStake,
        uint256 lockupPeriod,
        uint256 apy,
        bool isActive
    );
    event TierRewardTokenAdded(
        uint256 indexed tierId,
        address indexed tokenAddress
    );
    event TierRewardTokenRemoved(
        uint256 indexed tierId,
        address indexed tokenAddress
    );

    event RewardTokenRegistered(
        address indexed tokenAddress,
        string symbol,
        uint256 rewardRate
    );
    event RewardTokenUpdated(
        address indexed tokenAddress,
        uint256 rewardRate,
        bool isActive
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
    event AllRewardsClaimed(uint256 indexed stakeId, address indexed owner);

    event EmergencyWithdrawal(
        address indexed token,
        address indexed to,
        uint256 amount
    );
    event ContractPaused(address indexed by);
    event ContractUnpaused(address indexed by);

    /**
     * @dev Constructor
     * @param _kttyToken Address of the KTTY token
     */
    constructor(address _kttyToken) {
        require(_kttyToken != address(0), "KTTY token address cannot be zero");

        kttyToken = IERC20(_kttyToken);

        // Set up roles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(TIER_MANAGER_ROLE, msg.sender);
        _grantRole(FUND_MANAGER_ROLE, msg.sender);
        _grantRole(EMERGENCY_ROLE, msg.sender);

        // Initialize counters
        _stakeIdCounter = 1;
        _tierIdCounter = 1;
    }

    /**
     * @dev Pause the contract
     * Only ADMIN or EMERGENCY role can call this
     */
    function pause() external {
        require(
            hasRole(ADMIN_ROLE, msg.sender) ||
                hasRole(EMERGENCY_ROLE, msg.sender),
            "Caller must have admin or emergency role"
        );
        _pause();
        emit ContractPaused(msg.sender);
    }

    /**
     * @dev Unpause the contract
     * Only ADMIN role can call this
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
        emit ContractUnpaused(msg.sender);
    }

    /**
     * @dev Add a new tier
     * @param name Tier name
     * @param minStake Minimum KTTY to stake
     * @param maxStake Maximum KTTY allowed (0 = unlimited)
     * @param lockupPeriod Lockup period in days
     * @param apy Fixed percentage yield (scaled by 1e6, so 0.2% = 2000)
     */
    function addTier(
        string memory name,
        uint256 minStake,
        uint256 maxStake,
        uint256 lockupPeriod,
        uint256 apy
    ) external onlyRole(TIER_MANAGER_ROLE) {
        if (minStake == 0) revert InvalidAmount();
        if (lockupPeriod == 0) revert InvalidLockupPeriod();
        if (maxStake > 0 && maxStake <= minStake) revert InvalidRange();

        // Generate new tier ID
        uint256 id = _tierIdCounter++;

        // Convert lockup period from days to seconds
        uint256 lockupInSeconds = lockupPeriod * 1 days;

        tiers[id] = Tier({
            id: id,
            name: name,
            minStake: minStake,
            maxStake: maxStake,
            lockupPeriod: lockupInSeconds,
            apy: apy,
            isActive: true,
            rewardTokens: new address[](0)
        });

        tierIds.push(id);

        emit TierCreated(id, name, minStake, lockupInSeconds, apy);
    }

    /**
     * @dev Update an existing tier
     * @param id Tier ID
     * @param name New tier name
     * @param minStake New minimum KTTY to stake
     * @param maxStake New maximum KTTY allowed (0 = unlimited)
     * @param lockupPeriod New lockup period in days
     * @param apy New annual percentage yield
     * @param isActive Whether the tier is active
     */
    function updateTier(
        uint256 id,
        string memory name,
        uint256 minStake,
        uint256 maxStake,
        uint256 lockupPeriod,
        uint256 apy,
        bool isActive
    ) external onlyRole(TIER_MANAGER_ROLE) {
        if (tiers[id].minStake == 0) revert TierDoesNotExist();
        if (minStake == 0) revert InvalidAmount();
        if (lockupPeriod == 0) revert InvalidLockupPeriod();
        if (maxStake > 0 && maxStake <= minStake) revert InvalidRange();

        // Convert lockup period from days to seconds
        uint256 lockupInSeconds = lockupPeriod * 1 days;

        // Keep the existing reward tokens
        address[] memory rewardTokens = tiers[id].rewardTokens;

        tiers[id] = Tier({
            id: id,
            name: name,
            minStake: minStake,
            maxStake: maxStake,
            lockupPeriod: lockupInSeconds,
            apy: apy,
            isActive: isActive,
            rewardTokens: rewardTokens
        });

        emit TierUpdated(id, name, minStake, lockupInSeconds, apy, isActive);
    }

    /**
     * @dev Add a reward token to a tier
     * @param tierId Tier ID
     * @param tokenAddress Address of the token to add
     */
    function addRewardTokenToTier(
        uint256 tierId,
        address tokenAddress
    ) external onlyRole(TIER_MANAGER_ROLE) {
        if (tiers[tierId].minStake == 0) revert TierDoesNotExist();
        if (rewardTokens[tokenAddress].tokenAddress == address(0))
            revert TokenNotRegistered();

        // Check if the token is already in the tier
        for (uint256 i = 0; i < tiers[tierId].rewardTokens.length; i++) {
            if (tiers[tierId].rewardTokens[i] == tokenAddress)
                revert DuplicateRewardToken();
        }

        tiers[tierId].rewardTokens.push(tokenAddress);

        emit TierRewardTokenAdded(tierId, tokenAddress);
    }

    /**
     * @dev Remove a reward token from a tier
     * @param tierId Tier ID
     * @param tokenAddress Address of the token to remove
     */
    function removeRewardTokenFromTier(
        uint256 tierId,
        address tokenAddress
    ) external onlyRole(TIER_MANAGER_ROLE) {
        if (tiers[tierId].minStake == 0) revert TierDoesNotExist();

        bool found = false;
        uint256 tokenIndex;

        for (uint256 i = 0; i < tiers[tierId].rewardTokens.length; i++) {
            if (tiers[tierId].rewardTokens[i] == tokenAddress) {
                found = true;
                tokenIndex = i;
                break;
            }
        }

        if (!found) revert TokenNotRegistered();

        // Remove token by swapping with the last element and then removing the last element
        if (tokenIndex != tiers[tierId].rewardTokens.length - 1) {
            tiers[tierId].rewardTokens[tokenIndex] = tiers[tierId].rewardTokens[
                tiers[tierId].rewardTokens.length - 1
            ];
        }
        tiers[tierId].rewardTokens.pop();

        emit TierRewardTokenRemoved(tierId, tokenAddress);
    }

    /**
     * @dev Register a new reward token
     * @param tokenAddress Address of the token
     * @param symbol Symbol of the token
     * @param rewardRate Reward rate relative to KTTY (scaled by 1e6)
     */
    function registerRewardToken(
        address tokenAddress,
        string memory symbol,
        uint256 rewardRate
    ) external onlyRole(FUND_MANAGER_ROLE) {
        if (tokenAddress == address(0)) revert InvalidAmount();
        if (rewardRate == 0) revert InvalidRewardRate();
        if (rewardTokens[tokenAddress].tokenAddress != address(0))
            revert DuplicateRewardToken();

        rewardTokens[tokenAddress] = RewardToken({
            symbol: symbol,
            tokenAddress: tokenAddress,
            rewardRate: rewardRate,
            isActive: true
        });

        rewardTokenAddresses.push(tokenAddress);

        emit RewardTokenRegistered(tokenAddress, symbol, rewardRate);
    }

    /**
     * @dev Update a reward token
     * @param tokenAddress Address of the token
     * @param rewardRate New reward rate
     * @param isActive Whether the token is active
     */
    function updateRewardToken(
        address tokenAddress,
        uint256 rewardRate,
        bool isActive
    ) external onlyRole(FUND_MANAGER_ROLE) {
        if (rewardTokens[tokenAddress].tokenAddress == address(0))
            revert TokenNotRegistered();
        if (rewardRate == 0) revert InvalidRewardRate();

        rewardTokens[tokenAddress].rewardRate = rewardRate;
        rewardTokens[tokenAddress].isActive = isActive;

        emit RewardTokenUpdated(tokenAddress, rewardRate, isActive);
    }

    /**
     * @dev Create a new stake
     * @param amount Amount of KTTY to stake
     * @param tierId Tier ID
     */
    function stake(
        uint256 amount,
        uint256 tierId
    ) external nonReentrant whenNotPaused {
        // Validate inputs
        if (amount == 0) revert InvalidAmount();

        Tier storage tier = tiers[tierId];
        if (tier.minStake == 0) revert TierDoesNotExist();
        if (!tier.isActive) revert InvalidTier();
        if (amount < tier.minStake) revert InvalidAmount();
        if (tier.maxStake > 0 && amount > tier.maxStake) revert InvalidAmount();

        // Transfer KTTY tokens from user to this contract
        uint256 balanceBefore = kttyToken.balanceOf(address(this));
        kttyToken.safeTransferFrom(msg.sender, address(this), amount);
        uint256 balanceAfter = kttyToken.balanceOf(address(this));

        // Verify the transfer
        if (balanceAfter - balanceBefore != amount)
            revert InsufficientBalance();

        // Create the stake
        uint256 stakeId = _stakeIdCounter++;
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + tier.lockupPeriod;

        Stake storage newStake = _stakes[stakeId];
        newStake.id = stakeId;
        newStake.owner = msg.sender;
        newStake.amount = amount;
        newStake.tierId = tierId;
        newStake.startTime = startTime;
        newStake.endTime = endTime;
        newStake.hasWithdrawn = false;

        // Add to owner's stakes
        _ownerStakes[msg.sender].push(stakeId);

        emit Staked(stakeId, msg.sender, amount, tierId, startTime, endTime);
    }

    /**
     * @dev Withdraw staked KTTY
     * @param stakeId ID of the stake to withdraw
     */
    function withdraw(uint256 stakeId) external nonReentrant {
        Stake storage userStake = _stakes[stakeId];

        // Validate stake
        if (userStake.id == 0 || userStake.id != stakeId)
            revert StakeNotFound();
        if (userStake.owner != msg.sender) revert UnauthorizedWithdrawal();
        if (userStake.hasWithdrawn) revert StakingNotLocked();

        // Check if lockup period has ended
        if (block.timestamp < userStake.endTime && !paused())
            revert LockupNotCompleted();

        // Mark as withdrawn
        userStake.hasWithdrawn = true;

        // Transfer KTTY back to user
        kttyToken.safeTransfer(msg.sender, userStake.amount);

        emit StakeWithdrawn(stakeId, msg.sender, userStake.amount);
    }

    /**
     * @dev Claim all rewards and withdraw stake
     * @param stakeId ID of the stake
     */
    function claimRewardsAndWithdraw(uint256 stakeId) external nonReentrant {
        Stake storage userStake = _stakes[stakeId];

        // Validate stake
        if (userStake.id == 0 || userStake.id != stakeId)
            revert StakeNotFound();
        if (userStake.owner != msg.sender) revert UnauthorizedWithdrawal();

        // Check if lockup period has ended
        if (block.timestamp < userStake.endTime) revert LockupNotCompleted();

        // Check if rewards already claimed
        if (userStake.hasClaimedRewards) revert RewardAlreadyClaimed();

        // Check if principal already withdrawn
        if (userStake.hasWithdrawn) revert StakingNotLocked();

        // Mark as claimed and withdrawn
        userStake.hasClaimedRewards = true;
        userStake.hasWithdrawn = true;

        // Get tier information
        Tier storage tier = tiers[userStake.tierId];

        // Transfer principal back to user
        kttyToken.safeTransfer(msg.sender, userStake.amount);

        // Calculate and transfer KTTY rewards
        uint256 kttyRewardAmount = (userStake.amount * tier.apy) / 1e6;
        if (kttyRewardAmount > 0) {
            kttyToken.safeTransfer(msg.sender, kttyRewardAmount);
            emit RewardClaimed(
                stakeId,
                msg.sender,
                address(kttyToken),
                kttyRewardAmount
            );
        }

        // Transfer additional rewards for all tokens in tier
        for (uint256 i = 0; i < tier.rewardTokens.length; i++) {
            address tokenAddress = tier.rewardTokens[i];
            if (rewardTokens[tokenAddress].isActive) {
                uint256 tokenRewardAmount = (userStake.amount * tier.apy) / 1e6;
                if (tokenRewardAmount > 0) {
                    IERC20(tokenAddress).safeTransfer(
                        msg.sender,
                        tokenRewardAmount
                    );
                    emit RewardClaimed(
                        stakeId,
                        msg.sender,
                        tokenAddress,
                        tokenRewardAmount
                    );
                }
            }
        }

        emit StakeWithdrawn(stakeId, msg.sender, userStake.amount);
    }

    /**
     * @dev Check if a stake has claimed rewards
     * @param stakeId ID of the stake
     * @return True if rewards have been claimed
     */
    function hasClaimedRewards(uint256 stakeId) external view returns (bool) {
        Stake storage userStake = _stakes[stakeId];
        if (userStake.id == 0) revert StakeNotFound();

        return userStake.hasClaimedRewards;
    }

    /**
     * @dev Calculate reward amount for a stake and token
     * @param stakeId ID of the stake
     * @param tokenAddress Address of the reward token (address(0) for KTTY)
     * @return Amount of reward tokens
     */
    function calculateReward(
        uint256 stakeId,
        address tokenAddress
    ) external view returns (uint256) {
        Stake storage userStake = _stakes[stakeId];
        if (userStake.id == 0) revert StakeNotFound();

        // Check if rewards have already been claimed
        if (userStake.hasClaimedRewards) return 0;

        // Get tier information
        Tier storage tier = tiers[userStake.tierId];

        // Use KTTY token for base rewards
        address rewardToken = tokenAddress == address(0)
            ? address(kttyToken)
            : tokenAddress;

        // For KTTY token or any other token, it's a fixed percentage of the staked amount
        if (rewardToken == address(kttyToken)) {
            // Calculate fixed KTTY rewards
            return (userStake.amount * tier.apy) / 1e6;
        } else {
            // Validate additional reward token
            if (rewardTokens[rewardToken].tokenAddress == address(0)) return 0;
            if (!rewardTokens[rewardToken].isActive) return 0;

            // Check if token is in the tier's reward list
            bool isInTier = false;
            for (uint256 i = 0; i < tier.rewardTokens.length; i++) {
                if (tier.rewardTokens[i] == rewardToken) {
                    isInTier = true;
                    break;
                }
            }
            if (!isInTier) return 0;

            // Calculate fixed percentage reward
            return (userStake.amount * tier.apy) / 1e6;
        }
    }

    /**
     * @dev Emergency withdraw tokens from the contract
     * @param tokenAddress Address of the token to withdraw
     * @param to Address to send tokens to
     * @param amount Amount of tokens to withdraw
     */
    function emergencyWithdraw(
        address tokenAddress,
        address to,
        uint256 amount
    ) external onlyRole(EMERGENCY_ROLE) {
        if (to == address(0)) revert InvalidAmount();
        if (amount == 0) revert InvalidAmount();

        IERC20 token = IERC20(tokenAddress);
        uint256 balance = token.balanceOf(address(this));

        if (amount > balance) revert InsufficientBalance();

        bool success = token.transfer(to, amount);
        if (!success) revert EmergencyWithdrawalFailed();

        emit EmergencyWithdrawal(tokenAddress, to, amount);
    }

    /**
     * @dev Get the number of tiers
     * @return Number of tiers
     */
    function getTierCount() external view returns (uint256) {
        return tierIds.length;
    }

    /**
     * @dev Get the number of reward tokens
     * @return Number of reward tokens
     */
    function getRewardTokenCount() external view returns (uint256) {
        return rewardTokenAddresses.length;
    }

    /**
     * @dev Get the reward tokens for a tier
     * @param tierId Tier ID
     * @return Array of token addresses
     */
    function getTierRewardTokens(
        uint256 tierId
    ) external view returns (address[] memory) {
        return tiers[tierId].rewardTokens;
    }

    /**
     * @dev Get a user's stakes
     * @param owner Address of the stake owner
     * @return Array of stake IDs
     */
    function getUserStakes(
        address owner
    ) external view returns (uint256[] memory) {
        return _ownerStakes[owner];
    }

    /**
     * @dev Get stake details
     * @param stakeId Stake ID
     * @return id ID of the stake
     * @return owner Owner of the stake
     * @return amount Amount staked
     * @return tierId Tier ID
     * @return startTime Start time of the stake
     * @return endTime End time of the stake
     * @return hasWithdrawn Whether the stake has been withdrawn
     * @return _hasClaimedRewards Whether rewards have been claimed
     */
    function getStake(
        uint256 stakeId
    )
        external
        view
        returns (
            uint256 id,
            address owner,
            uint256 amount,
            uint256 tierId,
            uint256 startTime,
            uint256 endTime,
            bool hasWithdrawn,
            bool _hasClaimedRewards
        )
    {
        Stake storage _stake = _stakes[stakeId];
        if (_stake.id == 0) revert StakeNotFound();

        return (
            _stake.id,
            _stake.owner,
            _stake.amount,
            _stake.tierId,
            _stake.startTime,
            _stake.endTime,
            _stake.hasWithdrawn,
            _stake.hasClaimedRewards
        );
    }

    /**
     * @dev Check if a stake exists
     * @param stakeId Stake ID
     * @return True if the stake exists
     */
    function stakeExists(uint256 stakeId) external view returns (bool) {
        return _stakes[stakeId].id != 0;
    }
}
