// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title Revoked Nonce
 * @notice Contract holding revoked nonces.
 * @dev Adapted from PWNDAO/pwn_protocol:
 *      https://github.com/PWNDAO/pwn_protocol/blob/master/src/nonce/PWNRevokedNonce.sol
 */
contract RevokedNonce {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    mapping(address owner => mapping(uint256 space => mapping(uint256 nonce => bool isRevoked))) internal _revokedNonce;

    mapping(address owner => uint256 space) internal _nonceSpace;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event NonceRevoked(address indexed owner, uint256 indexed space, uint256 indexed nonce);

    event NonceSpaceRevoked(address indexed owner, uint256 indexed space);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error NonceAlreadyRevoked(address addr, uint256 space, uint256 nonce);

    /*//////////////////////////////////////////////////////////////
                   USER-FACING NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function revokeNonceSpace() external returns (uint256) {
        emit NonceSpaceRevoked(msg.sender, _nonceSpace[msg.sender]);
        return ++_nonceSpace[msg.sender];
    }

    function revokeNonce(uint256 nonce) external {
        _revokeNonce(msg.sender, _nonceSpace[msg.sender], nonce);
    }

    function revokeNonces(uint256[] calldata nonces) external {
        for (uint256 i; i < nonces.length; ++i) {
            _revokeNonce(msg.sender, _nonceSpace[msg.sender], nonces[i]);
        }
    }

    function revokeNonce(uint256 nonceSpace, uint256 nonce) external {
        _revokeNonce(msg.sender, nonceSpace, nonce);
    }

    /*//////////////////////////////////////////////////////////////
                     USER-FACING CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function currentNonceSpace(address owner) external view returns (uint256) {
        return _nonceSpace[owner];
    }

    function isNonceUsable(address owner, uint256 nonceSpace, uint256 nonce) external view returns (bool) {
        if (_nonceSpace[owner] != nonceSpace) return false;

        return !_revokedNonce[owner][nonceSpace][nonce];
    }

    /*//////////////////////////////////////////////////////////////
                    INTERNAL NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _revokeNonce(address owner, uint256 sapce, uint256 nonce) private {
        if (_revokedNonce[owner][sapce][nonce]) revert NonceAlreadyRevoked({ addr: owner, space: sapce, nonce: nonce });
        _revokedNonce[owner][sapce][nonce] = true;
        emit NonceRevoked(owner, sapce, nonce);
    }
}
