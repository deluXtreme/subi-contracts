// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

struct Subscription {
    address subscriber;
    address recipient;
    uint256 amount;
    uint256 lastRedeemed;
    uint256 frequency;
    uint256 nonce;
}
