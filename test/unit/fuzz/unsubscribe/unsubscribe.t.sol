// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.28 <0.9.0;

import { Base_Test } from "test/Base.t.sol";
import { stdStorage, StdStorage } from "forge-std/Test.sol";

import { Errors } from "src/libs/Errors.sol";
import { Subscription } from "src/libs/Types.sol";

contract Subscribe_Unit_Fuzz_Test is Base_Test {
    using stdStorage for StdStorage;

    function testFuzz_ShouldRevert_IdentifierNonexistent(address subscriber, bytes32 id) external {
        vm.expectRevert(Errors.IdentifierNonexistent.selector);
        module.exposed__unsubscribe(subscriber, id);
    }

    function testFuzz_Unsubscribe(
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
}
