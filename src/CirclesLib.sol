// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IHubV2 } from "@circles/src/hub/IHub.sol";
import { TypeDefinitions } from "@circles/src/hub/TypeDefinitions.sol";
import { LibBytes } from "@solady/src/utils/LibBytes.sol";

library CirclesLib {
    using LibBytes for bytes;

    /// @notice Read bytes[start:end] from calldata and turn them into a uint256.
    /// @param data  The full byte array in calldata.
    /// @param start The starting index (inclusive) of the slice.
    /// @param end   The ending index (exclusive) of the slice.
    /// @return result The integer value of the slice.
    function slice(bytes calldata data, uint256 start, uint256 end) internal pure returns (uint256 result) {
        bytes calldata window = data.sliceCalldata(start, end);
        for (uint256 i = 0; i < window.length; i++) {
            result = (result << 8) | uint8(window[i]);
        }
    }

    /// @notice Take the last two bytes of `coordinates` and use them as an index into `flowVertices`.
    /// @param coordinates A bytes array whose final two bytes encode an index.
    /// @param flowVertices A list of addresses. We return flowVertices[index].
    /// @return The address from flowVertices at the index encoded in the last two bytes.
    function extractRecipient(
        bytes calldata coordinates,
        address[] calldata flowVertices
    )
        internal
        pure
        returns (address)
    {
        uint256 l = coordinates.length;
        return flowVertices[slice(coordinates, l - 2, l)];
    }

    /// @notice Sum all flow amount entries where stream sink ID is 1.
    /// @param flow An array of FlowEdge structs.
    /// @return amount The total of all `amount` fields whose `streamSinkId` equals 1.
    function extractAmount(TypeDefinitions.FlowEdge[] calldata flow) internal pure returns (uint256 amount) {
        for (uint256 i = 0; i < flow.length; i++) {
            if (flow[i].streamSinkId == 1) {
                amount += flow[i].amount;
            }
        }
    }
}
