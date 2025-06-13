// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.28 <0.9.0;

import { Base_Test } from "test/Base.t.sol";

import { SubscriptionModule } from "src/SubscriptionModule.sol";
import { SubscriptionLib } from "src/libs/SubscriptionLib.sol";
import { Errors } from "src/libs/Errors.sol";
import { Subscription } from "src/libs/Types.sol";

contract UpdateRecipient_Unit_Fuzz_Test is Base_Test {
    bytes32 internal id;

    function setUp() public override {
        Base_Test.setUp();

        id = module.subscribe(users.recipient, defaults.SUBSCRIPTION_AMOUNT(), defaults.SUBSCRIPTION_FREQUENCY(), true);
    }

    function testFuzz_ShouldRevert_SubscriptionDoesNotExist() external {
        vm.expectRevert(Errors.OnlyRecipient.selector);
        module.updateRecipient(keccak256(abi.encode("FAKE_SUBSCRIPTION_ID")), address(0x1));
    }

    function testFuzz_ShouldRevert_CallerNotRecipient(address caller) external {
        vm.assume(caller != users.recipient);
        resetPrank({ msgSender: caller });
        vm.expectRevert(Errors.OnlyRecipient.selector);
        module.updateRecipient(id, address(0));
    }

    function testFuzz_UpdateRecipient(address newRecipient) external whenCallerRecipient {
        module.updateRecipient(id, newRecipient);
        assertEq(module.getSubscription(id).recipient, newRecipient);
    }
}
