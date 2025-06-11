// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.28;

import { StdAssertions } from "forge-std/Test.sol";
import { Subscription } from "src/libs/Types.sol";

contract Assertions is StdAssertions {
    function assertEq(Subscription memory a, Subscription memory b) internal pure {
        assertEq(keccak256(abi.encode(a)), keccak256(abi.encode(b)));
    }
}
