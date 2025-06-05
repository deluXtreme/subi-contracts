// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { RevokedNonce } from "src/RevokedNonce.sol";
import { Subscription } from "src/libs/Types.sol";
import { SubscriptionLib } from "src/libs/SubscriptionLib.sol";

import { EnumerableSetLib } from "@solady/src/utils/EnumerableSetLib.sol";

contract SubscriptionModule is RevokedNonce {
    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using SubscriptionLib for Subscription;

    using EnumerableSetLib for EnumerableSetLib.Bytes32Set;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    string public constant NAME = "Subscription Module";
    string public constant VERSION = "0.0.1";

    mapping(address safe => mapping(bytes32 id => Subscription subscription)) public subscriptions;

    mapping(address safe => EnumerableSetLib.Bytes32Set) internal ids;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event SubscriptionCreated(bytes32 indexed id, Subscription indexed subscription);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error IdentifierExists();

    error InvalidFrequency();

    /*//////////////////////////////////////////////////////////////
                   USER-FACING NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function subscribe(
        address recipient,
        uint256 amount,
        uint256 frequency,
        uint256 nonce
    )
        external
        returns (bytes32 id)
    {
        Subscription memory subscription = Subscription({
            subscriber: msg.sender,
            recipient: recipient,
            amount: amount,
            lastRedeemed: 0,
            frequency: frequency,
            nonce: nonce
        });

        id = subscription.compute();
        require(!ids[msg.sender].contains(id), IdentifierExists());
        require(frequency > 0, InvalidFrequency());

        subscriptions[msg.sender][id] = subscription;
        ids[msg.sender].add(id);
        emit SubscriptionCreated(id, subscription);
    }

    /*//////////////////////////////////////////////////////////////
                     USER-FACING CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getSubscriptionIds(address safe) external view returns (bytes32[] memory) {
        return ids[safe].values();
    }
}
