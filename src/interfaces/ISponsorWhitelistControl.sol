// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ISponsorWhitelistControl - Conflux built-in contract interface
/// @notice Conflux eSpace built-in at 0x0888000000000000000000000000000000000001
///         Allows contracts to sponsor gas and storage for their users.
interface ISponsorWhitelistControl {
    function getSponsorForGas(address contractAddr) external view returns (address);
    function getSponsoredBalanceForGas(address contractAddr) external view returns (uint256);
    function getSponsoredGasFeeUpperBound(address contractAddr) external view returns (uint256);
    function getSponsorForCollateral(address contractAddr) external view returns (address);
    function getSponsoredBalanceForCollateral(address contractAddr) external view returns (uint256);
    function isWhitelistedSender(address contractAddr, address user) external view returns (bool);
    function isAllWhitelistedSender(address contractAddr) external view returns (bool);

    /// @notice Set the sponsor for gas for `contractAddr`. Must send CFX.
    /// @param contractAddr The contract to sponsor
    /// @param upperBound   Max gas fee per tx the sponsor will cover
    function setSponsorForGas(address contractAddr, uint256 upperBound) external payable;

    /// @notice Set the sponsor for storage collateral for `contractAddr`. Must send CFX.
    /// @param contractAddr The contract to sponsor
    function setSponsorForCollateral(address contractAddr) external payable;

    /// @notice Add addresses to the whitelist of a sponsored contract
    /// @dev    Pass [address(0)] to whitelist ALL senders
    function addPrivilegeByAdmin(address contractAddr, address[] memory addresses) external;

    /// @notice Remove addresses from the whitelist
    function removePrivilegeByAdmin(address contractAddr, address[] memory addresses) external;
}
