// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.28;

import { Subscription } from "src/libs/Types.sol";

import { Constants } from "./Constants.sol";
import { Users } from "./Types.sol";

contract Defaults is Constants {
    /*//////////////////////////////////////////////////////////////
                                GENERICS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant SUBSCRIPTION_AMOUNT = 12e18;
    uint256 public constant SUBSCRIPTION_FREQUENCY = 86_400;
    uint256 public constant WARP_257_PERCENT = 222_048 + SUBSCRIPTION_FREQUENCY;

    uint256 public immutable START_TIME;

    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/

    Users private users;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {
        START_TIME = JULY_1_2024 + 4 days;
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function setUsers(Users memory users_) public {
        users = users_;
    }

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    function subscription() public view returns (Subscription memory) {
        return Subscription({
            subscriber: users.subscriber,
            recipient: users.recipient,
            amount: SUBSCRIPTION_AMOUNT,
            lastRedeemed: START_TIME - SUBSCRIPTION_FREQUENCY,
            frequency: SUBSCRIPTION_FREQUENCY,
            requireTrusted: true
        });
    }

    function subscriptionUntrusted() public view returns (Subscription memory) {
        return Subscription({
            subscriber: users.subscriber,
            recipient: users.recipient,
            amount: SUBSCRIPTION_AMOUNT,
            lastRedeemed: START_TIME - SUBSCRIPTION_FREQUENCY,
            frequency: SUBSCRIPTION_FREQUENCY,
            requireTrusted: false
        });
    }

    function subscriptionEmpty() public pure returns (Subscription memory) {
        return Subscription({
            subscriber: address(0),
            recipient: address(0),
            amount: 0,
            lastRedeemed: 0,
            frequency: 0,
            requireTrusted: false
        });
    }
}
