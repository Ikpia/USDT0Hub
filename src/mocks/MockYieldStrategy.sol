// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IYieldStrategy} from "../interfaces/IYieldStrategy.sol";

/// @title MockYieldStrategy - Configurable mock strategy for testing
contract MockYieldStrategy is IYieldStrategy {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    string private _name;
    uint256 public apy;
    uint256 public deposited;
    bool public enabled = true;

    constructor(address _token, string memory name_, uint256 _apy) {
        token = IERC20(_token);
        _name = name_;
        apy = _apy;
    }

    function name() external view override returns (string memory) { return _name; }
    function asset() external view override returns (address) { return address(token); }
    function totalDeposited() external view override returns (uint256) { return deposited; }
    function currentAPY() external view override returns (uint256) { return apy; }
    function depositEnabled() external view override returns (bool) { return enabled; }

    function deposit(uint256 amount) external override {
        deposited += amount;
    }

    function withdraw(uint256 amount) external override returns (uint256) {
        uint256 toSend = amount < deposited ? amount : deposited;
        deposited -= toSend;
        token.safeTransfer(msg.sender, toSend);
        return toSend;
    }

    function harvest() external override returns (uint256) {
        // Simulate yield: mint 0.1% of deposited as yield
        uint256 yield_ = deposited / 1000;
        if (yield_ > 0) {
            // In tests, the mock token can mint — here we just return 0
            // as yield is tracked via totalDeposited increase
        }
        return 0;
    }

    // ─── Test helpers ───────────────────────────────────────────────────

    function setAPY(uint256 _apy) external { apy = _apy; }
    function setEnabled(bool _enabled) external { enabled = _enabled; }
    function simulateYield(uint256 extra) external { deposited += extra; }
}
