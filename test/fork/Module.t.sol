// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.28 <0.9.0;

import { Fork_Test } from "./Fork.t.sol";

import { stdJson } from "forge-std/StdJson.sol";
import { Enum } from "@safe-smart-account/contracts/common/Enum.sol";
import { ModuleManager } from "@safe-smart-account/contracts/base/ModuleManager.sol";
import { TypeDefinitions } from "@circles/src/hub/TypeDefinitions.sol";

contract Module_Fork_Test is Fork_Test {
    using stdJson for string;

    struct Path {
        address from;
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

    string internal json;

    uint256 internal pk;

    function setUp() public override {
        Fork_Test.setUp();

        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/test/data/inputs.json");
        json = vm.readFile(path);

        pk = vm.envUint("PRIVATE_KEY");
    }

    function test_Scenario_0_manual() external {
        //        bytes memory rawBlob = json.parseRaw(".3");
        //        Path memory path = abi.decode(rawBlob, (Path));
        //
        //        bytes memory txData = abi.encodeCall(ModuleManager.enableModule, (address(module)));
        //
        //        resetPrank({ msgSender: vm.addr(pk) });
        //
        //        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
        //            pk,
        //            ISafe(path.from).getTransactionHash(
        //                path.from,
        //                0,
        //                txData,
        //                Enum.Operation.Call,
        //                0,
        //                0,
        //                0,
        //                address(0),
        //                payable(address(0)),
        //                ISafe(path.from).nonce()
        //            )
        //        );
        //        bytes memory signature = abi.encodePacked(r, s, v);
        //
        //        ISafe(path.from).execTransaction(
        //            path.from, 0, txData, Enum.Operation.Call, 0, 0, 0, address(0), payable(address(0)), signature
        //        );
        //
        //        resetPrank({ msgSender: path.from });
        //        bytes32 id = module.subscribe(path.to, path.value, 3600, true);
        //
        //        TypeDefinitions.FlowEdge[] memory flowEdges = new TypeDefinitions.FlowEdge[](path.inputs.flow.length);
        //        for (uint256 i = 0; i < path.inputs.flow.length; i++) {
        //            // note ordering in TypeDefinitions.FlowEdge is (streamSinkId, amount)
        //            flowEdges[i] = TypeDefinitions.FlowEdge({
        //                streamSinkId: path.inputs.flow[i].streamSinkId,
        //                amount: path.inputs.flow[i].amount
        //            });
        //        }
        //
        //        // allocate and populate Stream[]
        //        TypeDefinitions.Stream[] memory streams = new TypeDefinitions.Stream[](path.inputs.streams.length);
        //        for (uint256 i = 0; i < path.inputs.streams.length; i++) {
        //            // ordering in TypeDefinitions.Stream is (sourceCoordinate, flowEdgeIds, data)
        //            streams[i] = TypeDefinitions.Stream({
        //                sourceCoordinate: path.inputs.streams[i].sourceCoordinate,
        //                flowEdgeIds: path.inputs.streams[i].flowEdgeIds, // dynamic array copies fine
        //                data: path.inputs.streams[i].data
        //            });
        //        }
        //
        //        resetPrank({ msgSender: path.to });
        //        module.redeem(
        //            id,
        //            path.inputs.flowVertices,
        //            flowEdges,
        //            streams,
        //            path.inputs.packedCoordinates,
        //            path.inputs.sourceCoordinate
        //        );
        //    }
    }
}

interface ISafe { }
