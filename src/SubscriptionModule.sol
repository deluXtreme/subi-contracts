// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { RevokedNonce } from "src/RevokedNonce.sol";
import { ISafe } from "src/interfaces/ISafe.sol";
import { CirclesLib } from "src/libs/CirclesLib.sol";
import { Subscription } from "src/libs/Types.sol";
import { SubscriptionLib } from "src/libs/SubscriptionLib.sol";

import { IHubV2 } from "@circles/src/hub/IHub.sol";
import { TypeDefinitions } from "@circles/src/hub/TypeDefinitions.sol";
import { Enum } from "@safe-smart-account/contracts/common/Enum.sol";
import { EnumerableSetLib } from "@solady/src/utils/EnumerableSetLib.sol";

contract SubscriptionModule is RevokedNonce {
    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using SubscriptionLib for Subscription;

    using EnumerableSetLib for EnumerableSetLib.Bytes32Set;

    using CirclesLib for bytes;

    using CirclesLib for TypeDefinitions.FlowEdge[];

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    string public constant NAME = "Subscription Module";
    string public constant VERSION = "0.0.1";

    address public constant HUB = 0xc12C1E50ABB450d6205Ea2C3Fa861b3B834d13e8;

    mapping(bytes32 id => address safe) public safeFromId;

    mapping(address safe => mapping(bytes32 id => Subscription subscription)) public subscriptions;

    mapping(address safe => EnumerableSetLib.Bytes32Set) internal ids;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event SubscriptionCreated(bytes32 indexed id, Subscription indexed subscription);

    event Redeemed(bytes32 indexed id, Subscription indexed subscription);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ExecutionFailed();

    error InvalidAmount();

    error IdentifierExists();

    error InvalidFrequency();

    error InvalidRecipient();

    error InvalidSubscriber();

    error NotRedeemable();

    error NotSafe();

    error SingleStreamOnly();

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
        Subscription memory sub = Subscription({
            subscriber: msg.sender,
            recipient: recipient,
            amount: amount,
            lastRedeemed: 0,
            frequency: frequency,
            nonce: nonce
        });

        id = sub.compute();
        require(!ids[msg.sender].contains(id), IdentifierExists());
        require(frequency > 0, InvalidFrequency());

        subscriptions[msg.sender][id] = sub;
        ids[msg.sender].add(id);
        emit SubscriptionCreated(id, sub);
    }

    function redeem(
        bytes32 id,
        address[] calldata flowVertices,
        TypeDefinitions.FlowEdge[] calldata flow,
        TypeDefinitions.Stream[] calldata streams,
        bytes calldata packedCoordinates
    )
        external
    {
        address safe = safeFromId[id];
        Subscription memory sub = subscriptions[safe][id];

        require(sub.lastRedeemed + sub.frequency <= block.timestamp, NotRedeemable());
        require(streams.length == 1, SingleStreamOnly());
        require(flowVertices[streams[0].sourceCoordinate] == sub.subscriber, InvalidSubscriber());
        require(packedCoordinates.extractRecipient(flowVertices) == sub.recipient, InvalidRecipient());
        require(flow.extractAmount() == sub.amount, InvalidAmount());

        sub.lastRedeemed = block.timestamp;

        subscriptions[safe][id] = sub;

        require(
            ISafe(safe).execTransactionFromModule(
                HUB,
                0,
                abi.encodeCall(IHubV2.operateFlowMatrix, (flowVertices, flow, streams, packedCoordinates)),
                Enum.Operation.Call
            ),
            ExecutionFailed()
        );

        emit Redeemed(id, subscriptions[safe][id]);
    }

    /*//////////////////////////////////////////////////////////////
                     USER-FACING CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getSubscriptionIds(address safe) external view returns (bytes32[] memory) {
        return ids[safe].values();
    }
}
