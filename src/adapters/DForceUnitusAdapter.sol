// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IYieldStrategy} from "../interfaces/IYieldStrategy.sol";

/// @notice Minimal dForce Unitus lending interface
interface IiToken {
    function mint(address recipient, uint256 mintAmount) external;
    function redeem(address from, uint256 redeemTokens) external;
    function redeemUnderlying(address from, uint256 redeemAmount) external;
    function balanceOf(address owner) external view returns (uint256);
    function exchangeRateStored() external view returns (uint256);
    function supplyRatePerBlock() external view returns (uint256);
    function underlying() external view returns (address);
}

/// @title DForceUnitusAdapter - dForce Unitus USDT0 lending strategy
/// @notice Deposits USDT0 into dForce Unitus lending market to earn supply APY.
///         Wraps the iToken (interest-bearing token) interface.
contract DForceUnitusAdapter is IYieldStrategy, Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable usdt0;
    IiToken public immutable iToken; // dForce iUSDT0
    address public router;

    /// @dev Approximate blocks per year on Conflux eSpace (1.25s block time)
    uint256 public constant BLOCKS_PER_YEAR = 25_228_800;

    constructor(
        address _usdt0,
        address _iToken,
        address _router,
        address _owner
    ) Ownable(_owner) {
        usdt0 = IERC20(_usdt0);
        iToken = IiToken(_iToken);
        router = _router;

        // Approve iToken to spend USDT0
        IERC20(_usdt0).approve(_iToken, type(uint256).max);
    }

    modifier onlyRouter() {
        require(msg.sender == router, "only router");
        _;
    }

    // ─── IYieldStrategy ─────────────────────────────────────────────────

    function name() external pure override returns (string memory) {
        return "dForce Unitus USDT0 Lending";
    }

    function asset() external view override returns (address) {
        return address(usdt0);
    }

    function totalDeposited() external view override returns (uint256) {
        uint256 iTokenBalance = iToken.balanceOf(address(this));
        uint256 exchangeRate = iToken.exchangeRateStored();
        // exchangeRate is scaled by 1e18
        return (iTokenBalance * exchangeRate) / 1e18;
    }

    function currentAPY() external view override returns (uint256) {
        // supplyRatePerBlock * BLOCKS_PER_YEAR → annualised rate
        // Convert to basis points
        uint256 ratePerBlock = iToken.supplyRatePerBlock();
        // Rate is in 1e18 scale
        uint256 annualRate = ratePerBlock * BLOCKS_PER_YEAR;
        // Convert from 1e18 to bps (1e18 = 100% = 10000 bps)
        return annualRate / 1e14;
    }

    function deposit(uint256 amount) external override onlyRouter {
        iToken.mint(address(this), amount);
    }

    function withdraw(uint256 amount) external override onlyRouter returns (uint256) {
        iToken.redeemUnderlying(address(this), amount);
        uint256 balance = usdt0.balanceOf(address(this));
        uint256 toSend = amount < balance ? amount : balance;
        usdt0.safeTransfer(router, toSend);
        return toSend;
    }

    function harvest() external override onlyRouter returns (uint256) {
        // dForce auto-compounds via exchange rate increase
        // No explicit harvest needed — yield is reflected in exchangeRate
        return 0;
    }

    function depositEnabled() external pure override returns (bool) {
        return true;
    }

    // ─── Admin ──────────────────────────────────────────────────────────

    function setRouter(address _router) external onlyOwner {
        router = _router;
    }

    /// @notice Emergency withdraw all funds back to router
    function emergencyWithdraw() external onlyOwner {
        uint256 iBalance = iToken.balanceOf(address(this));
        if (iBalance > 0) {
            iToken.redeem(address(this), iBalance);
        }
        uint256 balance = usdt0.balanceOf(address(this));
        if (balance > 0) {
            usdt0.safeTransfer(router, balance);
        }
    }
}
