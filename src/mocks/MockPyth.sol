// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPyth, Price} from "../interfaces/IPyth.sol";

/// @title MockPyth - Mock Pyth oracle for testing
contract MockPyth is IPyth {
    mapping(bytes32 => Price) public prices;

    function setPrice(bytes32 id, int64 price, uint64 conf, int32 expo) external {
        prices[id] = Price({
            price: price,
            conf: conf,
            expo: expo,
            publishTime: block.timestamp
        });
    }

    function getPrice(bytes32 id) external view override returns (Price memory) {
        return prices[id];
    }

    function getPriceNoOlderThan(bytes32 id, uint256) external view override returns (Price memory) {
        return prices[id];
    }

    function getPriceUnsafe(bytes32 id) external view override returns (Price memory) {
        return prices[id];
    }

    function getUpdateFee(bytes[] calldata) external pure override returns (uint256) {
        return 0;
    }

    function updatePriceFeeds(bytes[] calldata) external payable override {}
}
