// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28 <0.9.0;

import { Test } from "forge-std/Test.sol";
import { CirclesLib } from "src/CirclesLib.sol";

contract SubscriptionModuleTest is Test {
    using CirclesLib for bytes;

    function test_slicey_boys(bytes calldata data) external {
        vm.assume(data.length <= 64);
        vm.assume(data.length >= 2);
        uint256 start = data.length - 2;
        uint256 end = data.length;
        uint256 x1 = data.slice(start, end);

        emit log_uint(x1);
        emit log_bytes(data);
    }
}
