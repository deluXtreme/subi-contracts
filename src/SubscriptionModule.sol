// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { RevokedNonce } from "src/RevokedNonce.sol";
import { Subscription } from "src/libs/Types.sol";
import { SubscriptionLib } from "src/libs/SubscriptionLib.sol";

contract SubscriptionModule is RevokedNonce {
    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using SubscriptionLib for Subscription;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    string public constant NAME = "Subscription Module";
    string public constant VERSION = "0.0.1";
}
