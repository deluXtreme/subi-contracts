// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.28 <0.9.0;

import { SubscriptionModule } from "src/SubscriptionModule.sol";

import { Assertions } from "../utils/Assertions.sol";
import { Utils } from "../utils/Utils.sol";

abstract contract Fork_Test is Assertions, Utils {
    SubscriptionModule internal module;

    function setUp() public virtual {
        vm.createSelectFork({ blockNumber: 40_531_966, urlOrAlias: "gnosis" });

        module = new SubscriptionModule();
    }
}
