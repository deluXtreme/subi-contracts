// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.28 <0.9.0;

import { SubscriptionModule } from "src/SubscriptionModule.sol";
import { Subscription } from "src/libs/Types.sol";

contract ModuleHarness is SubscriptionModule {
    function exposed__subscribe(bytes32 id, Subscription memory subscription) external {
        _subscribe(id, subscription);
    }

    function exposed__unsubscribe(address subscriber, bytes32 id) external {
        _unsubscribe(subscriber, id);
    }
}
