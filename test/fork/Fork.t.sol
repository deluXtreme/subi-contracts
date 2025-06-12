// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.28 <0.9.0;

import { SubscriptionModule } from "src/SubscriptionModule.sol";
import { ISafe } from "src/interfaces/ISafe.sol";

import { Assertions } from "../utils/Assertions.sol";
import { Utils } from "../utils/Utils.sol";

import { IHubV2 } from "@circles/src/hub/IHub.sol";
import { TypeDefinitions } from "@circles/src/hub/TypeDefinitions.sol";
import { Enum } from "@safe-smart-account/contracts/common/Enum.sol";
import { ModuleManager } from "@safe-smart-account/contracts/base/ModuleManager.sol";

abstract contract Fork_Test is Assertions, Utils {
    SubscriptionModule internal module;

    uint256 internal pk = vm.envUint("PRIVATE_KEY");

    address internal constant FROM = 0xeDe0C2E70E8e2d54609c1BdF79595506B6F623FE;

    IHubV2 internal constant hub = IHubV2(0xc12C1E50ABB450d6205Ea2C3Fa861b3B834d13e8);

    /*//////////////////////////////////////////////////////////////
                       ALPHABETICAL-ORDER-STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct FlowInfo {
        Inputs inputs;
        address to;
        uint256 value;
    }

    struct Inputs {
        FlowEdge[] flow;
        address[] flowVertices;
        bytes packedCoordinates;
        uint256 sourceCoordinate;
        Stream[] streams;
    }

    struct FlowEdge {
        uint192 amount;
        uint16 streamSinkId;
    }

    struct Stream {
        bytes data;
        uint16[] flowEdgeIds;
        uint16 sourceCoordinate;
    }

    /*//////////////////////////////////////////////////////////////
                                 SET-UP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        vm.createSelectFork({ blockNumber: 40_531_966, urlOrAlias: "gnosis" });

        module = new SubscriptionModule();
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _toTypeEdge(FlowEdge memory e) internal pure returns (TypeDefinitions.FlowEdge memory) {
        return TypeDefinitions.FlowEdge({ streamSinkId: e.streamSinkId, amount: e.amount });
    }

    function _toTypeStream(Stream memory s) internal pure returns (TypeDefinitions.Stream memory) {
        return
            TypeDefinitions.Stream({ sourceCoordinate: s.sourceCoordinate, flowEdgeIds: s.flowEdgeIds, data: s.data });
    }

    function _toTypeInputs(Inputs memory in_)
        internal
        pure
        returns (
            TypeDefinitions.FlowEdge[] memory flowEdges,
            address[] memory flowVertices,
            bytes memory packedCoordinates,
            uint256 sourceCoordinate,
            TypeDefinitions.Stream[] memory streams
        )
    {
        flowEdges = new TypeDefinitions.FlowEdge[](in_.flow.length);
        for (uint256 i = 0; i < in_.flow.length; i++) {
            flowEdges[i] = _toTypeEdge(in_.flow[i]);
        }
        streams = new TypeDefinitions.Stream[](in_.streams.length);
        for (uint256 j = 0; j < in_.streams.length; j++) {
            streams[j] = _toTypeStream(in_.streams[j]);
        }
        flowVertices = in_.flowVertices;
        packedCoordinates = in_.packedCoordinates;
        sourceCoordinate = in_.sourceCoordinate;
    }

    function _toTypeFlowInfo(FlowInfo memory info)
        internal
        pure
        returns (
            TypeDefinitions.FlowEdge[] memory flowEdges,
            address[] memory flowVertices,
            bytes memory packedCoordinates,
            uint256 sourceCoordinate,
            TypeDefinitions.Stream[] memory streams
        )
    {
        (flowEdges, flowVertices, packedCoordinates, sourceCoordinate, streams) = _toTypeInputs(info.inputs);
    }

    function _enableModule() internal {
        resetPrank({ msgSender: vm.addr(pk) });
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            pk,
            ISafe(FROM).getTransactionHash(
                FROM,
                0,
                abi.encodeCall(ModuleManager.enableModule, (address(module))),
                Enum.Operation.Call,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                ISafe(FROM).nonce()
            )
        );
        ISafe(FROM).execTransaction(
            FROM,
            0,
            abi.encodeCall(ModuleManager.enableModule, (address(module))),
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            abi.encodePacked(r, s, v)
        );
    }
}
