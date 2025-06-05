// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

struct Subscription {
    address recipient;
    bool isRecurring;
    uint256 amount;
    uint256 lastRedeemed;
    uint256 frequency;
    uint256 nonce;
}
