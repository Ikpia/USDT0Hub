// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IUSDT0Router - Public interface for the USDT0Hub Router
interface IUSDT0Router {
    event StrategyRegistered(uint256 indexed id, address strategy);
    event StrategyRemoved(uint256 indexed id, address strategy);
    event Deposited(address indexed user, uint256 amount, uint256 shares);
    event Withdrawn(address indexed user, uint256 shares, uint256 amount);
    event Rebalanced(address indexed caller, uint256 timestamp);
    event YieldHarvested(uint256 totalHarvested);
    event Usdt0Bridged(
        uint32 indexed dstEid,
        bytes32 indexed recipient,
        uint256 amount,
        uint256 minAmountReceived,
        uint256 nativeFee
    );

    function deposit(uint256 amount) external returns (uint256 shares);
    function withdraw(uint256 shares) external returns (uint256 amount);
    function rebalance() external;
    function registerStrategy(address strategy) external;
    function removeStrategy(uint256 strategyId) external;
    function getStrategyCount() external view returns (uint256);
    function getBestStrategy() external view returns (uint256 strategyId, uint256 apy);
    function totalAssets() external view returns (uint256);
    function quoteUsdt0Bridge(
        uint32 dstEid,
        bytes32 recipient,
        uint256 amount,
        uint256 minAmountReceived,
        bytes calldata extraOptions,
        bytes calldata composeMsg,
        bytes calldata oftCmd
    ) external view returns (uint256 nativeFee, uint256 lzTokenFee);
    function bridgeUsdt0(
        uint32 dstEid,
        bytes32 recipient,
        uint256 amount,
        uint256 minAmountReceived,
        bytes calldata extraOptions,
        bytes calldata composeMsg,
        bytes calldata oftCmd
    ) external payable;
}
