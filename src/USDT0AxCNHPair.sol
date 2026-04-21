// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IPyth, Price} from "./interfaces/IPyth.sol";

/// @title USDT0AxCNHPair - Stablecoin AMM for USDT0/AxCNH FX swaps
/// @notice Constant-sum AMM with Pyth oracle-based pricing for near-zero slippage
///         stablecoin swaps. First on-chain USD ↔ offshore CNH FX market on Conflux.
/// @dev    Uses a StableSwap-style invariant tuned for pegged stablecoin pairs.
///         Pyth oracle provides external reference price for slippage protection.
contract USDT0AxCNHPair is ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;

    // ─── Tokens ─────────────────────────────────────────────────────────
    IERC20 public immutable usdt0;   // 6 decimals
    IERC20 public immutable axcnh;   // 18 decimals

    // ─── Oracle ─────────────────────────────────────────────────────────
    IPyth public immutable pyth;
    bytes32 public immutable usdtPriceFeedId;
    bytes32 public immutable cnhPriceFeedId;
    uint256 public constant MAX_PRICE_AGE = 300; // 5 minutes

    // ─── Pool state ─────────────────────────────────────────────────────
    uint256 public reserve0; // USDT0 reserve (scaled to 18 dec internally)
    uint256 public reserve1; // AxCNH reserve (18 dec)

    // ─── Fees ───────────────────────────────────────────────────────────
    uint256 public swapFeeBps = 5;           // 0.05% swap fee
    uint256 public protocolFeeShareBps = 1000; // 10% of swap fee goes to protocol
    address public feeRecipient;

    // Accumulated protocol fees (in native token decimals)
    uint256 public accumulatedFee0; // USDT0 fees
    uint256 public accumulatedFee1; // AxCNH fees

    // ─── Amplification (StableSwap) ─────────────────────────────────────
    uint256 public constant A = 100; // Amplification coefficient

    // ─── Scaling ────────────────────────────────────────────────────────
    uint256 private constant USDT0_SCALE = 1e12; // 6 dec → 18 dec

    // ─── Events ─────────────────────────────────────────────────────────
    event LiquidityAdded(address indexed provider, uint256 usdt0Amount, uint256 axcnhAmount, uint256 lpTokens);
    event LiquidityRemoved(address indexed provider, uint256 usdt0Amount, uint256 axcnhAmount, uint256 lpTokens);
    event Swapped(address indexed user, address tokenIn, uint256 amountIn, uint256 amountOut);
    event FeesCollected(uint256 fee0, uint256 fee1);

    constructor(
        address _usdt0,
        address _axcnh,
        address _pyth,
        bytes32 _usdtFeedId,
        bytes32 _cnhFeedId,
        address _owner
    ) ERC20("USDT0Hub FX LP", "huFX-LP") Ownable(_owner) {
        usdt0 = IERC20(_usdt0);
        axcnh = IERC20(_axcnh);
        pyth = IPyth(_pyth);
        usdtPriceFeedId = _usdtFeedId;
        cnhPriceFeedId = _cnhFeedId;
        feeRecipient = _owner;
    }

    // ─── Liquidity ──────────────────────────────────────────────────────

    /// @notice Add liquidity to the USDT0/AxCNH pool
    /// @param usdt0Amount Amount of USDT0 (6 decimals)
    /// @param axcnhAmount Amount of AxCNH (18 decimals)
    /// @return lpTokens   LP tokens minted
    function addLiquidity(uint256 usdt0Amount, uint256 axcnhAmount)
        external
        nonReentrant
        returns (uint256 lpTokens)
    {
        require(usdt0Amount > 0 || axcnhAmount > 0, "zero amounts");

        // Transfer tokens in
        if (usdt0Amount > 0) {
            usdt0.safeTransferFrom(msg.sender, address(this), usdt0Amount);
        }
        if (axcnhAmount > 0) {
            axcnh.safeTransferFrom(msg.sender, address(this), axcnhAmount);
        }

        // Scale USDT0 to 18 decimals for internal math
        uint256 scaled0 = usdt0Amount * USDT0_SCALE;

        uint256 totalSupplyBefore = totalSupply();

        if (totalSupplyBefore == 0) {
            // First deposit — LP tokens = total value deposited (in 18 dec)
            lpTokens = scaled0 + axcnhAmount;
            require(lpTokens > 1000, "initial liquidity too low");
        } else {
            // Proportional mint based on value added vs existing reserves
            uint256 totalReserveValue = reserve0 + reserve1;
            uint256 depositValue = scaled0 + axcnhAmount;
            lpTokens = (depositValue * totalSupplyBefore) / totalReserveValue;
        }

        reserve0 += scaled0;
        reserve1 += axcnhAmount;

        _mint(msg.sender, lpTokens);
        emit LiquidityAdded(msg.sender, usdt0Amount, axcnhAmount, lpTokens);
    }

    /// @notice Remove liquidity from the pool
    /// @param lpTokens Amount of LP tokens to burn
    /// @return usdt0Out USDT0 returned (6 decimals)
    /// @return axcnhOut AxCNH returned (18 decimals)
    function removeLiquidity(uint256 lpTokens)
        external
        nonReentrant
        returns (uint256 usdt0Out, uint256 axcnhOut)
    {
        require(lpTokens > 0, "zero lp tokens");
        require(balanceOf(msg.sender) >= lpTokens, "insufficient lp");

        uint256 totalSupplyBefore = totalSupply();

        // Pro-rata share of reserves
        uint256 scaled0Out = (reserve0 * lpTokens) / totalSupplyBefore;
        uint256 scaled1Out = (reserve1 * lpTokens) / totalSupplyBefore;

        // Scale USDT0 back to 6 decimals
        usdt0Out = scaled0Out / USDT0_SCALE;
        axcnhOut = scaled1Out;

        reserve0 -= scaled0Out;
        reserve1 -= scaled1Out;

        _burn(msg.sender, lpTokens);

        // Transfer tokens out
        if (usdt0Out > 0) {
            usdt0.safeTransfer(msg.sender, usdt0Out);
        }
        if (axcnhOut > 0) {
            axcnh.safeTransfer(msg.sender, axcnhOut);
        }

        emit LiquidityRemoved(msg.sender, usdt0Out, axcnhOut, lpTokens);
    }

    // ─── Swap ───────────────────────────────────────────────────────────

    /// @notice Swap USDT0 for AxCNH
    /// @param amountIn     USDT0 amount (6 decimals)
    /// @param minAmountOut Minimum AxCNH to receive (18 decimals)
    /// @return amountOut   AxCNH received
    function swapUSDT0ForAxCNH(uint256 amountIn, uint256 minAmountOut)
        external
        nonReentrant
        returns (uint256 amountOut)
    {
        require(amountIn > 0, "zero amount");

        usdt0.safeTransferFrom(msg.sender, address(this), amountIn);

        uint256 scaledIn = amountIn * USDT0_SCALE;
        amountOut = _quoteUsdt0ForAxCnhRaw(amountIn);

        // Apply swap fee
        uint256 fee = (amountOut * swapFeeBps) / 10_000;
        uint256 protocolFee = (fee * protocolFeeShareBps) / 10_000;
        accumulatedFee1 += protocolFee;
        amountOut -= fee;

        require(amountOut >= minAmountOut, "slippage exceeded");
        require(amountOut <= reserve1, "insufficient liquidity");

        reserve0 += scaledIn;
        reserve1 -= (amountOut + fee);

        axcnh.safeTransfer(msg.sender, amountOut);
        emit Swapped(msg.sender, address(usdt0), amountIn, amountOut);
    }

    /// @notice Swap AxCNH for USDT0
    /// @param amountIn     AxCNH amount (18 decimals)
    /// @param minAmountOut Minimum USDT0 to receive (6 decimals)
    /// @return amountOut   USDT0 received (6 decimals)
    function swapAxCNHForUSDT0(uint256 amountIn, uint256 minAmountOut)
        external
        nonReentrant
        returns (uint256 amountOut)
    {
        require(amountIn > 0, "zero amount");

        axcnh.safeTransferFrom(msg.sender, address(this), amountIn);

        uint256 scaledOut = _quoteAxCnhForUsdt0Raw(amountIn);

        // Apply swap fee (in 18 dec)
        uint256 fee = (scaledOut * swapFeeBps) / 10_000;
        uint256 protocolFee = (fee * protocolFeeShareBps) / 10_000;
        accumulatedFee0 += protocolFee / USDT0_SCALE;
        scaledOut -= fee;

        require(scaledOut <= reserve0, "insufficient liquidity");

        reserve1 += amountIn;
        reserve0 -= (scaledOut + fee);

        // Scale back to 6 decimals
        amountOut = scaledOut / USDT0_SCALE;
        require(amountOut >= minAmountOut, "slippage exceeded");

        usdt0.safeTransfer(msg.sender, amountOut);
        emit Swapped(msg.sender, address(axcnh), amountIn, amountOut);
    }

    // ─── View Functions ─────────────────────────────────────────────────

    /// @notice Get the current FX rate from Pyth oracle (USDT/CNH)
    /// @return rate The exchange rate scaled to 18 decimals
    function getOracleRate() public view returns (uint256 rate) {
        Price memory usdtPrice = pyth.getPriceNoOlderThan(usdtPriceFeedId, MAX_PRICE_AGE);
        Price memory cnhPrice = pyth.getPriceNoOlderThan(cnhPriceFeedId, MAX_PRICE_AGE);

        require(usdtPrice.price > 0 && cnhPrice.price > 0, "invalid oracle price");

        uint256 usdtUsd = _normalizePythPrice(usdtPrice);
        uint256 usdCnh = _normalizePythPrice(cnhPrice);
        rate = (usdtUsd * usdCnh) / 1e18;
    }

    /// @notice Quote USDT0 → AxCNH swap (view only, no state change)
    function quoteUSDT0ForAxCNH(uint256 amountIn) external view returns (uint256 amountOut) {
        amountOut = _quoteUsdt0ForAxCnhRaw(amountIn);
        uint256 fee = (amountOut * swapFeeBps) / 10_000;
        amountOut -= fee;
    }

    /// @notice Quote AxCNH → USDT0 swap (view only, no state change)
    function quoteAxCNHForUSDT0(uint256 amountIn) external view returns (uint256 amountOut) {
        uint256 scaledOut = _quoteAxCnhForUsdt0Raw(amountIn);
        uint256 fee = (scaledOut * swapFeeBps) / 10_000;
        scaledOut -= fee;
        amountOut = scaledOut / USDT0_SCALE;
    }

    /// @notice Get pool reserves in native token decimals
    function getReserves() external view returns (uint256 usdt0Reserve, uint256 axcnhReserve) {
        usdt0Reserve = reserve0 / USDT0_SCALE;
        axcnhReserve = reserve1;
    }

    // ─── Admin ──────────────────────────────────────────────────────────

    function setSwapFee(uint256 _feeBps) external onlyOwner {
        require(_feeBps <= 100, "max 1%");
        swapFeeBps = _feeBps;
    }

    function setFeeRecipient(address _recipient) external onlyOwner {
        feeRecipient = _recipient;
    }

    function collectFees() external {
        require(msg.sender == feeRecipient, "not fee recipient");

        uint256 fee0 = accumulatedFee0;
        uint256 fee1 = accumulatedFee1;
        accumulatedFee0 = 0;
        accumulatedFee1 = 0;

        if (fee0 > 0) usdt0.safeTransfer(feeRecipient, fee0);
        if (fee1 > 0) axcnh.safeTransfer(feeRecipient, fee1);

        emit FeesCollected(fee0, fee1);
    }

    // ─── Internal: StableSwap Math ──────────────────────────────────────

    function _quoteUsdt0ForAxCnhRaw(uint256 amountIn) internal view returns (uint256 amountOut) {
        require(reserve0 > 0 && reserve1 > 0, "no liquidity");
        uint256 oracleRate = getOracleRate();
        uint256 idealOut = (amountIn * USDT0_SCALE * oracleRate) / 1e18;
        amountOut = _applyDepthDiscount(idealOut, reserve1);
    }

    function _quoteAxCnhForUsdt0Raw(uint256 amountIn) internal view returns (uint256 scaledOut) {
        require(reserve0 > 0 && reserve1 > 0, "no liquidity");
        uint256 oracleRate = getOracleRate();
        uint256 idealOut = (amountIn * 1e18) / oracleRate;
        scaledOut = _applyDepthDiscount(idealOut, reserve0);
    }

    function _applyDepthDiscount(uint256 idealOut, uint256 reserveOut) internal pure returns (uint256) {
        uint256 amplified = A * 2 + 1;
        uint256 numerator = idealOut * reserveOut * amplified;
        uint256 denominator = reserveOut * amplified + idealOut;
        return numerator / denominator;
    }

    function _normalizePythPrice(Price memory price) internal pure returns (uint256 normalized) {
        require(price.price > 0, "invalid oracle price");
        uint256 unsignedPrice = uint256(uint64(price.price));
        if (price.expo < 0) {
            uint32 decimals = uint32(-price.expo);
            normalized = (unsignedPrice * 1e18) / (10 ** decimals);
        } else {
            normalized = unsignedPrice * (10 ** uint32(price.expo)) * 1e18;
        }
    }
}
