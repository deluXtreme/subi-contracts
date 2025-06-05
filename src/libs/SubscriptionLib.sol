// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Subscription } from "src/libs/Types.sol";

library SubscriptionLib {
    function compute(Subscription memory subscription) internal pure returns (bytes32) {
        return keccak256(abi.encode(subscription));
    }
}
