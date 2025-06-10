// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.28 <0.9.0;

import { SubscriptionModule } from "src/SubscriptionModule.sol";

contract ModuleHarness is SubscriptionModule {
    function exposed__subscribe(address subscriber, bytes32 id, Subscription memory subscription) external {
        _subscribe(subscriber, id, subscription);
    }

    function exposed__unsubscribe(address subscriber, bytes32 id) external {
        _unsubscribe(subscriber, id);
    }

    function exposed__exists(bytes32 id) external view returns (bool) {
        return _exists(id);
    }

    function exposed__loadSubscription(bytes32 id) external view returns (address safe, Subscription memory sub) {
        (safe, sub) = _loadSubscription(id);
    }

    function exposed__requireRedeemablePeriods(Subscription memory sub) external view returns (uint256 periods) {
        periods = _requireRedeemablePeriods(sub);
    }

    function exposed__applyRedemption(address safe, bytes32 id, Subscription memory sub, uint256 periods) external {
        _applyRedemption(safe, id, sub, periods);
    }
}
