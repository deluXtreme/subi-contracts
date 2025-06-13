// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { ISafe } from "src/interfaces/ISafe.sol";
import { CirclesLib } from "src/libs/CirclesLib.sol";
import { Errors } from "src/libs/Errors.sol";
import { Subscription } from "src/libs/Types.sol";
import { SubscriptionLib } from "src/libs/SubscriptionLib.sol";

import { ERC1155 } from "@circles/src/circles/ERC1155.sol";
import { IHubV2 } from "@circles/src/hub/IHub.sol";
import { TypeDefinitions } from "@circles/src/hub/TypeDefinitions.sol";
import { Enum } from "@safe-smart-account/contracts/common/Enum.sol";
import { EnumerableSetLib } from "@solady/src/utils/EnumerableSetLib.sol";

contract SubscriptionModule {
    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using SubscriptionLib for Subscription;

    using EnumerableSetLib for EnumerableSetLib.Bytes32Set;

    using CirclesLib for TypeDefinitions.FlowEdge[];

    using CirclesLib for TypeDefinitions.Stream[];

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    string public constant NAME = "Subscription Module";
    string public constant VERSION = "0.1.0";

    address public constant HUB = 0xc12C1E50ABB450d6205Ea2C3Fa861b3B834d13e8;

    mapping(bytes32 id => address safe) public safeFromId;

    mapping(address safe => mapping(bytes32 id => Subscription subscription)) internal _subscriptions;

    mapping(address safe => EnumerableSetLib.Bytes32Set) internal ids;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event SubscriptionCreated(
        bytes32 indexed id,
        address indexed subscriber,
        address indexed recipient,
        uint256 amount,
        uint256 frequency,
        bool requireTrusted
    );

    event Redeemed(bytes32 indexed id, address indexed subscriber, address indexed recipient);

    event RecipientUpdated(bytes32 indexed id, address indexed oldRecipient, address indexed newRecipient);

    /*//////////////////////////////////////////////////////////////
                   USER-FACING NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function subscribe(
        address recipient,
        uint256 amount,
        uint256 frequency,
        bool requireTrusted
    )
        external
        returns (bytes32 id)
    {
        require(frequency > 0, Errors.InvalidFrequency());
        Subscription memory sub = Subscription({
            subscriber: msg.sender,
            recipient: recipient,
            amount: amount,
            lastRedeemed: block.timestamp - frequency,
            frequency: frequency,
            requireTrusted: requireTrusted
        });
        id = sub.compute();
        _subscribe(msg.sender, id, sub);
        emit SubscriptionCreated(id, msg.sender, recipient, amount, frequency, requireTrusted);
    }

    function redeem(
        bytes32 id,
        address[] calldata flowVertices,
        TypeDefinitions.FlowEdge[] calldata flow,
        TypeDefinitions.Stream[] calldata streams,
        bytes calldata packedCoordinates,
        uint256 sourceCoordinate
    )
        external
    {
        (address safe, Subscription memory sub) = _loadSubscription(id);

        uint256 periods = _requireRedeemablePeriods(sub);

        require(flowVertices[sourceCoordinate] == sub.subscriber, Errors.InvalidSubscriber());

        require(streams.checkSource(sourceCoordinate), Errors.InvalidStreamSource());

        require(streams.checkRecipients(sub.recipient, flowVertices, packedCoordinates), Errors.InvalidRecipient());

        require(flow.extractAmount() == periods * sub.amount, Errors.InvalidAmount());

        _applyRedemption(safe, id, sub, periods);

        require(
            ISafe(safe).execTransactionFromModule(
                HUB,
                0,
                abi.encodeCall(IHubV2.operateFlowMatrix, (flowVertices, flow, streams, packedCoordinates)),
                Enum.Operation.Call
            ),
            Errors.ExecutionFailed()
        );

        emit Redeemed(id, safe, sub.recipient);
    }

    function redeemUntrusted(bytes32 id) external {
        (address safe, Subscription memory sub) = _loadSubscription(id);

        require(!sub.requireTrusted, Errors.TrustedPathOnly());

        uint256 periods = _requireRedeemablePeriods(sub);

        _applyRedemption(safe, id, sub, periods);

        require(
            ISafe(safe).execTransactionFromModule(
                HUB,
                0,
                abi.encodeCall(
                    ERC1155.safeTransferFrom,
                    (sub.subscriber, sub.recipient, uint256(uint160(sub.subscriber)), periods * sub.amount, "")
                ),
                Enum.Operation.Call
            ),
            Errors.ExecutionFailed()
        );

        emit Redeemed(id, safe, sub.recipient);
    }

    function unsubscribe(bytes32 id) external {
        _unsubscribe(msg.sender, id);
    }

    function unsubscribeMany(bytes32[] calldata _ids) external {
        for (uint256 i; i < _ids.length; ++i) {
            _unsubscribe(msg.sender, _ids[i]);
        }
    }

    function updateRecipient(bytes32 id, address newRecipient) external {
        address safe = safeFromId[id];
        Subscription storage sub = _subscriptions[safe][id];
        require(sub.recipient == msg.sender, Errors.OnlyRecipient());
        sub.recipient = newRecipient;
        emit RecipientUpdated(id, msg.sender, newRecipient);
    }

    /*//////////////////////////////////////////////////////////////
                     USER-FACING CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getSubscription(bytes32 id) external view returns (Subscription memory) {
        return _subscriptions[safeFromId[id]][id];
    }

    function getSubscriptionIds(address safe) external view returns (bytes32[] memory) {
        return ids[safe].values();
    }

    function isValidOrRedeemable(bytes32 id) public view returns (uint256) {
        Subscription memory subscription = _subscriptions[safeFromId[id]][id];
        return (block.timestamp - subscription.lastRedeemed) / subscription.frequency * subscription.amount;
    }

    function isTrustedRequired(bytes32 id) external view returns (bool) {
        return _subscriptions[safeFromId[id]][id].requireTrusted;
    }

    /*//////////////////////////////////////////////////////////////
                    INTERNAL NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _subscribe(address subscriber, bytes32 id, Subscription memory subscription) internal {
        require(!_exists(id), Errors.IdentifierExists());
        _subscriptions[subscriber][id] = subscription;
        safeFromId[id] = subscriber;
        ids[subscriber].add(id);
    }

    function _unsubscribe(address subscriber, bytes32 id) internal {
        require(_exists(id), Errors.IdentifierNonexistent());
        delete _subscriptions[subscriber][id];
        delete safeFromId[id];
        ids[subscriber].remove(id);
    }

    /*//////////////////////////////////////////////////////////////
                      INTERNAL CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _exists(bytes32 id) internal view returns (bool) {
        return safeFromId[id] != address(0);
    }

    function _loadSubscription(bytes32 id) internal view returns (address safe, Subscription memory sub) {
        require(_exists(id), Errors.IdentifierNonexistent());
        safe = safeFromId[id];
        sub = _subscriptions[safe][id];
    }

    function _requireRedeemablePeriods(Subscription memory sub) internal view returns (uint256 periods) {
        periods = (block.timestamp - sub.lastRedeemed) / sub.frequency;
        require(periods >= 1, Errors.NotRedeemable());
    }

    function _applyRedemption(address safe, bytes32 id, Subscription memory sub, uint256 periods) internal {
        sub.lastRedeemed += periods * sub.frequency;
        _subscriptions[safe][id] = sub;
    }
}
