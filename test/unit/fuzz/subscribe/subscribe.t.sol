// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.28 <0.9.0;

import { Base_Test } from "test/Base.t.sol";
import { stdStorage, StdStorage } from "forge-std/Test.sol";

import { SubscriptionModule } from "src/SubscriptionModule.sol";
import { SubscriptionLib } from "src/libs/SubscriptionLib.sol";
import { Errors } from "src/libs/Errors.sol";
import { Subscription } from "src/libs/Types.sol";

contract Subscribe_Unit_Fuzz_Test is Base_Test {
    using stdStorage for StdStorage;
    using SubscriptionLib for Subscription;

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/

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

    /*//////////////////////////////////////////////////////////////
                              USER-FACING
    //////////////////////////////////////////////////////////////*/

    function testFuzz_ShouldRevert_ZeroFrequency(
        address recipient,
        uint256 amount,
        bool requireTrusted
    )
        external
        givenIdentifierNotExists
    {
        vm.expectRevert(Errors.InvalidFrequency.selector);
        module.subscribe(recipient, amount, 0, requireTrusted);
    }

    function testFuzz_Subscribe(
        address recipient,
        uint256 amount,
        uint256 frequency,
        bool requireTrusted
    )
        external
        whenCallerSubscriber
        givenIdentifierExists
        whenFrequencyGtZero
    {
        frequency = bound(frequency, 1, vm.getBlockTimestamp());

        Subscription memory sub = Subscription({
            subscriber: users.subscriber,
            recipient: recipient,
            amount: amount,
            lastRedeemed: vm.getBlockTimestamp() - frequency,
            frequency: frequency,
            requireTrusted: requireTrusted
        });

        vm.expectEmit();
        emit SubscriptionModule.SubscriptionCreated(
            sub.compute(),
            users.subscriber,
            recipient,
            amount,
            vm.getBlockTimestamp() - frequency,
            frequency,
            requireTrusted
        );

        bytes32 id = module.subscribe(recipient, amount, frequency, requireTrusted);

        assertEq(module.getSubscription(users.subscriber, id), sub);
        assertEq(module.safeFromId(id), users.subscriber);
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = id;
        assertEq(module.getSubscriptionIds(users.subscriber), ids);
    }
}
