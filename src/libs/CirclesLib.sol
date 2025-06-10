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

    /// @notice Verify that every flow edge in the given stream routes to the specified recipient.
    /// @param streams A Stream struct whose flow edge ids define how many edges to check.
    /// @param recipient The address that each to index must match.
    /// @param flowVertices The list of all addresses (vertices) used to resolve each to index.
    /// @param coordinates Packed coordinates for this stream.
    /// @return success True if every extracted to address equals `recipient`, otherwise false.
    function checkRecipients(
        TypeDefinitions.Stream[] calldata streams,
        address recipient,
        address[] calldata flowVertices,
        bytes calldata coordinates
    )
        internal
        pure
        returns (bool)
    {
        TypeDefinitions.Stream memory stream = streams[streams.length - 1];
        uint256 edgeCount = stream.flowEdgeIds.length;
        for (uint256 i = 0; i < edgeCount; i++) {
            uint256 start = 6 * stream.flowEdgeIds[i] + 4;
            uint256 toIndex = slice(coordinates, start, start + 2);
            if (flowVertices[toIndex] != recipient) return false;
        }
        return true;
    }

    function checkSource(
        TypeDefinitions.Stream[] calldata streams,
        uint256 sourceCoordinate
    )
        internal
        pure
        returns (bool success)
    {
        for (uint256 i; i < streams.length; ++i) {
            if (streams[i].sourceCoordinate != sourceCoordinate) return false;
        }
        return true;
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
