// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IYieldStrategy} from "../interfaces/IYieldStrategy.sol";

/// @notice Minimal WallFreeX router interface for stablecoin LP
interface IWallFreeXRouter {
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);
}

/// @notice Minimal LP token interface
interface ILPToken {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

/// @title WallFreeXAdapter - WallFreeX stablecoin LP yield strategy
/// @notice Provides USDT0 liquidity to WallFreeX stablecoin pools (USDT0/AxCNH)
///         and earns swap fee yield.
contract WallFreeXAdapter is IYieldStrategy, Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable usdt0;
    IERC20 public immutable axcnh;
    IWallFreeXRouter public immutable wallfreexRouter;
    address public lpToken;
    address public router; // USDT0Hub router

    uint256 public depositedAmount; // Track deposited USDT0 (since LP is dual-sided)
    uint256 public estimatedAPY = 300; // 3% default, updated by rebalancer

    constructor(
        address _usdt0,
        address _axcnh,
        address _wallfreexRouter,
        address _lpToken,
        address _router,
        address _owner
    ) Ownable(_owner) {
        usdt0 = IERC20(_usdt0);
        axcnh = IERC20(_axcnh);
        wallfreexRouter = IWallFreeXRouter(_wallfreexRouter);
        lpToken = _lpToken;
        router = _router;

        // Approve WallFreeX router
        IERC20(_usdt0).approve(_wallfreexRouter, type(uint256).max);
        IERC20(_axcnh).approve(_wallfreexRouter, type(uint256).max);
        ILPToken(_lpToken).approve(_wallfreexRouter, type(uint256).max);
    }

    modifier onlyRouter() {
        require(msg.sender == router, "only router");
        _;
    }

    // ─── IYieldStrategy ─────────────────────────────────────────────────

    function name() external pure override returns (string memory) {
        return "WallFreeX USDT0/AxCNH LP";
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
        // Single-sided deposit: provide USDT0 only
        // In production, would pair with AxCNH for dual-sided LP
        // For hackathon, we do single-sided deposit tracking
        depositedAmount += amount;

        // If we have AxCNH balance, do a proper dual-sided LP add
        uint256 axcnhBalance = axcnh.balanceOf(address(this));
        if (axcnhBalance > 0) {
            wallfreexRouter.addLiquidity(
                address(usdt0),
                address(axcnh),
                amount,
                axcnhBalance,
                0, // accept any ratio for stablecoin pair
                0,
                address(this),
                block.timestamp + 300
            );
        }
    }

    function withdraw(uint256 amount) external override onlyRouter returns (uint256) {
        uint256 lpBalance = ILPToken(lpToken).balanceOf(address(this));

        if (lpBalance > 0) {
            // Calculate proportional LP to burn
            uint256 lpToRemove = depositedAmount > 0
                ? (lpBalance * amount) / depositedAmount
                : lpBalance;

            if (lpToRemove > lpBalance) lpToRemove = lpBalance;

            wallfreexRouter.removeLiquidity(
                address(usdt0),
                address(axcnh),
                lpToRemove,
                0,
                0,
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
        // Swap fees are auto-compounded in LP position
        // Any excess USDT0 beyond tracked deposit is yield
        uint256 balance = usdt0.balanceOf(address(this));
        if (balance > 0) {
            usdt0.safeTransfer(router, balance);
            return balance;
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
        uint256 lpBalance = ILPToken(lpToken).balanceOf(address(this));
        if (lpBalance > 0) {
            wallfreexRouter.removeLiquidity(
                address(usdt0),
                address(axcnh),
                lpBalance,
                0,
                0,
                address(this),
                block.timestamp + 300
            );
        }
        uint256 usdtBal = usdt0.balanceOf(address(this));
        if (usdtBal > 0) usdt0.safeTransfer(router, usdtBal);
        uint256 axcnhBal = axcnh.balanceOf(address(this));
        if (axcnhBal > 0) axcnh.safeTransfer(router, axcnhBal);
        depositedAmount = 0;
    }
}
