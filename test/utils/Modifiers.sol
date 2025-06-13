// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { Constants } from "./Constants.sol";
import { Defaults } from "./Defaults.sol";
import { Users } from "./Types.sol";
import { Utils } from "./Utils.sol";

abstract contract Modifiers is Constants, Utils {
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/

    Defaults private defaults;
    Users private users;

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function setVariables(Defaults _defaults, Users memory _users) public {
        defaults = _defaults;
        users = _users;
    }

    modifier givenIdentifierNotExists() {
        _;
    }

    modifier givenIdentifierExists() {
        _;
    }

    modifier whenFrequencyGtZero() {
        _;
    }

    modifier whenCallerSubscriber() {
        resetPrank({ msgSender: users.subscriber });
        _;
    }

    modifier whenCallerRecipient() {
        resetPrank({ msgSender: users.recipient });
        _;
    }
}
