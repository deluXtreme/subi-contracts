// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.28 <0.9.0;

import { Base_Test } from "test/Base.t.sol";
import { stdStorage, StdStorage } from "forge-std/Test.sol";

import { SubscriptionModule } from "src/SubscriptionModule.sol";
import { SubscriptionLib } from "src/libs/SubscriptionLib.sol";
import { Errors } from "src/libs/Errors.sol";
import { Subscription, Category } from "src/libs/Types.sol";

contract Subscribe_Unit_Fuzz_Test is Base_Test {
    using stdStorage for StdStorage;
    using SubscriptionLib for Subscription;

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/

    function testFuzz_ShouldRevert_IdentifierExists(address s, address r, uint256 a, uint256 f, uint256 lr) external {
        vm.assume(s != address(0));
        vm.assume(r != address(0));
        vm.assume(f > 0);
        vm.assume(lr <= block.timestamp);

        Subscription memory sub = Subscription({
            subscriber: s,
            recipient: r,
            amount: a,
            lastRedeemed: lr,
            frequency: f,
            category: Category.trusted
        });

        bytes32 id = sub.compute();
        module.exposed__subscribe(id, sub);

        vm.expectRevert(Errors.IdentifierExists.selector);
        module.exposed__subscribe(id, sub);
    }

    function testFuzz_Subscribe_Internal(
        bytes32 id,
        address s,
        address r,
        uint256 a,
        uint256 f,
        uint256 lr,
        uint8 c
    )
        external
        givenIdentifierNotExists
    {
        vm.assume(id != bytes32(ZERO_SENTINEL));
        vm.assume(s != address(0));
        vm.assume(r != address(0));
        vm.assume(f > 0);
        vm.assume(lr <= block.timestamp);

        Subscription memory sub = fuzzSubscription(s, r, a, lr, f, c);
        module.exposed__subscribe(id, sub);

        assertEq(module.getSubscription(id), sub);
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = id;
        assertEq(module.getSubscriptionIds(sub.subscriber), ids);
    }

    /*//////////////////////////////////////////////////////////////
                              USER-FACING
    //////////////////////////////////////////////////////////////*/

    function testFuzz_ShouldRevert_ZeroFrequency(address recipient, uint256 amount) external givenIdentifierNotExists {
        vm.expectRevert(Errors.InvalidFrequency.selector);
        module.subscribe(recipient, amount, 0, Category.trusted);
    }

    function testFuzz_Subscribe(
        address recipient,
        uint256 amount,
        uint256 frequency
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
            category: Category.trusted
        });

        vm.expectEmit();
        emit SubscriptionModule.SubscriptionCreated(
            sub.compute(), users.subscriber, recipient, amount, frequency, Category.trusted
        );

        bytes32 id = module.subscribe(recipient, amount, frequency, Category.trusted);

        assertEq(module.getSubscription(id), sub);
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = id;
        assertEq(module.getSubscriptionIds(users.subscriber), ids);
    }
}
