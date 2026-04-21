// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

struct Price {
    int64 price;
    uint64 conf;
    int32 expo;
    uint256 publishTime;
}

/// @title IPyth - Minimal Pyth Network interface for Conflux eSpace
interface IPyth {
    function getPrice(bytes32 id) external view returns (Price memory price);
    function getPriceNoOlderThan(bytes32 id, uint256 age) external view returns (Price memory price);
    function getPriceUnsafe(bytes32 id) external view returns (Price memory price);
    function getUpdateFee(bytes[] calldata updateData) external view returns (uint256 feeAmount);
    function updatePriceFeeds(bytes[] calldata updateData) external payable;
}
