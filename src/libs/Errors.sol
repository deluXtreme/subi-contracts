// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library Errors {
    error ExecutionFailed();

    error InvalidAmount();

    error IdentifierExists();

    error IdentifierNonexistent();

    error InvalidCategory();

    error InvalidFrequency();

    error InvalidRecipient();

    error InvalidSubscriber();

    error InvalidStreamSource();

    error NotRedeemable();

    error SingleStreamOnly();

    error TrustedPathOnly();

    error OnlyRecipient();

    error OnlySubscriber();
}
