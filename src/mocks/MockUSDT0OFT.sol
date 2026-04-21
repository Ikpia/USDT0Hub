// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {
    IUSDT0OFT,
    MessagingFee,
    MessagingReceipt,
    OFTReceipt,
    SendParam
} from "../interfaces/IUSDT0OFT.sol";

contract MockUSDT0OFT is IUSDT0OFT {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    SendParam public lastSendParam;
    address public lastRefundAddress;
    uint256 public sendCount;

    constructor(address _token) {
        token = IERC20(_token);
    }

    function quoteSend(
        SendParam calldata sendParam,
        bool
    ) external pure override returns (MessagingFee memory fee) {
        fee = MessagingFee({
            nativeFee: sendParam.amountLD / 1_000_000,
            lzTokenFee: 0
        });
    }

    function send(
        SendParam calldata sendParam,
        MessagingFee calldata fee,
        address refundAddress
    )
        external
        payable
        override
        returns (MessagingReceipt memory receipt, OFTReceipt memory oftReceipt)
    {
        require(msg.value >= fee.nativeFee, "insufficient native fee");
        token.safeTransferFrom(msg.sender, address(this), sendParam.amountLD);

        lastSendParam = sendParam;
        lastRefundAddress = refundAddress;
        sendCount += 1;

        receipt = MessagingReceipt({
            guid: keccak256(abi.encode(sendCount, sendParam.dstEid, sendParam.to, sendParam.amountLD)),
            nonce: uint64(sendCount),
            fee: fee
        });
        oftReceipt = OFTReceipt({
            amountSentLD: sendParam.amountLD,
            amountReceivedLD: sendParam.minAmountLD
        });
    }
}
