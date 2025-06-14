// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { ISafe } from "src/interfaces/ISafe.sol";
import { IHubV2 } from "src/interfaces/IHub.sol";
import { IMultiSend } from "src/interfaces/IMultiSend.sol";
import { CirclesLib } from "src/libs/CirclesLib.sol";
import { Errors } from "src/libs/Errors.sol";
import { Subscription } from "src/libs/Types.sol";
import { SubscriptionLib } from "src/libs/SubscriptionLib.sol";

import { ERC1155 } from "@circles/src/circles/ERC1155.sol";
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

    address public constant MULTISEND = 0x38869bf66a61cF6bDB996A6aE40D5853Fd43B526;

    bytes32 internal constant NULL_SUBSCRIPTION = 0x868e09d528a16744c1f38ea3c10cc2251e01a456434f91172247695087d129b7;

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
        uint256 lastRedeemed,
        uint256 frequency,
        bool requireTrusted
    );

    event Redeemed(
        bytes32 indexed id,
        address indexed subscriber,
        address indexed recipient,
        uint256 lastRedeemed,
        bool requireTrusted
    );

    event RecipientUpdated(bytes32 indexed id, address indexed oldRecipient, address indexed newRecipient);

    event Unsubscribed(bytes32 indexed id, address indexed subscriber);

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
        _subscribe(id, sub);
        emit SubscriptionCreated(
            id, msg.sender, recipient, amount, block.timestamp - frequency, frequency, requireTrusted
        );
    }

    function redeem(bytes32 id, bytes calldata data) external {
        Subscription memory sub = _subscriptions[id];

        if (IHubV2(HUB).isGroup(sub.recipient)) {
            _redeemGroup(id);
            return;
        }

        if (sub.requireTrusted) {
            (
                address[] memory flowVertices,
                TypeDefinitions.FlowEdge[] memory flow,
                TypeDefinitions.Stream[] memory streams,
                bytes memory packedCoordinates,
                uint256 sourceCoordinate
            ) = abi.decode(data, (address[], TypeDefinitions.FlowEdge[], TypeDefinitions.Stream[], bytes, uint256));
            _redeemTrusted(id, flowVertices, flow, streams, packedCoordinates, sourceCoordinate);
        } else {
            _redeemUntrusted(id);
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
        Subscription memory sub = _subscriptions[id];
        if (!_exists(sub)) return 0;
        return (block.timestamp - sub.lastRedeemed) / sub.frequency * sub.amount;
    }

    /*//////////////////////////////////////////////////////////////
                    INTERNAL NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _subscribe(bytes32 id, Subscription memory sub) internal {
        require(!_exists(sub), Errors.IdentifierExists());
        _subscriptions[id] = sub;
        ids[sub.subscriber].add(id);
    }

    function _unsubscribe(address caller, bytes32 id) internal {
        Subscription memory sub = _subscriptions[id];
        require(_exists(sub), Errors.IdentifierNonexistent());
        require(sub.subscriber == caller, Errors.OnlySubscriber());
        delete _subscriptions[id];
        ids[sub.subscriber].remove(id);
        emit Unsubscribed(id, sub.subscriber);
    }

    function _redeemGroup(bytes32 id) internal {
        Subscription memory sub = _loadSubscription(id);

        uint256 periods = _requireRedeemablePeriods(sub);

        _applyRedemption(id, sub, periods);

        address[] memory collateralAvatars = new address[](1);
        collateralAvatars[0] = sub.subscriber;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = sub.amount;

        /**
         * Steps required to handle group minting for the subscriber
         *   - pull subscriber CRC tokens
         *   - mint group (= recipient) tokens to this module using subscriber CRC collateral
         *     - empty data for now, @todo check group mint policies for requirements
         *   - transfer minted group tokens to the subscriber
         */
        bytes memory call0 = abi.encodeCall(
            ERC1155.safeTransferFrom,
            (sub.subscriber, address(this), _toTokenId(sub.subscriber), periods * sub.amount, "")
        );
        /// @todo empty data for now -- checkout mint policies of existing groups for data requirements
        bytes memory call1 = abi.encodeCall(IHubV2.groupMint, (sub.recipient, collateralAvatars, amounts, ""));
        bytes memory call2 = abi.encodeCall(
            ERC1155.safeTransferFrom,
            (
                address(this),
                sub.subscriber,
                _toTokenId(sub.recipient),
                ERC1155(HUB).balanceOf(address(this), _toTokenId(sub.recipient)),
                ""
            )
        );
        bytes memory transactions = bytes.concat(
            abi.encodePacked(uint8(0), HUB, uint256(0), call0.length, call0),
            abi.encodePacked(uint8(0), HUB, uint256(0), call1.length, call1),
            abi.encodePacked(uint8(0), HUB, uint256(0), call2.length, call2)
        );

        require(
            ISafe(sub.subscriber).execTransactionFromModule(
                MULTISEND, 0, abi.encodeCall(IMultiSend.multiSend, (transactions)), Enum.Operation.DelegateCall
            ),
            Errors.ExecutionFailed()
        );

        emit Redeemed(id, sub.subscriber, sub.recipient, sub.lastRedeemed, sub.requireTrusted);
    }

    function _redeemTrusted(
        bytes32 id,
        address[] memory flowVertices,
        TypeDefinitions.FlowEdge[] memory flow,
        TypeDefinitions.Stream[] memory streams,
        bytes memory packedCoordinates,
        uint256 sourceCoordinate
    )
        internal
    {
        Subscription memory sub = _loadSubscription(id);

        uint256 periods = _requireRedeemablePeriods(sub);

        require(flowVertices[sourceCoordinate] == sub.subscriber, Errors.InvalidSubscriber());

        require(streams.checkSource(sourceCoordinate), Errors.InvalidStreamSource());

        require(streams.checkRecipients(sub.recipient, flowVertices, packedCoordinates), Errors.InvalidRecipient());

        require(flow.extractAmount() == periods * sub.amount, Errors.InvalidAmount());

        _applyRedemption(id, sub, periods);

        require(
            ISafe(sub.subscriber).execTransactionFromModule(
                HUB,
                0,
                abi.encodeCall(IHubV2.operateFlowMatrix, (flowVertices, flow, streams, packedCoordinates)),
                Enum.Operation.Call
            ),
            Errors.ExecutionFailed()
        );

        emit Redeemed(id, sub.subscriber, sub.recipient, sub.lastRedeemed, sub.requireTrusted);
    }

    function _redeemUntrusted(bytes32 id) internal {
        Subscription memory sub = _loadSubscription(id);

        require(!sub.requireTrusted, Errors.TrustedPathOnly());

        uint256 periods = _requireRedeemablePeriods(sub);

        _applyRedemption(id, sub, periods);

        require(
            ISafe(sub.subscriber).execTransactionFromModule(
                HUB,
                0,
                abi.encodeCall(
                    ERC1155.safeTransferFrom,
                    (sub.subscriber, sub.recipient, _toTokenId(sub.subscriber), periods * sub.amount, "")
                ),
                Enum.Operation.Call
            ),
            Errors.ExecutionFailed()
        );

        emit Redeemed(id, sub.subscriber, sub.recipient, sub.lastRedeemed, sub.requireTrusted);
    }

    /*//////////////////////////////////////////////////////////////
                      INTERNAL CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _exists(Subscription memory sub) internal pure returns (bool) {
        return keccak256(abi.encode(sub)) != NULL_SUBSCRIPTION;
    }

    function _loadSubscription(bytes32 id) internal view returns (Subscription memory sub) {
        sub = _subscriptions[id];
        require(_exists(sub), Errors.IdentifierNonexistent());
    }

    function _requireRedeemablePeriods(Subscription memory sub) internal view returns (uint256 periods) {
        periods = (block.timestamp - sub.lastRedeemed) / sub.frequency;
        require(periods >= 1, Errors.NotRedeemable());
    }

    function _applyRedemption(bytes32 id, Subscription memory sub, uint256 periods) internal {
        sub.lastRedeemed += periods * sub.frequency;
        _subscriptions[id] = sub;
    }

    function _toTokenId(address _avatar) internal pure returns (uint256) {
        return uint256(uint160(_avatar));
    }
}
