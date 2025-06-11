// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.28 <0.9.0;

import { Base_Test } from "test/Base.t.sol";
import { stdStorage, StdStorage } from "forge-std/Test.sol";

import { Errors } from "src/libs/Errors.sol";
import { Subscription } from "src/libs/Types.sol";

contract Subscribe_Unit_Fuzz_Test is Base_Test {
    using stdStorage for StdStorage;

    function testFuzz_ShouldRevert_IdentifierExists(
        address subscriber,
        bytes32 id,
        Subscription memory subscription,
        address almostAnything
    )
        external
    {
        vm.assume(id != bytes32(ZERO_SENTINEL));
        vm.assume(almostAnything != address(0));
        stdstore.target(address(module)).sig("safeFromId(bytes32)").with_key(id).checked_write(almostAnything);

        vm.expectRevert(Errors.IdentifierExists.selector);
        module.exposed__subscribe(subscriber, id, subscription);
    }

    function testFuzz_Subscribe(
        address subscriber,
        bytes32 id,
        Subscription memory subscription
    )
        external
        givenIdentifierNotExists
    {
        vm.assume(id != bytes32(ZERO_SENTINEL));
        module.exposed__subscribe(subscriber, id, subscription);

        assertEq(module.getSubscription(subscriber, id), subscription);
        assertEq(module.safeFromId(id), subscriber);
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = id;
        assertEq(module.getSubscriptionIds(subscriber), ids);
    }
}
