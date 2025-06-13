// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.24;

import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { ICircles } from "@circles/src/circles/ICircles.sol";
import { TypeDefinitions } from "@circles/src/hub/TypeDefinitions.sol";

interface IHubV2 is IERC1155, ICircles {
    function avatars(address avatar) external view returns (address);
    function isHuman(address avatar) external view returns (bool);
    function isGroup(address avatar) external view returns (bool);
    function isOrganization(address avatar) external view returns (bool);

    function groupMint(
        address _group,
        address[] calldata _collateralAvatars,
        uint256[] calldata _amounts,
        bytes calldata _data
    )
        external;

    function migrate(address owner, address[] calldata avatars, uint256[] calldata amounts) external;
    function mintPolicies(address avatar) external view returns (address);

    function operateFlowMatrix(
        address[] calldata _flowVertices,
        TypeDefinitions.FlowEdge[] calldata _flow,
        TypeDefinitions.Stream[] calldata _streams,
        bytes calldata _packedCoordinates
    )
        external;
}
