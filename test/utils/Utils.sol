// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.28;

import { CommonBase } from "forge-std/Base.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { StdUtils } from "forge-std/StdUtils.sol";

abstract contract Utils is CommonBase, StdCheats, StdUtils {
    function resetPrank(address msgSender) internal {
        vm.stopPrank();
        vm.startPrank(msgSender);
    }
}
