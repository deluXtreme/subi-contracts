// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.28 <0.9.0;

import { Base_Test } from "test/Base.t.sol";

import { TransientPattern } from "test/mocks/TransientPattern.sol";

contract TransientPattern_Unit_Fuzz_Test is Base_Test {
    function testFuzz_TransientFlows(uint256 a, uint256 f, uint256 t, bool flag) external {
        a = bound(a, 1e18, 100_000_000e18);
        f = bound(f, 3600, 86_400);
        t = bound(t, f + 1, 10 * f);

        // Create
        transientPattern.create(a, f);

        // Cache last redeemed
        uint256 l = vm.getBlockTimestamp() - f;

        // Time warp
        vm.warp(vm.getBlockTimestamp() + t);

        // Assert
        TransientPattern.Data memory ld = TransientPattern.Data(a, l, f);
        assertEq(keccak256(abi.encode(transientPattern.getData())), keccak256(abi.encode(ld)));

        // Cache expected transient amount
        uint256 periods = (vm.getBlockTimestamp() - l) / f;
        uint256 ta = periods * a;

        emit log_named_uint("periods", periods);
        emit log_named_uint("transient amount", ta);

        // Redeem
        transientPattern.redeem(flag);

        // Assert
        assertEq(transientPattern.v(), _expectedValue(flag, ta));

        // Can we access the transient slot and get a non-zero value?
        uint256 shouldBeZero = uint256(vm.load(address(transientPattern), transientPattern.T_REDEEMABLE_AMOUNT()));
        assertEq(shouldBeZero, 0);
    }

    function _expectedValue(bool isDoSomething, uint256 ta) internal returns (bytes32) {
        return (isDoSomething) ? _getHash("SOMETHING", ta) : _getHash("SOMETHING_ELSE", ta);
    }

    function _getHash(string memory s, uint256 ta) internal returns (bytes32) {
        return keccak256(abi.encode(s, ta));
    }
}
