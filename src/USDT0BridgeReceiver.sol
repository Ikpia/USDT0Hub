// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {USDT0Router} from "./USDT0Router.sol";

/// @title USDT0BridgeReceiver - Meson.fi bridge integration receiver
/// @notice Receives USDT0 bridged via Meson.fi from any source chain and
///         automatically routes it into the USDT0Router for yield.
///         Supports strategy hints so users can pick their preferred strategy
///         from the source chain.
contract USDT0BridgeReceiver is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ─── State ──────────────────────────────────────────────────────────
    IERC20 public immutable usdt0;
    USDT0Router public immutable router;

    /// @notice Authorised Meson router address that can call onReceive
    address public mesonRouter;

    // ─── Strategy hints ─────────────────────────────────────────────────
    uint8 public constant STRATEGY_AUTO = 0;    // Router picks best APY
    uint8 public constant STRATEGY_DFORCE = 1;
    uint8 public constant STRATEGY_WALLFREEX = 2;
    uint8 public constant STRATEGY_SHUI = 3;

    // ─── Events ─────────────────────────────────────────────────────────
    event BridgeReceived(
        address indexed recipient,
        uint256 amount,
        uint8 strategyHint,
        uint256 sharesReceived
    );
    event DirectDeposit(address indexed user, uint256 amount, uint256 sharesReceived);

    constructor(
        address _usdt0,
        address _router,
        address _mesonRouter,
        address _owner
    ) Ownable(_owner) {
        usdt0 = IERC20(_usdt0);
        router = USDT0Router(payable(_router));
        mesonRouter = _mesonRouter;

        // Pre-approve router to spend USDT0
        IERC20(_usdt0).approve(_router, type(uint256).max);
    }

    // ─── Meson Integration ──────────────────────────────────────────────

    /// @notice Called by Meson router after bridging USDT0 to Conflux eSpace
    /// @dev    Meson transfers USDT0 to this contract first, then calls onReceive.
    ///         The `data` param encodes the recipient address and strategy hint.
    /// @param amount The bridged USDT0 amount
    /// @param data   ABI-encoded (address recipient, uint8 strategyHint)
    function onReceive(uint256 amount, bytes calldata data) external nonReentrant {
        require(msg.sender == mesonRouter, "only meson router");
        require(amount > 0, "zero amount");

        (address recipient, uint8 strategyHint) = abi.decode(data, (address, uint8));
        require(recipient != address(0), "zero recipient");

        uint256 shares = _routeDeposit(amount, recipient);

        emit BridgeReceived(recipient, amount, strategyHint, shares);
    }

    /// @notice Direct deposit from any user on Conflux eSpace
    /// @dev    Users who already have USDT0 on eSpace can bypass the bridge.
    /// @param amount USDT0 amount to deposit
    /// @return shares huUSDT0 shares received
    function depositDirect(uint256 amount) external nonReentrant returns (uint256 shares) {
        require(amount > 0, "zero amount");

        usdt0.safeTransferFrom(msg.sender, address(this), amount);
        shares = _routeDeposit(amount, msg.sender);

        emit DirectDeposit(msg.sender, amount, shares);
    }

    // ─── Admin ──────────────────────────────────────────────────────────

    function setMesonRouter(address _mesonRouter) external onlyOwner {
        mesonRouter = _mesonRouter;
    }

    /// @notice Rescue tokens accidentally sent to this contract
    function rescueTokens(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(owner(), amount);
    }

    // ─── Internal ───────────────────────────────────────────────────────

    function _routeDeposit(uint256 amount, address recipient) internal returns (uint256 shares) {
        // Deposit into router on behalf of recipient
        shares = router.deposit(amount, recipient);
    }
}
