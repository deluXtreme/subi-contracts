// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.28 <0.9.0;

import { ModuleHarness } from "./harness/ModuleHarness.sol";

import { Assertions } from "./utils/Assertions.sol";
import { Defaults } from "./utils/Defaults.sol";
import { Modifiers } from "./utils/Modifiers.sol";
import { Users } from "./utils/Types.sol";
import { Utils } from "./utils/Utils.sol";

abstract contract Base_Test is Assertions, Utils, Modifiers {
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/

    Users internal users;

    /*//////////////////////////////////////////////////////////////
                             TEST CONTRACTS
    //////////////////////////////////////////////////////////////*/

    Defaults internal defaults;

    ModuleHarness internal module;

    /*//////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        vm.warp({ newTimestamp: JULY_1_2024 });

        users.recipient = createUser("Recipient");
        users.sender = createUser("Sender");
        users.subscriber = createUser("Subscriber");

        defaults = new Defaults();

        module = new ModuleHarness();
        vm.label(address(module), "ModuleHarness");

        defaults.setUsers(users);
        setVariables(defaults, users);

        vm.warp({ newTimestamp: START_TIME });

        vm.startPrank({ msgSender: users.sender });
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function createUser(string memory name) internal returns (address) {
        address user = makeAddr(name);
        vm.deal({ account: user, newBalance: 1 ether });
        return user;
    }
}
