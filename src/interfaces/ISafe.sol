// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import { Enum } from "@safe-smart-account/contracts/common/Enum.sol";

interface ISafe {
    function execTransactionFromModule(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation
    )
        external
        returns (bool success);

    function getOwners() external view returns (address[] memory);

    function enableModule(address module) external;

    function nonce() external view returns (uint256);

    function execTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes memory signatures
    )
        external
        returns (bool success);

    function getTransactionHash(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address refundReceiver,
        uint256 _nonce
    )
        external
        view
        returns (bytes32);
}
