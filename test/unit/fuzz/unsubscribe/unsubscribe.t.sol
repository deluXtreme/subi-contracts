// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.28 <0.9.0;

import { Base_Test } from "test/Base.t.sol";
import { stdStorage, StdStorage } from "forge-std/Test.sol";

import { Errors } from "src/libs/Errors.sol";
import { Subscription } from "src/libs/Types.sol";

contract Subscribe_Unit_Fuzz_Test is Base_Test {
    using stdStorage for StdStorage;

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/

    function testFuzz_ShouldRevert_IdentifierNonexistent(address subscriber, bytes32 id) external {
        vm.expectRevert(Errors.IdentifierNonexistent.selector);
        module.exposed__unsubscribe(subscriber, id);
    }

    function testFuzz_Unsubscribe_Internal(
        address subscriber,
        bytes32 id,
        Subscription memory subscription
    )
        external
        givenIdentifierExists
    {
        vm.assume(id != bytes32(ZERO_SENTINEL));
        vm.assume(subscriber != address(0));
        module.exposed__subscribe(subscriber, id, subscription);

        module.exposed__unsubscribe(subscriber, id);

        assertEq(module.getSubscription(id), defaults.subscriptionEmpty());
        assertEq(module.safeFromId(id), address(0));
        bytes32[] memory ids;
        assertEq(module.getSubscriptionIds(subscriber), ids);
    }

    /*//////////////////////////////////////////////////////////////
                              USER-FACING
    //////////////////////////////////////////////////////////////*/

    struct Vars {
        address recipient;
        uint256 amount;
        uint256 frequency;
        bool requireTrusted;
    }

    function testFuzz_UnsubscribeMany(Vars[3] memory vars) external givenIdentifierExists whenCallerSubscriber {
        bytes32[] memory ids = new bytes32[](3);

        for (uint256 i; i < 3; ++i) {
            vars[i].frequency = bound(vars[i].frequency, 1, SECONDS_PER_YEAR);
            Vars memory v = vars[i];
            ids[i] = module.subscribe(v.recipient, v.amount, v.frequency, v.requireTrusted);
        }

        module.unsubscribeMany(ids);

        for (uint256 i; i < 3; ++i) {
            assertEq(module.getSubscription(ids[i]), defaults.subscriptionEmpty());
            assertEq(module.safeFromId(ids[i]), address(0));
        }
    }
}
