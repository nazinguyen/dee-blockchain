// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IBackendController {
    // Events cho monitoring
    event EmergencyStop(address indexed by, uint256 timestamp);
    event EmergencyResume(address indexed by, uint256 timestamp);
    event RateLimitUpdated(uint256 newLimit);
    
    // Access control
    function hasRole(bytes32 role, address account) external view returns (bool);
    function grantRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
    
    // Emergency controls
    function emergencyStop() external;
    function emergencyResume() external;
    
    // Rate limiting
    function setRateLimit(uint256 newLimit) external;
    function checkRateLimit(address user) external view returns (bool);
    
    // Batch operations for backend
    function batchMintCredentials(
        address[] memory recipients,
        string[] memory ipfsHashes,
        string[] memory types
    ) external returns (uint256[] memory);
    
    // Admin functions
    function updateContractConfig(bytes memory config) external;
    function getContractStats() external view returns (
        uint256 totalDIDs,
        uint256 activeDIDs,
        uint256 totalCredentials,
        uint256 activeCredentials
    );
}
