// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IFrontendController {
    // Structs
    struct DIDQueryResult {
        string did;
        string ipfsHash;
        uint256 updated;
        bool active;
        address owner;
    }
    
    struct CredentialQueryResult {
        uint256 tokenId;
        string ipfsHash;
        string credentialType;
        uint256 issueDate;
        address holder;
    }
    
    // Events for frontend tracking
    event DIDStatusChanged(string indexed did, bool active);
    event CredentialStatusChanged(uint256 indexed tokenId, bool active);
    
    // Pagination functions for DID
    function getDIDs(uint256 offset, uint256 limit) external view returns (DIDQueryResult[] memory);
    
    // Pagination functions for credentials
    function getCredentials(uint256 offset, uint256 limit) external view returns (CredentialQueryResult[] memory);
    
    // Filter functions
    function getCredentialsByType(string memory credentialType) external view returns (CredentialQueryResult[] memory);
    function getCredentialsByHolder(address holder) external view returns (CredentialQueryResult[] memory);
    
    // Batch operations
    function batchVerifyCredentials(uint256[] memory tokenIds) external view returns (bool[] memory);
    function batchGetDIDStatus(address[] memory identities) external view returns (bool[] memory);
}
