// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IIPFSController {
    // Sự kiện khi metadata được thêm vào IPFS
    event MetadataAdded(string indexed did, string ipfsHash, uint256 timestamp);
    
    // Sự kiện khi metadata được cập nhật
    event MetadataUpdated(string indexed did, string oldIpfsHash, string newIpfsHash, uint256 timestamp);
    
    // Kiểm tra tính hợp lệ của IPFS hash
    function validateIPFSHash(string memory ipfsHash) external pure returns (bool);
    
    // Lấy metadata structure
    function getMetadataStructure(string memory did) external view returns (
        string memory ipfsHash,
        uint256 created,
        uint256 updated,
        bool exists
    );
    
    // Thêm metadata mới
    function addMetadata(string memory did, string memory ipfsHash) external returns (bool);
    
    // Cập nhật metadata
    function updateMetadata(string memory did, string memory newIpfsHash) external returns (bool);
}
