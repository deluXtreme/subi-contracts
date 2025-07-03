// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { LibTransient } from "@solady/src/utils/LibTransient.sol";

contract TransientPattern {
    using LibTransient for LibTransient.TUint256;

    bytes32 public constant T_REDEEMABLE_AMOUNT = 0x70bfbb43a5ce660914e09d1b48fcc488982d5981137b973eac35b0592a414e90;

    struct Data {
        uint256 a;
        uint256 l;
        uint256 f;
    }

    Data internal data;

    bytes32 public v;

    function create(uint256 a, uint256 f) external {
        require(f > 0);
        data = Data({ a: a, l: block.timestamp - f, f: f });
    }

    function redeem(bool isDoSomething) external {
        Data memory d = data;

        // Calculate periods
        uint256 p = (block.timestamp - d.l) / d.f;
        require(p >= 1);

        // Update data
        d.l += p * d.f;
        data = d;

        // Set transient storage
        LibTransient.tUint256(T_REDEEMABLE_AMOUNT).set(p * d.a);

        if (isDoSomething) _doSomething();
        else _doSomethingElse();

        // Best practice
        LibTransient.tUint256(T_REDEEMABLE_AMOUNT).clear();
    }

    function _doSomething() internal {
        v = keccak256(abi.encode("SOMETHING", LibTransient.tUint256(T_REDEEMABLE_AMOUNT).get()));
    }

    function _doSomethingElse() internal {
        v = keccak256(abi.encode("SOMETHING_ELSE", LibTransient.tUint256(T_REDEEMABLE_AMOUNT).get()));
    }

    function getData() external view returns (Data memory) {
        return data;
    }
}
