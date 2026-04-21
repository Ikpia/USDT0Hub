// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IYieldStrategy} from "../interfaces/IYieldStrategy.sol";

/// @notice Minimal DEX router interface for USDT0 → CFX swap path
interface IDEXRouter {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

/// @notice Minimal SHUI staking interface
interface ISHUIStaking {
    function stake(uint256 amount) external;
    function unstake(uint256 amount) external;
    function claimRewards() external returns (uint256);
    function balanceOf(address user) external view returns (uint256);
    function earned(address user) external view returns (uint256);
}

/// @title SHUIFinanceAdapter - SHUI Finance yield strategy via CFX swap
/// @notice Swaps USDT0 → CFX → stakes in SHUI Finance for staking yield.
///         Reverses the path on withdrawal: unstake → swap CFX → USDT0.
contract SHUIFinanceAdapter is IYieldStrategy, Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable usdt0;
    IERC20 public immutable wcfx;
    IDEXRouter public immutable dexRouter;
    ISHUIStaking public immutable shuiStaking;

    address public router; // USDT0Hub router
    uint256 public depositedAmount; // Track USDT0 value deposited
    uint256 public estimatedAPY = 500; // 5% default

    address[] public swapPathIn;  // USDT0 → WCFX
    address[] public swapPathOut; // WCFX → USDT0

    constructor(
        address _usdt0,
        address _wcfx,
        address _dexRouter,
        address _shuiStaking,
        address _router,
        address _owner
    ) Ownable(_owner) {
        usdt0 = IERC20(_usdt0);
        wcfx = IERC20(_wcfx);
        dexRouter = IDEXRouter(_dexRouter);
        shuiStaking = ISHUIStaking(_shuiStaking);
        router = _router;

        swapPathIn = new address[](2);
        swapPathIn[0] = _usdt0;
        swapPathIn[1] = _wcfx;

        swapPathOut = new address[](2);
        swapPathOut[0] = _wcfx;
        swapPathOut[1] = _usdt0;

        IERC20(_usdt0).approve(_dexRouter, type(uint256).max);
        IERC20(_wcfx).approve(_dexRouter, type(uint256).max);
        IERC20(_wcfx).approve(_shuiStaking, type(uint256).max);
    }

    modifier onlyRouter() {
        require(msg.sender == router, "only router");
        _;
    }

    // ─── IYieldStrategy ─────────────────────────────────────────────────

    function name() external pure override returns (string memory) {
        return "SHUI Finance CFX Staking (via swap)";
    }

    function asset() external view override returns (address) {
        return address(usdt0);
    }

    function totalDeposited() external view override returns (uint256) {
        return depositedAmount;
    }

    function currentAPY() external view override returns (uint256) {
        return estimatedAPY;
    }

    function deposit(uint256 amount) external override onlyRouter {
        depositedAmount += amount;

        // Swap USDT0 → WCFX
        uint256[] memory amounts = dexRouter.swapExactTokensForTokens(
            amount,
            0, // Accept any amount for hackathon (production: use oracle price with slippage)
            swapPathIn,
            address(this),
            block.timestamp + 300
        );

        // Stake WCFX in SHUI
        shuiStaking.stake(amounts[1]);
    }

    function withdraw(uint256 amount) external override onlyRouter returns (uint256) {
        // Calculate proportional WCFX to unstake
        uint256 stakedBalance = shuiStaking.balanceOf(address(this));
        uint256 unstakeAmount = depositedAmount > 0
            ? (stakedBalance * amount) / depositedAmount
            : stakedBalance;

        if (unstakeAmount > stakedBalance) unstakeAmount = stakedBalance;

        // Unstake and swap back
        shuiStaking.unstake(unstakeAmount);

        uint256 wcfxBalance = wcfx.balanceOf(address(this));
        if (wcfxBalance > 0) {
            dexRouter.swapExactTokensForTokens(
                wcfxBalance,
                0,
                swapPathOut,
                address(this),
                block.timestamp + 300
            );
        }

        uint256 balance = usdt0.balanceOf(address(this));
        uint256 toSend = amount < balance ? amount : balance;

        if (toSend > depositedAmount) {
            depositedAmount = 0;
        } else {
            depositedAmount -= toSend;
        }

        usdt0.safeTransfer(router, toSend);
        return toSend;
    }

    function harvest() external override onlyRouter returns (uint256) {
        uint256 rewards = shuiStaking.claimRewards();
        if (rewards > 0) {
            // Swap rewards (WCFX) back to USDT0
            uint256 wcfxBalance = wcfx.balanceOf(address(this));
            if (wcfxBalance > 0) {
                dexRouter.swapExactTokensForTokens(
                    wcfxBalance,
                    0,
                    swapPathOut,
                    address(this),
                    block.timestamp + 300
                );
                uint256 harvested = usdt0.balanceOf(address(this));
                usdt0.safeTransfer(router, harvested);
                return harvested;
            }
        }
        return 0;
    }

    function depositEnabled() external pure override returns (bool) {
        return true;
    }

    // ─── Admin ──────────────────────────────────────────────────────────

    function setRouter(address _router) external onlyOwner {
        router = _router;
    }

    function setEstimatedAPY(uint256 _apy) external onlyOwner {
        estimatedAPY = _apy;
    }

    function emergencyWithdraw() external onlyOwner {
        uint256 staked = shuiStaking.balanceOf(address(this));
        if (staked > 0) shuiStaking.unstake(staked);

        uint256 wcfxBal = wcfx.balanceOf(address(this));
        if (wcfxBal > 0) {
            dexRouter.swapExactTokensForTokens(
                wcfxBal, 0, swapPathOut, address(this), block.timestamp + 300
            );
        }

        uint256 usdtBal = usdt0.balanceOf(address(this));
        if (usdtBal > 0) usdt0.safeTransfer(router, usdtBal);
        depositedAmount = 0;
    }
}
