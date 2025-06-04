// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Module } from "@zodiac/contracts/core/Module.sol";
import { IAvatar } from "@zodiac/contracts/interfaces/IAvatar.sol";
import { Enum } from "@safe-smart-account/contracts/common/Enum.sol";

import { IHubV2 } from "@circles/src/hub/IHub.sol";
import { TypeDefinitions } from "@circles/src/hub/TypeDefinitions.sol";

import { CirclesLib } from "src/CirclesLib.sol";

contract SubscriptionModule is Module {
    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using CirclesLib for bytes;

    using CirclesLib for TypeDefinitions.FlowEdge[];

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Circle Protocol Hub V2 address on Gnosis Chain
    address public constant HUB_ADDRESS = 0xc12C1E50ABB450d6205Ea2C3Fa861b3B834d13e8;

    /// @notice Subscription manager address
    address public constant SUBSCRIPTION_MANAGER = 0x7E9BaF7CC7cD83bACeFB9B2D5c5124C0F9c30834;

    /// @notice Next subscription id
    uint256 private nextId;

    struct Subscription {
        address recipient;
        bool isRecurring;
        uint256 amount;
        uint256 lastRedeemed;
        uint256 frequency;
    }

    /// @notice Mapping for subscription ID to details
    mapping(uint256 id => Subscription subscription) public subscriptions;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the `exec` function call does not succeed.
    error CannotExec();

    /// @notice Thrown when the flow and subscription amounts are not the same.
    error InvalidAmount();

    /// @notice Thrown when the frequency is zero for a recurring subscription.
    error InvalidFrequency();

    /// @notice Thrown when the provided current recipient does not match the subscription recipient
    error InvalidRecipient();

    /// @notice Thrown when it is too soon for subscription redemption.
    error NotRedeemable();

    /// @notice Thrown when the caller is not the subscription manager.
    error OnlyManager();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _owner, address _avatar, address _target) {
        bytes memory initParams = abi.encode(_owner, _avatar, _target);
        setUp(initParams);
    }

    /*//////////////////////////////////////////////////////////////
                              INITIALIZER
    //////////////////////////////////////////////////////////////*/

    function setUp(bytes memory initParams) public override initializer {
        (address _owner, address _avatar, address _target) = abi.decode(initParams, (address, address, address));

        __Ownable_init(msg.sender);

        setAvatar(_avatar);
        setTarget(_target);

        transferOwnership(_owner);
    }

    /*//////////////////////////////////////////////////////////////
                  PERMISSIONED NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    modifier onlyManager() {
        require(msg.sender == SUBSCRIPTION_MANAGER, OnlyManager());
        _;
    }

    /// @notice Creates a new subscription for a recipient with a specified amount and frequency.
    /// @param recipient The address that will receive the subscription payments.
    /// @param isRecurring  True for a recurring subscription; false for a one-off.
    /// @param amount The amount to be paid per interval.
    /// @param frequency The interval in seconds between payments.
    /// @return id The unique ID of the created subscription.
    function subscribe(
        address recipient,
        uint256 amount,
        uint256 frequency,
        bool isRecurring
    )
        external
        onlyManager
        returns (uint256 id)
    {
        id = ++nextId;
        if (isRecurring) {
            require(frequency > 0, InvalidFrequency());
            subscriptions[id] = Subscription({
                recipient: recipient,
                isRecurring: isRecurring,
                amount: amount,
                lastRedeemed: 0,
                frequency: frequency
            });
        } else {
            subscriptions[id] = Subscription({
                recipient: recipient,
                isRecurring: false,
                amount: amount,
                lastRedeemed: 0,
                frequency: 0
            });
        }
    }

    /// @notice Redeems a subscription, verifies recipient and amount, executes the flow, and updates next redeem time.
    /// @param id The subscription ID to redeem.
    /// @param flowVertices The addresses in the flow matrix.
    /// @param flow The array of FlowEdge entries for this flow.
    /// @param streams The array of Stream definitions for this flow.
    /// @param packedCoordinates A bytes blob whose last two bytes encode the recipient index in flowVertices.
    /// @return The next timestamp when this subscription can be redeemed again.
    function redeem(
        uint256 id,
        address[] calldata flowVertices,
        TypeDefinitions.FlowEdge[] calldata flow,
        TypeDefinitions.Stream[] calldata streams,
        bytes calldata packedCoordinates
    )
        external
        onlyManager
        returns (uint256)
    {
        Subscription memory sub = subscriptions[id];
        if (sub.lastRedeemed + sub.frequency > block.timestamp) revert NotRedeemable();

        if (packedCoordinates.extractRecipient(flowVertices) != sub.recipient) revert InvalidRecipient();

        if (flow.extractAmount() != sub.amount) revert InvalidAmount();

        sub.lastRedeemed = block.timestamp;
        subscriptions[id] = sub;

        require(
            exec(
                HUB_ADDRESS,
                0,
                abi.encodeCall(IHubV2.operateFlowMatrix, (flowVertices, flow, streams, packedCoordinates)),
                Enum.Operation.Call
            ),
            CannotExec()
        );

        return (block.timestamp + sub.frequency);
    }

    /// @notice Cancels an existing subscription.
    /// @param id The ID of the subscription to cancel.
    function cancel(uint256 id) external onlyManager {
        delete subscriptions[id];
    }

    /// @notice Updates the recipient for a given subscription.
    /// @param id The ID of the subscription to modify.
    /// @param currentRecipient The address currently on record as the subscription’s recipient.
    /// @param newRecipient The address to set as the new recipient.
    function updateRecipient(uint256 id, address currentRecipient, address newRecipient) external onlyManager {
        Subscription memory sub = subscriptions[id];
        require(sub.recipient == currentRecipient, InvalidRecipient());
        subscriptions[id].recipient = newRecipient;
    }
}
