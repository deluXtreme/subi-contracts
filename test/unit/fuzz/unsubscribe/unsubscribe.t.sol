// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.28 <0.9.0;

import { Base_Test } from "test/Base.t.sol";
import { stdStorage, StdStorage } from "forge-std/Test.sol";

import { SubscriptionModule } from "src/SubscriptionModule.sol";
import { Errors } from "src/libs/Errors.sol";
import { Subscription, Category } from "src/libs/Types.sol";

contract Subscribe_Unit_Fuzz_Test is Base_Test {
    using stdStorage for StdStorage;

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/

    function testFuzz_ShouldRevert_WhenSubscriptionMissing(address subscriber, bytes32 id) external {
        vm.assume(subscriber != address(0));
        vm.expectRevert(Errors.OnlySubscriber.selector);
        module.exposed__unsubscribe(subscriber, id);
    }

    function testFuzz_ShouldRevert_WhenCallerNotSubscriber(
        address caller,
        bytes32 id,
        address s,
        address r,
        uint256 a,
        uint256 lr,
        uint256 f
    )
        external
    {
        vm.assume(id != bytes32(ZERO_SENTINEL));
        vm.assume(s != address(0));
        vm.assume(r != address(0));
        vm.assume(f > 0);
        vm.assume(lr <= block.timestamp);
        vm.assume(caller != address(0));
        vm.assume(caller != s);

        Subscription memory sub = fuzzSubscription(s, r, a, lr, f, 0);
        module.exposed__subscribe(id, sub);

        vm.expectRevert(Errors.OnlySubscriber.selector);
        module.exposed__unsubscribe(caller, id);
    }

    function testFuzz_Unsubscribe_Internal(
        bytes32 id,
        address s,
        address r,
        uint256 a,
        uint256 lr,
        uint256 f
    )
        external
        givenIdentifierExists
    {
        vm.assume(id != bytes32(ZERO_SENTINEL));
        vm.assume(s != address(0));
        vm.assume(s != address(0));
        vm.assume(r != address(0));
        vm.assume(f > 0);
        vm.assume(lr <= block.timestamp);
        Subscription memory sub = fuzzSubscription(s, r, a, f, lr, 0);
        module.exposed__subscribe(id, sub);

        vm.expectEmit();
        emit SubscriptionModule.Unsubscribed(id, sub.subscriber);

        module.exposed__unsubscribe(sub.subscriber, id);

        assertEq(module.getSubscription(id), defaults.subscriptionEmpty());
        bytes32[] memory ids;
        assertEq(module.getSubscriptionIds(sub.subscriber), ids);
    }

    /*//////////////////////////////////////////////////////////////
                              USER-FACING
    //////////////////////////////////////////////////////////////*/

    struct Vars {
        address recipient;
        uint256 amount;
        uint256 frequency;
        uint8 categoryUint;
    }

    function testFuzz_UnsubscribeMany(Vars[3] memory vars) external givenIdentifierExists whenCallerSubscriber {
        bytes32[] memory ids = new bytes32[](3);

        for (uint256 i; i < 3; ++i) {
            vars[i].frequency = bound(vars[i].frequency, 1, SECONDS_PER_YEAR);
            Vars memory v = vars[i];
            ids[i] = module.subscribe(v.recipient, v.amount, v.frequency, fuzzCategory(v.categoryUint));
        }

        for (uint256 i; i < 3; ++i) {
            vm.expectEmit();
            emit SubscriptionModule.Unsubscribed(ids[i], users.subscriber);
        }

        module.unsubscribeMany(ids);

        for (uint256 i; i < 3; ++i) {
            assertEq(module.getSubscription(ids[i]), defaults.subscriptionEmpty());
        }
    }
}
