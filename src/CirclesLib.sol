// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IHubV2 } from "@circles/src/hub/IHub.sol";
import { TypeDefinitions } from "@circles/src/hub/TypeDefinitions.sol";
import { LibBytes } from "@solady/src/utils/LibBytes.sol";

library CirclesLib {
    using LibBytes for bytes;

    function slice(bytes calldata data, uint256 start, uint256 end) internal pure returns (uint256 result) {
        bytes calldata window = data.sliceCalldata(start, end);
        for (uint256 i = 0; i < window.length; i++) {
            result = (result << 8) | uint8(window[i]);
        }
    }

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

    function extractAmount(TypeDefinitions.FlowEdge[] calldata flow) internal pure returns (uint256 amount) {
        for (uint256 i = 0; i < flow.length; i++) {
            if (flow[i].streamSinkId == 1) {
                amount += flow[i].amount;
            }
        }
    }
}
