// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { TypeDefinitions } from "@circles/src/hub/TypeDefinitions.sol";

interface ISubscriptionModule {
    function cancel(uint256 id) external;

    function owner() external view returns (address);

    function redeem(
        uint256 id,
        address[] memory flowVertices,
        TypeDefinitions.FlowEdge[] memory flow,
        TypeDefinitions.Stream[] memory streams,
        bytes memory packedCoordinates
    )
        external
        returns (uint256);

    function subscribe(
        address recipient,
        uint256 amount,
        uint256 frequency,
        bool isRecurring
    )
        external
        returns (uint256 id);

    function updateRecipient(uint256 id, address currentRecipient, address newRecipient) external;
}
