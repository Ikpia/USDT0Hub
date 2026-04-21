// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IYieldStrategy - Interface for USDT0Hub yield strategy adapters
/// @notice Each adapter wraps a DeFi protocol on Conflux eSpace and exposes
///         a uniform deposit/withdraw/APY interface consumed by USDT0Router.
interface IYieldStrategy {
    /// @notice Human-readable name of the strategy (e.g. "dForce Unitus USDT0 Lending")
    function name() external view returns (string memory);

    /// @notice The underlying asset this strategy accepts (always USDT0 for v1)
    function asset() external view returns (address);

    /// @notice Total assets currently managed by this strategy (in asset decimals)
    function totalDeposited() external view returns (uint256);

    /// @notice Current annualised yield in basis points (e.g. 500 = 5.00%)
    function currentAPY() external view returns (uint256);

    /// @notice Deposit `amount` of the asset into the underlying protocol
    /// @dev    The Router transfers asset to the adapter first, then calls deposit.
    /// @param  amount The amount of asset to deploy
    function deposit(uint256 amount) external;

    /// @notice Withdraw `amount` of the asset from the underlying protocol
    /// @dev    Sends withdrawn tokens back to `msg.sender` (the Router).
    /// @param  amount The amount of asset to pull back
    /// @return actual The actual amount withdrawn (may be less due to fees / slippage)
    function withdraw(uint256 amount) external returns (uint256 actual);

    /// @notice Harvest any accrued yield and reinvest or return it
    /// @return harvested The amount of yield harvested (in asset units)
    function harvest() external returns (uint256 harvested);

    /// @notice Whether deposits are currently accepted
    function depositEnabled() external view returns (bool);
}
