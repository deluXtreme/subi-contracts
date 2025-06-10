// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library Errors {
    error ExecutionFailed();

    error InvalidAmount();

    error IdentifierExists();

    error InvalidFrequency();

    error InvalidRecipient();

    error InvalidSubscriber();

    error NonceAlreadyRevoked(address addr, uint256 nonce);

    error NotRedeemable();

    error SingleStreamOnly();

    error SubscriptionCancelled();
}
