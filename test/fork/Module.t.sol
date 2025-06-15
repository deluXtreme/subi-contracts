// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.28 <0.9.0;

import { Fork_Test } from "./Fork.t.sol";
import { stdJson } from "forge-std/StdJson.sol";

import { Errors } from "src/libs/Errors.sol";
import { TypeDefinitions } from "@circles/src/hub/TypeDefinitions.sol";

contract Module_Fork_Test is Fork_Test {
    using stdJson for string;

    string internal json;

    function setUp() public override {
        Fork_Test.setUp();

        json = vm.readFile(string.concat(vm.projectRoot(), "/test/data/inputs.json"));
    }

    function test_Scenario_0() external {
        bytes memory rawBlob = json.parseRaw(".0");
        FlowInfo memory info = abi.decode(rawBlob, (FlowInfo));

        _enableModule();

        (
            TypeDefinitions.FlowEdge[] memory flowEdges,
            address[] memory flowVertices,
            bytes memory packedCoordinates,
            uint256 sourceCoordinate,
            TypeDefinitions.Stream[] memory streams
        ) = _toTypeFlowInfo(info);

        resetPrank({ msgSender: FROM });
        bytes32 id = module.subscribe(info.to, info.value, 3600, true);

        resetPrank({ msgSender: info.to });
        bytes memory data = abi.encode(flowVertices, flowEdges, streams, packedCoordinates, sourceCoordinate);
        module.redeem(id, data);
    }

    /// @dev Trusted path fails for this scenario, passes with untrusted flow
    function test_Scenario_1() external {
        bytes memory rawBlob = json.parseRaw(".1");
        FlowInfo memory info = abi.decode(rawBlob, (FlowInfo));

        _enableModule();

        resetPrank({ msgSender: FROM });
        bytes32 id = module.subscribe(info.to, info.value, 3600, false);

        uint256 cachedToBal = hub.balanceOf(info.to, uint256(uint160(FROM)));
        uint256 cachedFromBal = hub.balanceOf(FROM, uint256(uint160(FROM)));

        resetPrank({ msgSender: info.to });
        module.redeem(id, "");

        assertEq(hub.balanceOf(info.to, uint256(uint160(FROM))), cachedToBal + info.value);
        assertEq(hub.balanceOf(FROM, uint256(uint160(FROM))), cachedFromBal - info.value);
    }

    function test_Scenario_1_MultiplePeriods() external {
        uint256 numPeriods = 3;

        bytes memory rawBlob = json.parseRaw(".1");
        FlowInfo memory info = abi.decode(rawBlob, (FlowInfo));

        _enableModule();

        resetPrank({ msgSender: FROM });
        bytes32 id = module.subscribe(info.to, info.value, 3600, false);

        uint256 cachedToBal = hub.balanceOf(info.to, uint256(uint160(FROM)));
        uint256 cachedFromBal = hub.balanceOf(FROM, uint256(uint160(FROM)));

        vm.warp(vm.getBlockTimestamp() + 3600 * (numPeriods - 1));

        resetPrank({ msgSender: info.to });
        module.redeem(id, "");

        assertEq(hub.balanceOf(info.to, uint256(uint160(FROM))), cachedToBal + numPeriods * info.value);
        assertEq(hub.balanceOf(FROM, uint256(uint160(FROM))), cachedFromBal - numPeriods * info.value);
    }

    function test_ShouldRevert_CannotRedeemAfterUnsubscribed() external {
        bytes memory rawBlob = json.parseRaw(".1");
        FlowInfo memory info = abi.decode(rawBlob, (FlowInfo));

        _enableModule();

        resetPrank({ msgSender: FROM });
        bytes32 id = module.subscribe(info.to, info.value, 3600, false);
        module.unsubscribe(id);

        resetPrank({ msgSender: info.to });
        vm.expectRevert(Errors.IdentifierNonexistent.selector);
        module.redeem(id, "");
    }

    function test_ShouldRevert_CannotRedeemAgainImmediately() external {
        bytes memory rawBlob = json.parseRaw(".1");
        FlowInfo memory info = abi.decode(rawBlob, (FlowInfo));

        _enableModule();

        resetPrank({ msgSender: FROM });
        bytes32 id = module.subscribe(info.to, info.value, 3600, false);

        resetPrank({ msgSender: info.to });
        module.redeem(id, "");

        vm.expectRevert(Errors.NotRedeemable.selector);
        module.redeem(id, "");
    }
}
