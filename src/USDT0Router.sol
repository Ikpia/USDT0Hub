// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IYieldStrategy} from "./interfaces/IYieldStrategy.sol";
import {IUSDT0OFT, MessagingFee, SendParam} from "./interfaces/IUSDT0OFT.sol";
import {IUSDT0Router} from "./interfaces/IUSDT0Router.sol";

/// @title USDT0Router - Smart yield routing vault for USDT0 on Conflux eSpace
/// @notice Accepts USDT0 deposits, routes to highest-yielding strategy, mints huUSDT0 shares.
///         Implements ERC-4626 so huUSDT0 is composable with any vault-aware protocol.
contract USDT0Router is ERC4626, Ownable, ReentrancyGuard, IUSDT0Router {
    using SafeERC20 for IERC20;
    using Math for uint256;

    // ─── Strategy Registry ──────────────────────────────────────────────
    struct StrategyInfo {
        IYieldStrategy strategy;
        bool active;
    }

    StrategyInfo[] public strategies;
    mapping(address => bool) public isRegistered;

    // ─── Rebalancer ─────────────────────────────────────────────────────
    address public rebalancer;
    uint256 public rebalanceThresholdBps; // minimum APY delta to trigger rebalance
    uint256 public lastRebalanceTimestamp;
    uint256 public constant MIN_REBALANCE_INTERVAL = 60; // 1 minute cooldown

    // ─── Allocation ─────────────────────────────────────────────────────
    /// @notice Which strategy currently holds the bulk of deposits
    uint256 public activeStrategyId;

    // ─── Idle buffer ────────────────────────────────────────────────────
    /// @notice Small buffer kept in router for instant withdrawals (bps of total)
    uint256 public idleBufferBps = 500; // 5% default

    // ─── Protocol fee ───────────────────────────────────────────────────
    uint256 public protocolFeeBps = 1000; // 10% of harvested yield
    address public feeRecipient;
    IUSDT0OFT public immutable usdt0Oft;

    constructor(
        IERC20 _usdt0,
        address _usdt0Oft,
        address _owner,
        address _rebalancer,
        uint256 _rebalanceThresholdBps
    )
        ERC20("USDT0Hub Vault Token", "huUSDT0")
        ERC4626(_usdt0)
        Ownable(_owner)
    {
        require(_usdt0Oft != address(0), "zero oft");
        usdt0Oft = IUSDT0OFT(_usdt0Oft);
        rebalancer = _rebalancer;
        rebalanceThresholdBps = _rebalanceThresholdBps;
        feeRecipient = _owner;
        IERC20(address(_usdt0)).approve(_usdt0Oft, type(uint256).max);
    }

    // ─── Modifiers ──────────────────────────────────────────────────────

    modifier onlyRebalancer() {
        require(msg.sender == rebalancer || msg.sender == owner(), "not rebalancer");
        _;
    }

    // ─── ERC-4626 overrides ─────────────────────────────────────────────

    /// @notice Total assets = idle balance in router + sum of all strategy deposits
    function totalAssets() public view override(ERC4626, IUSDT0Router) returns (uint256) {
        uint256 idle = IERC20(asset()).balanceOf(address(this));
        uint256 deployed;
        for (uint256 i; i < strategies.length; i++) {
            if (strategies[i].active) {
                deployed += strategies[i].strategy.totalDeposited();
            }
        }
        return idle + deployed;
    }

    function deposit(uint256 assets, address receiver)
        public
        override(ERC4626)
        nonReentrant
        returns (uint256 shares)
    {
        shares = super.deposit(assets, receiver);
        _deployIdleFunds();
        emit Deposited(receiver, assets, shares);
    }

    /// @notice Convenience wrapper matching IUSDT0Router interface
    function deposit(uint256 assets) external override returns (uint256 shares) {
        return deposit(assets, msg.sender);
    }

    function withdraw(uint256 assets, address receiver, address _owner)
        public
        override(ERC4626)
        nonReentrant
        returns (uint256 shares)
    {
        _ensureLiquidity(assets);
        shares = super.withdraw(assets, receiver, _owner);
        emit Withdrawn(receiver, shares, assets);
    }

    /// @notice Convenience wrapper matching IUSDT0Router interface
    function withdraw(uint256 shares) external override returns (uint256 amount) {
        amount = redeem(shares, msg.sender, msg.sender);
    }

    function redeem(uint256 shares, address receiver, address _owner)
        public
        override(ERC4626)
        nonReentrant
        returns (uint256 assets)
    {
        assets = previewRedeem(shares);
        _ensureLiquidity(assets);
        assets = super.redeem(shares, receiver, _owner);
    }

    // ─── Strategy Management ────────────────────────────────────────────

    function registerStrategy(address _strategy) external override onlyOwner {
        require(!isRegistered[_strategy], "already registered");
        require(IYieldStrategy(_strategy).asset() == asset(), "wrong asset");

        strategies.push(StrategyInfo({
            strategy: IYieldStrategy(_strategy),
            active: true
        }));
        isRegistered[_strategy] = true;

        // Approve strategy to pull tokens
        IERC20(asset()).approve(_strategy, type(uint256).max);

        emit StrategyRegistered(strategies.length - 1, _strategy);
    }

    function removeStrategy(uint256 strategyId) external override onlyOwner {
        require(strategyId < strategies.length, "invalid id");
        StrategyInfo storage info = strategies[strategyId];
        require(info.active, "already inactive");

        // Withdraw everything from the strategy
        uint256 deposited = info.strategy.totalDeposited();
        if (deposited > 0) {
            info.strategy.withdraw(deposited);
        }

        info.active = false;
        isRegistered[address(info.strategy)] = false;

        // Revoke approval
        IERC20(asset()).approve(address(info.strategy), 0);

        // If this was the active strategy, reset
        if (activeStrategyId == strategyId) {
            activeStrategyId = _findBestStrategy();
        }

        emit StrategyRemoved(strategyId, address(info.strategy));
    }

    function getStrategyCount() external view override returns (uint256) {
        return strategies.length;
    }

    // ─── Rebalancing ────────────────────────────────────────────────────

    function rebalance() external override onlyRebalancer {
        require(
            block.timestamp >= lastRebalanceTimestamp + MIN_REBALANCE_INTERVAL,
            "rebalance cooldown"
        );

        // Harvest yield from all strategies
        uint256 totalHarvested;
        for (uint256 i; i < strategies.length; i++) {
            if (strategies[i].active) {
                totalHarvested += strategies[i].strategy.harvest();
            }
        }

        // Take protocol fee from harvested yield
        if (totalHarvested > 0 && feeRecipient != address(0)) {
            uint256 fee = (totalHarvested * protocolFeeBps) / 10_000;
            if (fee > 0) {
                IERC20(asset()).safeTransfer(feeRecipient, fee);
            }
            emit YieldHarvested(totalHarvested);
        }

        // Find best strategy
        uint256 bestId = _findBestStrategy();

        // If best strategy changed, migrate funds
        if (bestId != activeStrategyId && strategies.length > 0) {
            _migrateToStrategy(bestId);
        }

        lastRebalanceTimestamp = block.timestamp;
        emit Rebalanced(msg.sender, block.timestamp);
    }

    function getBestStrategy() external view override returns (uint256 strategyId, uint256 apy) {
        strategyId = _findBestStrategy();
        if (strategies.length > 0 && strategies[strategyId].active) {
            apy = strategies[strategyId].strategy.currentAPY();
        }
    }

    // ─── Admin ──────────────────────────────────────────────────────────

    function setRebalancer(address _rebalancer) external onlyOwner {
        rebalancer = _rebalancer;
    }

    function setRebalanceThreshold(uint256 _bps) external onlyOwner {
        require(_bps <= 10_000, "invalid bps");
        rebalanceThresholdBps = _bps;
    }

    function setIdleBufferBps(uint256 _bps) external onlyOwner {
        require(_bps <= 5_000, "max 50%");
        idleBufferBps = _bps;
    }

    function setProtocolFee(uint256 _bps, address _recipient) external onlyOwner {
        require(_bps <= 3_000, "max 30%");
        protocolFeeBps = _bps;
        feeRecipient = _recipient;
    }

    function quoteUsdt0Bridge(
        uint32 dstEid,
        bytes32 recipient,
        uint256 amount,
        uint256 minAmountReceived,
        bytes calldata extraOptions,
        bytes calldata composeMsg,
        bytes calldata oftCmd
    ) external view override returns (uint256 nativeFee, uint256 lzTokenFee) {
        SendParam memory sendParam = _buildSendParam(
            dstEid,
            recipient,
            amount,
            minAmountReceived,
            extraOptions,
            composeMsg,
            oftCmd
        );
        MessagingFee memory fee = usdt0Oft.quoteSend(sendParam, false);
        return (fee.nativeFee, fee.lzTokenFee);
    }

    function bridgeUsdt0(
        uint32 dstEid,
        bytes32 recipient,
        uint256 amount,
        uint256 minAmountReceived,
        bytes calldata extraOptions,
        bytes calldata composeMsg,
        bytes calldata oftCmd
    ) external payable override onlyOwner nonReentrant {
        require(amount > 0, "zero amount");
        _ensureLiquidity(amount);

        SendParam memory sendParam = _buildSendParam(
            dstEid,
            recipient,
            amount,
            minAmountReceived,
            extraOptions,
            composeMsg,
            oftCmd
        );
        MessagingFee memory fee = usdt0Oft.quoteSend(sendParam, false);
        require(msg.value >= fee.nativeFee, "insufficient fee");

        usdt0Oft.send{value: msg.value}(sendParam, fee, msg.sender);
        emit Usdt0Bridged(dstEid, recipient, amount, minAmountReceived, fee.nativeFee);
    }

    // ─── Internal ───────────────────────────────────────────────────────

    function _deployIdleFunds() internal {
        if (strategies.length == 0) return;

        uint256 total = totalAssets();
        uint256 idle = IERC20(asset()).balanceOf(address(this));
        uint256 targetIdle = (total * idleBufferBps) / 10_000;

        if (idle > targetIdle) {
            uint256 toDeploy = idle - targetIdle;
            StrategyInfo storage best = strategies[activeStrategyId];
            if (best.active && best.strategy.depositEnabled()) {
                IERC20(asset()).safeTransfer(address(best.strategy), toDeploy);
                best.strategy.deposit(toDeploy);
            }
        }
    }

    function _ensureLiquidity(uint256 amount) internal {
        uint256 idle = IERC20(asset()).balanceOf(address(this));
        if (idle >= amount) return;

        uint256 needed = amount - idle;

        // Pull from active strategy first
        if (strategies.length > 0 && strategies[activeStrategyId].active) {
            uint256 available = strategies[activeStrategyId].strategy.totalDeposited();
            uint256 pullAmount = needed < available ? needed : available;
            if (pullAmount > 0) {
                strategies[activeStrategyId].strategy.withdraw(pullAmount);
                needed -= pullAmount;
            }
        }

        // If still short, pull from other strategies
        if (needed > 0) {
            for (uint256 i; i < strategies.length && needed > 0; i++) {
                if (i == activeStrategyId || !strategies[i].active) continue;
                uint256 available = strategies[i].strategy.totalDeposited();
                uint256 pullAmount = needed < available ? needed : available;
                if (pullAmount > 0) {
                    strategies[i].strategy.withdraw(pullAmount);
                    needed -= pullAmount;
                }
            }
        }
    }

    function _findBestStrategy() internal view returns (uint256 bestId) {
        uint256 bestApy;
        for (uint256 i; i < strategies.length; i++) {
            if (!strategies[i].active) continue;
            uint256 apy = strategies[i].strategy.currentAPY();
            if (apy > bestApy) {
                bestApy = apy;
                bestId = i;
            }
        }
    }

    function _migrateToStrategy(uint256 newId) internal {
        if (!strategies[newId].active) return;

        // Check APY delta exceeds threshold
        uint256 currentApy = strategies[activeStrategyId].active
            ? strategies[activeStrategyId].strategy.currentAPY()
            : 0;
        uint256 newApy = strategies[newId].strategy.currentAPY();

        if (newApy <= currentApy + rebalanceThresholdBps) return;

        // Withdraw from current strategy
        if (strategies[activeStrategyId].active) {
            uint256 deposited = strategies[activeStrategyId].strategy.totalDeposited();
            if (deposited > 0) {
                strategies[activeStrategyId].strategy.withdraw(deposited);
            }
        }

        // Deploy to new strategy
        uint256 total = IERC20(asset()).balanceOf(address(this));
        uint256 targetIdle = (total * idleBufferBps) / 10_000;
        uint256 toDeploy = total > targetIdle ? total - targetIdle : 0;

        if (toDeploy > 0 && strategies[newId].strategy.depositEnabled()) {
            IERC20(asset()).safeTransfer(address(strategies[newId].strategy), toDeploy);
            strategies[newId].strategy.deposit(toDeploy);
        }

        activeStrategyId = newId;
    }

    function _buildSendParam(
        uint32 dstEid,
        bytes32 recipient,
        uint256 amount,
        uint256 minAmountReceived,
        bytes calldata extraOptions,
        bytes calldata composeMsg,
        bytes calldata oftCmd
    ) internal pure returns (SendParam memory) {
        require(dstEid != 0, "zero dstEid");
        require(recipient != bytes32(0), "zero recipient");
        require(minAmountReceived <= amount, "min > amount");
        return SendParam({
            dstEid: dstEid,
            to: recipient,
            amountLD: amount,
            minAmountLD: minAmountReceived,
            extraOptions: extraOptions,
            composeMsg: composeMsg,
            oftCmd: oftCmd
        });
    }

    /// @notice ERC-4626 uses 6 decimals to match USDT0
    function decimals() public pure override(ERC4626) returns (uint8) {
        return 6;
    }
}
