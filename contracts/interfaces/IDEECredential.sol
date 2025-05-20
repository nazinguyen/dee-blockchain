// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IDEECredential {
    struct Credential {
        uint256 tokenId;
        string ipfsHash;
        string credentialType;
        uint256 issueDate;
        address holder;
        bool revoked;
    }

    function mint(
        address to,
        string memory ipfsHash,
        string memory credentialType
    ) external returns (uint256);

    function revoke(uint256 tokenId) external;
    function isRevoked(uint256 tokenId) external view returns (bool);
    function getCredential(uint256 tokenId) external view returns (Credential memory);
    function getCredentialsByHolder(address holder) external view returns (Credential[] memory);
    function getCredentialCount() external view returns (uint256);
    function getActiveCredentialCount() external view returns (uint256);
}
