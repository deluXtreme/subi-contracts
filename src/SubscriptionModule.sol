// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { RevokedNonce } from "src/RevokedNonce.sol";

contract SubscriptionModule is RevokedNonce {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    string public constant NAME = "Subscription Module";
    string public constant VERSION = "0.0.1";
}
