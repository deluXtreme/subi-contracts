// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { Subscription, Category } from "src/libs/Types.sol";

import { Constants } from "./Constants.sol";
import { Utils } from "./Utils.sol";

abstract contract Fuzzers is Constants, Utils {
    function fuzzSubscription(
        address subscriber,
        address recipient,
        uint256 amount,
        uint256 lastRedeemed,
        uint256 frequency,
        uint8 categoryUint
    )
        internal
        pure
        returns (Subscription memory)
    {
        Category category = fuzzCategory(categoryUint);

        return Subscription({
            subscriber: subscriber,
            recipient: recipient,
            amount: amount,
            lastRedeemed: lastRedeemed,
            frequency: frequency,
            category: category
        });
    }

    function fuzzCategory(uint8 categoryUint) internal pure returns (Category category) {
        if (categoryUint == 0) {
            category = Category.trusted;
        } else if (categoryUint == 1) {
            category = Category.untrusted;
        } else if (categoryUint == 2) {
            category = Category.group;
        }
    }
}
