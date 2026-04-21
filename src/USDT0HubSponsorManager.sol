// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ISponsorWhitelistControl} from "./interfaces/ISponsorWhitelistControl.sol";

/// @title USDT0HubSponsorManager - Conflux Gas Sponsorship Manager
/// @notice Manages gas sponsorship for all USDT0Hub contracts using Conflux's
///         built-in SponsorWhitelistControl. Sponsors gas so users with zero CFX
///         can interact with deposit, withdraw, swap, and claim functions.
contract USDT0HubSponsorManager is Ownable {
    ISponsorWhitelistControl public constant SPONSOR_CONTROL =
        ISponsorWhitelistControl(0x0888000000000000000000000000000000000001);

    /// @notice Contracts managed by this sponsor manager
    address[] public sponsoredContracts;
    mapping(address => bool) public isSponsored;

    event ContractSponsored(address indexed contractAddr, uint256 gasAmount, uint256 upperBound);
    event WhitelistUpdated(address indexed contractAddr, bool allUsers);
    event SponsorToppedUp(address indexed contractAddr, uint256 amount);

    constructor(address _owner) Ownable(_owner) {}

    /// @notice Register a contract for gas sponsorship and whitelist all senders
    /// @param contractAddr The USDT0Hub contract to sponsor
    /// @param gasUpperBound Maximum gas fee per transaction (in drip)
    function sponsorContract(address contractAddr, uint256 gasUpperBound) external payable onlyOwner {
        require(msg.value > 0, "must send CFX for sponsorship");
        require(!isSponsored[contractAddr], "already sponsored");

        // Set gas sponsor
        SPONSOR_CONTROL.setSponsorForGas{value: msg.value}(contractAddr, gasUpperBound);

        // Whitelist ALL senders (address(0) means everyone)
        address[] memory everyone = new address[](1);
        everyone[0] = address(0);
        SPONSOR_CONTROL.addPrivilegeByAdmin(contractAddr, everyone);

        sponsoredContracts.push(contractAddr);
        isSponsored[contractAddr] = true;

        emit ContractSponsored(contractAddr, msg.value, gasUpperBound);
        emit WhitelistUpdated(contractAddr, true);
    }

    /// @notice Add more CFX to an existing sponsorship
    /// @param contractAddr The contract to top up
    function topUpSponsorship(address contractAddr) external payable onlyOwner {
        require(msg.value > 0, "must send CFX");
        require(isSponsored[contractAddr], "not sponsored");

        uint256 currentUpperBound = SPONSOR_CONTROL.getSponsoredGasFeeUpperBound(contractAddr);
        SPONSOR_CONTROL.setSponsorForGas{value: msg.value}(contractAddr, currentUpperBound);

        emit SponsorToppedUp(contractAddr, msg.value);
    }

    /// @notice Set storage collateral sponsorship
    /// @param contractAddr The contract to sponsor storage for
    function sponsorStorage(address contractAddr) external payable onlyOwner {
        require(msg.value > 0, "must send CFX");
        SPONSOR_CONTROL.setSponsorForCollateral{value: msg.value}(contractAddr);
    }

    /// @notice Whitelist specific addresses for a sponsored contract
    /// @param contractAddr The sponsored contract
    /// @param users        Addresses to whitelist
    function whitelistUsers(address contractAddr, address[] calldata users) external onlyOwner {
        require(isSponsored[contractAddr], "not sponsored");
        SPONSOR_CONTROL.addPrivilegeByAdmin(contractAddr, users);
    }

    /// @notice Remove addresses from whitelist
    /// @param contractAddr The sponsored contract
    /// @param users        Addresses to remove
    function removeFromWhitelist(address contractAddr, address[] calldata users) external onlyOwner {
        require(isSponsored[contractAddr], "not sponsored");
        SPONSOR_CONTROL.removePrivilegeByAdmin(contractAddr, users);
    }

    // ─── View Functions ─────────────────────────────────────────────────

    function getSponsoredContractCount() external view returns (uint256) {
        return sponsoredContracts.length;
    }

    function getSponsorBalance(address contractAddr) external view returns (uint256) {
        return SPONSOR_CONTROL.getSponsoredBalanceForGas(contractAddr);
    }

    function getGasUpperBound(address contractAddr) external view returns (uint256) {
        return SPONSOR_CONTROL.getSponsoredGasFeeUpperBound(contractAddr);
    }

    function isUserWhitelisted(address contractAddr, address user) external view returns (bool) {
        return SPONSOR_CONTROL.isWhitelistedSender(contractAddr, user);
    }

    /// @notice Allow owner to withdraw excess CFX
    function withdrawCFX() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "no balance");
        (bool ok,) = owner().call{value: balance}("");
        require(ok, "transfer failed");
    }

    receive() external payable {}
}
