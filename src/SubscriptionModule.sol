// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { ISafe } from "src/interfaces/ISafe.sol";
import { CirclesLib } from "src/libs/CirclesLib.sol";
import { Errors } from "src/libs/Errors.sol";
import { Subscription } from "src/libs/Types.sol";
import { SubscriptionLib } from "src/libs/SubscriptionLib.sol";

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

    using CirclesLib for TypeDefinitions.Stream;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    string public constant NAME = "Subscription Module";
    string public constant VERSION = "0.0.1";

    address public constant HUB = 0xc12C1E50ABB450d6205Ea2C3Fa861b3B834d13e8;

    mapping(bytes32 id => address safe) public safeFromId;

    mapping(address safe => mapping(bytes32 id => Subscription subscription)) public subscriptions;

    mapping(address safe => EnumerableSetLib.Bytes32Set) internal ids;

    mapping(address safe => mapping(uint256 space => mapping(uint256 nonce => bool isRevoked))) internal _revokedNonce;

    mapping(address safe => uint256 space) internal _nonceSpace;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event SubscriptionCreated(bytes32 indexed id, Subscription indexed subscription);

    event Redeemed(bytes32 indexed id, Subscription indexed subscription);

    event NonceRevoked(address indexed owner, uint256 indexed space, uint256 indexed nonce);

    event NonceSpaceRevoked(address indexed owner, uint256 indexed space);

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
        require(!ids[msg.sender].contains(id), Errors.IdentifierExists());
        require(frequency > 0, Errors.InvalidFrequency());

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

        require(isNonceUsable(safe, _nonceSpace[safe], sub.nonce), Errors.SubscriptionCancelled());
        uint256 periods = (block.timestamp - sub.lastRedeemed) / sub.frequency;
        require(periods >= 1, Errors.NotRedeemable());
        TypeDefinitions.Stream memory stream = streams[0];
        require(streams.length == 1, Errors.SingleStreamOnly());
        require(flowVertices[stream.sourceCoordinate] == sub.subscriber, Errors.InvalidSubscriber());
        require(stream.checkRecipients(sub.recipient, flowVertices, packedCoordinates), Errors.InvalidRecipient());
        require(flow.extractAmount() == periods * sub.amount, Errors.InvalidAmount());

        sub.lastRedeemed += periods * sub.frequency;

        subscriptions[safe][id] = sub;

        require(
            ISafe(safe).execTransactionFromModule(
                HUB,
                0,
                abi.encodeCall(IHubV2.operateFlowMatrix, (flowVertices, flow, streams, packedCoordinates)),
                Enum.Operation.Call
            ),
            Errors.ExecutionFailed()
        );

        emit Redeemed(id, subscriptions[safe][id]);
    }

    function cancelAll() external returns (uint256) {
        emit NonceSpaceRevoked(msg.sender, _nonceSpace[msg.sender]);
        return ++_nonceSpace[msg.sender];
    }

    function cancel(bytes32 id) public {
        _revokeNonce(msg.sender, _nonceSpace[msg.sender], subscriptions[msg.sender][id].nonce);
    }

    function cancelMultiple(bytes32[] calldata _ids) external {
        for (uint256 i; i < _ids.length; ++i) {
            cancel(_ids[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////
                     USER-FACING CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getSubscriptionIds(address safe) external view returns (bytes32[] memory) {
        return ids[safe].values();
    }

    function currentNonceSpace(address owner) external view returns (uint256) {
        return _nonceSpace[owner];
    }

    function isNonceUsable(address owner, uint256 nonceSpace, uint256 nonce) public view returns (bool) {
        if (_nonceSpace[owner] != nonceSpace) return false;

        return !_revokedNonce[owner][nonceSpace][nonce];
    }

    function isRedeemable(bytes32 id) public view returns (uint256) {
        address safe = safeFromId[id];
        Subscription memory subscription = subscriptions[safe][id];
        return (block.timestamp - subscription.lastRedeemed) / subscription.frequency * subscription.amount;
    }

    /*//////////////////////////////////////////////////////////////
                    INTERNAL NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _revokeNonce(address safe, uint256 sapce, uint256 nonce) private {
        if (_revokedNonce[safe][sapce][nonce]) {
            revert Errors.NonceAlreadyRevoked({ addr: safe, space: sapce, nonce: nonce });
        }
        _revokedNonce[safe][sapce][nonce] = true;
        emit NonceRevoked(safe, sapce, nonce);
    }
}
