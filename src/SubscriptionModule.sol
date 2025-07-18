// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { ISafe } from "src/interfaces/ISafe.sol";
import { IHubV2 } from "src/interfaces/IHub.sol";
import { IMultiSend } from "src/interfaces/IMultiSend.sol";
import { CirclesLib } from "src/libs/CirclesLib.sol";
import { Errors } from "src/libs/Errors.sol";
import { Subscription, Category } from "src/libs/Types.sol";
import { SubscriptionLib } from "src/libs/SubscriptionLib.sol";

import { ERC1155 } from "@circles/src/circles/ERC1155.sol";
import { TypeDefinitions } from "@circles/src/hub/TypeDefinitions.sol";
import { Enum } from "@safe-smart-account/contracts/common/Enum.sol";
import { EnumerableSetLib } from "@solady/src/utils/EnumerableSetLib.sol";
import { LibTransient } from "@solady/src/utils/LibTransient.sol";

contract SubscriptionModule {
    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using SubscriptionLib for Subscription;

    using EnumerableSetLib for EnumerableSetLib.Bytes32Set;

    using CirclesLib for TypeDefinitions.FlowEdge[];

    using CirclesLib for TypeDefinitions.Stream[];

    using LibTransient for LibTransient.TUint256;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    string public constant NAME = "Subscription Module";
    string public constant VERSION = "0.1.0";

    address public constant HUB = 0xc12C1E50ABB450d6205Ea2C3Fa861b3B834d13e8;

    address public constant MULTISEND = 0x38869bf66a61cF6bDB996A6aE40D5853Fd43B526;

    bytes32 internal constant T_REDEEMABLE_AMOUNT = 0x70bfbb43a5ce660914e09d1b48fcc488982d5981137b973eac35b0592a414e90;

    mapping(bytes32 id => Subscription subscription) internal _subscriptions;

    mapping(address subscriber => EnumerableSetLib.Bytes32Set) internal ids;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event SubscriptionCreated(
        bytes32 indexed id,
        address indexed subscriber,
        address indexed recipient,
        uint256 amount,
        uint256 nextRedeemAt,
        Category category
    );

    event Redeemed(bytes32 indexed id, address indexed subscriber, address indexed recipient, uint256 nextRedeemAt);

    event RecipientUpdated(bytes32 indexed id, address indexed oldRecipient, address indexed newRecipient);

    event Unsubscribed(bytes32 indexed id, address indexed subscriber);

    /*//////////////////////////////////////////////////////////////
                   USER-FACING NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function subscribe(
        address recipient,
        uint256 amount,
        uint256 frequency,
        Category category
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
            category: category
        });
        id = sub.compute();
        _subscribe(id, sub);
        emit SubscriptionCreated(id, msg.sender, recipient, amount, block.timestamp, category);
    }

    function redeem(bytes32 id, bytes calldata data) external {
        Subscription memory sub = _subscriptions[id];
        require(sub.subscriber != address(0), Errors.IdentifierNonexistent());

        uint256 periods = (block.timestamp - sub.lastRedeemed) / sub.frequency;
        require(periods >= 1, Errors.NotRedeemable());

        LibTransient.tUint256(T_REDEEMABLE_AMOUNT).set(periods * sub.amount);
        sub.lastRedeemed += periods * sub.frequency;
        _subscriptions[id] = sub;

        if (sub.category == Category.group) {
            _redeemGroup(id, sub);
        } else if (sub.category == Category.trusted) {
            (
                address[] memory flowVertices,
                TypeDefinitions.FlowEdge[] memory flow,
                TypeDefinitions.Stream[] memory streams,
                bytes memory packedCoordinates,
                uint256 sourceCoordinate
            ) = abi.decode(data, (address[], TypeDefinitions.FlowEdge[], TypeDefinitions.Stream[], bytes, uint256));
            _redeemTrusted(id, sub, flowVertices, flow, streams, packedCoordinates, sourceCoordinate);
        } else if (sub.category == Category.untrusted) {
            _redeemUntrusted(id, sub);
        } else {
            revert Errors.InvalidCategory();
        }
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
        Subscription storage sub = _subscriptions[id];
        require(sub.recipient == msg.sender, Errors.OnlyRecipient());
        sub.recipient = newRecipient;
        emit RecipientUpdated(id, msg.sender, newRecipient);
    }

    /*//////////////////////////////////////////////////////////////
                     USER-FACING CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getSubscription(bytes32 id) external view returns (Subscription memory) {
        return _subscriptions[id];
    }

    function getSubscriptionIds(address subscriber) external view returns (bytes32[] memory) {
        return ids[subscriber].values();
    }

    function isValidOrRedeemable(bytes32 id) public view returns (uint256) {
        if (_subscriptions[id].subscriber == address(0)) return 0;
        Subscription memory sub = _subscriptions[id];
        return (block.timestamp - sub.lastRedeemed) / sub.frequency * sub.amount;
    }

    /*//////////////////////////////////////////////////////////////
                    INTERNAL NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _subscribe(bytes32 id, Subscription memory sub) internal {
        require(_subscriptions[id].subscriber == address(0), Errors.IdentifierExists());
        _subscriptions[id] = sub;
        ids[sub.subscriber].add(id);
    }

    function _unsubscribe(address caller, bytes32 id) internal {
        Subscription memory sub = _subscriptions[id];
        require(sub.subscriber == caller, Errors.OnlySubscriber());
        delete _subscriptions[id];
        ids[sub.subscriber].remove(id);
        emit Unsubscribed(id, sub.subscriber);
    }

    function _redeemGroup(bytes32 id, Subscription memory sub) internal {
        address[] memory collateralAvatars = new address[](1);
        collateralAvatars[0] = sub.subscriber;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = sub.amount;

        require(
            ISafe(sub.subscriber).execTransactionFromModule(
                HUB,
                0,
                abi.encodeCall(IHubV2.groupMint, (sub.recipient, collateralAvatars, amounts, "")),
                Enum.Operation.Call
            ),
            Errors.ExecutionFailed()
        );

        emit Redeemed(id, sub.subscriber, sub.recipient, sub.lastRedeemed + sub.frequency);
        LibTransient.tUint256(T_REDEEMABLE_AMOUNT).clear();
    }

    function _redeemTrusted(
        bytes32 id,
        Subscription memory sub,
        address[] memory flowVertices,
        TypeDefinitions.FlowEdge[] memory flow,
        TypeDefinitions.Stream[] memory streams,
        bytes memory packedCoordinates,
        uint256 sourceCoordinate
    )
        internal
    {
        require(flowVertices[sourceCoordinate] == sub.subscriber, Errors.InvalidSubscriber());

        require(streams.checkSource(sourceCoordinate), Errors.InvalidStreamSource());

        require(streams.checkRecipients(sub.recipient, flowVertices, packedCoordinates), Errors.InvalidRecipient());

        require(flow.extractAmount() == LibTransient.tUint256(T_REDEEMABLE_AMOUNT).get(), Errors.InvalidAmount());

        require(
            ISafe(sub.subscriber).execTransactionFromModule(
                HUB,
                0,
                abi.encodeCall(IHubV2.operateFlowMatrix, (flowVertices, flow, streams, packedCoordinates)),
                Enum.Operation.Call
            ),
            Errors.ExecutionFailed()
        );

        emit Redeemed(id, sub.subscriber, sub.recipient, sub.lastRedeemed + sub.frequency);
        LibTransient.tUint256(T_REDEEMABLE_AMOUNT).clear();
    }

    function _redeemUntrusted(bytes32 id, Subscription memory sub) internal {
        require(
            ISafe(sub.subscriber).execTransactionFromModule(
                HUB,
                0,
                abi.encodeCall(
                    ERC1155.safeTransferFrom,
                    (
                        sub.subscriber,
                        sub.recipient,
                        _toTokenId(sub.subscriber),
                        LibTransient.tUint256(T_REDEEMABLE_AMOUNT).get(),
                        ""
                    )
                ),
                Enum.Operation.Call
            ),
            Errors.ExecutionFailed()
        );

        emit Redeemed(id, sub.subscriber, sub.recipient, sub.lastRedeemed + sub.frequency);
        LibTransient.tUint256(T_REDEEMABLE_AMOUNT).clear();
    }

    /*//////////////////////////////////////////////////////////////
                      INTERNAL CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _toTokenId(address _avatar) internal pure returns (uint256) {
        return uint256(uint160(_avatar));
    }
}
