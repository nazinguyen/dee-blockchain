// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./interfaces/IIPFSController.sol";
import "./interfaces/IFrontendController.sol";
import "./interfaces/IBackendController.sol";
import "./interfaces/IDEECredential.sol";

/** 
 * @title DIDRegistry
 * @dev Implementation of Decentralized Identity (DID) registry with credential management
 * @custom:security-contact security@deeproject.com
 */
contract DIDRegistry is Ownable, Pausable, AccessControl, ReentrancyGuard, IIPFSController, IFrontendController, IBackendController {
    using Strings for address;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
    uint256 public constant RATE_LIMIT = 1 minutes;
    uint256 public constant TIMELOCK_PERIOD = 24 hours;
    
    // Timelock system
    struct TimelockOperation {
        bytes32 operationHash;
        uint256 timestamp;
        bool executed;
    }
    
    mapping(bytes32 => TimelockOperation) public timelockOperations;
    
    event OperationQueued(bytes32 indexed operationHash, uint256 timestamp);
    event OperationExecuted(bytes32 indexed operationHash, uint256 timestamp);
    
    // DEECredential contract reference
    IDEECredential public credentialContract;
    
    // Events for credential integration
    event CredentialContractSet(address indexed contractAddress);
    
    // Stats
    uint256 public totalDIDs;
    uint256 public activeDIDs;
    uint256 public rateLimit;
    mapping(address => uint256) public lastActionTimestamp;

    // DID Document structure
    struct DIDDocument {
        string ipfsHash;      // IPFS hash of the DID Document
        uint256 created;      // Creation timestamp
        uint256 updated;      // Last update timestamp
        bool active;          // DID status
        mapping(string => bool) delegates;  // Authorized delegates
        mapping(string => string) metadata; // Additional metadata
    }

    // Mapping from address to DID Document
    mapping(address => DIDDocument) private didDocuments;
    
    // Array to track all DIDs for pagination
    address[] private allDIDs;

    // Registered DIDs mapping
    mapping(string => bool) private registeredDIDs;

    // Events
    event DIDCreated(address indexed identity, string did, string ipfsHash);
    event DIDUpdated(address indexed identity, string did, string newIpfsHash);
    event DIDDeactivated(address indexed identity, string did);
    event DelegateAdded(address indexed identity, string delegate);
    event DelegateRemoved(address indexed identity, string delegate);
    event MetadataAdded(string indexed did, string ipfsHash, uint256 timestamp);
    event MetadataUpdated(string indexed did, string oldIpfsHash, string newIpfsHash, uint256 timestamp);
    event DIDStatusChanged(string indexed did, bool active);
    event EmergencyStop(address indexed by, uint256 timestamp);
    event EmergencyResume(address indexed by, uint256 timestamp);
    event RateLimitUpdated(uint256 newLimit);
    event DIDRegistered(string indexed did, address indexed owner, uint256 timestamp);
    event DIDRevoked(string indexed did, address indexed owner, uint256 timestamp);    constructor(address initialOwner) Ownable(initialOwner) {
        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
        _grantRole(ADMIN_ROLE, initialOwner);
        _grantRole(ISSUER_ROLE, initialOwner);
        rateLimit = RATE_LIMIT;
        _pause(); // Start paused for safety
    }// Create new DID with validation and rate limiting
    function createDID(string memory ipfsHash) public checkRateLimit whenNotPaused returns (string memory) {
        require(bytes(didDocuments[msg.sender].ipfsHash).length == 0, "DID already exists");
        require(validateIPFSHash(ipfsHash), "Invalid IPFS hash format");
        
        string memory did = string(abi.encodePacked("did:dee:", msg.sender.toHexString()));
        
        DIDDocument storage doc = didDocuments[msg.sender];
        doc.ipfsHash = ipfsHash;
        doc.created = block.timestamp;
        doc.updated = block.timestamp;
        doc.active = true;

        totalDIDs++;
        activeDIDs++;
        allDIDs.push(msg.sender);

        emit DIDCreated(msg.sender, did, ipfsHash);
        emit MetadataAdded(did, ipfsHash, block.timestamp);
        return did;
    }    // Update DID Document with validation
    function updateDID(string memory newIpfsHash) public checkRateLimit whenNotPaused {
        require(bytes(didDocuments[msg.sender].ipfsHash).length > 0, "DID does not exist");
        require(didDocuments[msg.sender].active, "DID is not active");
        require(validateIPFSHash(newIpfsHash), "Invalid IPFS hash format");

        string memory oldHash = didDocuments[msg.sender].ipfsHash;
        didDocuments[msg.sender].ipfsHash = newIpfsHash;
        didDocuments[msg.sender].updated = block.timestamp;

        string memory did = string(abi.encodePacked("did:dee:", msg.sender.toHexString()));
        emit MetadataUpdated(did, oldHash, newIpfsHash, block.timestamp);
        emit DIDUpdated(msg.sender, 
            string(abi.encodePacked("did:dee:", msg.sender.toHexString())),
            newIpfsHash
        );
    }    // Deactivate DID with status tracking
    function deactivateDID() public checkRateLimit whenNotPaused {
        require(bytes(didDocuments[msg.sender].ipfsHash).length > 0, "DID does not exist");
        require(didDocuments[msg.sender].active, "DID already deactivated");

        didDocuments[msg.sender].active = false;
        activeDIDs--;

        string memory did = string(abi.encodePacked("did:dee:", msg.sender.toHexString()));
        emit DIDDeactivated(msg.sender, did);
        emit DIDStatusChanged(did, false);
    }

    // Add delegate
    function addDelegate(string memory delegate) public {
        require(bytes(didDocuments[msg.sender].ipfsHash).length > 0, "DID does not exist");
        require(didDocuments[msg.sender].active, "DID is not active");
        require(!didDocuments[msg.sender].delegates[delegate], "Delegate already exists");

        didDocuments[msg.sender].delegates[delegate] = true;
        emit DelegateAdded(msg.sender, delegate);
    }

    // Remove delegate
    function removeDelegate(string memory delegate) public {
        require(bytes(didDocuments[msg.sender].ipfsHash).length > 0, "DID does not exist");
        require(didDocuments[msg.sender].delegates[delegate], "Delegate does not exist");

        didDocuments[msg.sender].delegates[delegate] = false;
        emit DelegateRemoved(msg.sender, delegate);
    }

    // Resolve DID Document
    function resolveDID(address identity) public view returns (
        string memory ipfsHash,
        uint256 updated,
        bool active
    ) {
        require(bytes(didDocuments[identity].ipfsHash).length > 0, "DID does not exist");
        
        DIDDocument storage doc = didDocuments[identity];
        return (doc.ipfsHash, doc.updated, doc.active);
    }

    // Check if delegate is authorized
    function isDelegate(address identity, string memory delegate) public view returns (bool) {
        return didDocuments[identity].delegates[delegate];
    }

    // Credential Management Functions
    function setCredentialContract(address _credentialContract) external onlyRole(ADMIN_ROLE) {
        require(_credentialContract != address(0), "Invalid credential contract address");
        credentialContract = IDEECredential(_credentialContract);
        emit CredentialContractSet(_credentialContract);
    }

    function issueCredential(
        address to,
        string memory ipfsHash,
        string memory credentialType
    ) external onlyRole(ISSUER_ROLE) whenNotPaused returns (uint256) {
        require(address(credentialContract) != address(0), "Credential contract not set");
        require(bytes(didDocuments[to].ipfsHash).length > 0, "Recipient DID not registered");
        require(didDocuments[to].active, "Recipient DID not active");
        require(validateIPFSHash(ipfsHash), "Invalid IPFS hash format");
        require(validateCredentialType(credentialType), "Invalid credential type format");
        
        return credentialContract.mint(to, ipfsHash, credentialType);
    }

    function revokeCredential(uint256 tokenId) external onlyRole(ISSUER_ROLE) whenNotPaused {
        require(address(credentialContract) != address(0), "Credential contract not set");
        credentialContract.revoke(tokenId);
    }

    function getCredentialsByHolder(address holder) external view returns (IDEECredential.Credential[] memory) {
        require(address(credentialContract) != address(0), "Credential contract not set");
        return credentialContract.getCredentialsByHolder(holder);
    }

    // Update getContractStats to include credential stats
    function getContractStats() external view override returns (
        uint256 _totalDIDs,
        uint256 _activeDIDs,
        uint256 totalCredentials,
        uint256 activeCredentials
    ) {
        if (address(credentialContract) != address(0)) {
            totalCredentials = credentialContract.getCredentialCount();
            activeCredentials = credentialContract.getActiveCredentialCount();
        }
        return (totalDIDs, activeDIDs, totalCredentials, activeCredentials);
    }

    // Batch DID operations    function batchCreateDIDs(
        address[] memory identities,
        string[] memory ipfsHashes
    ) external onlyRole(ADMIN_ROLE) {
        require(identities.length == ipfsHashes.length, "Array lengths must match");
        require(identities.length <= 100, "Batch too large"); // Prevent DOS
        
        uint256 timestamp = block.timestamp; // Cache timestamp
        uint256 length = identities.length;  // Cache length
        
        for(uint256 i = 0; i < length;) {
            if(bytes(didDocuments[identities[i]].ipfsHash).length == 0) {
                string memory did = string(abi.encodePacked("did:dee:", identities[i].toHexString()));
                
                DIDDocument storage doc = didDocuments[identities[i]];
                doc.ipfsHash = ipfsHashes[i];
                doc.created = timestamp;
                doc.updated = timestamp;
                doc.active = true;

                unchecked {
                    totalDIDs++;
                    activeDIDs++;
                }
                allDIDs.push(identities[i]);

                emit DIDCreated(identities[i], did, ipfsHashes[i]);
                emit MetadataAdded(did, ipfsHashes[i], timestamp);
            }
            unchecked { ++i; }
        }
    }

    // Config update function
    function updateContractConfig(bytes memory config) external override onlyRole(ADMIN_ROLE) {
        // Config structure: [rateLimit (uint256)]
        require(config.length >= 32, "Invalid config length");
        
        uint256 newRateLimit;
        assembly {
            newRateLimit := mload(add(config, 32))
        }
        
        rateLimit = newRateLimit;
        emit RateLimitUpdated(newRateLimit);
    }

    modifier checkRateLimit() {
        require(block.timestamp - lastActionTimestamp[_msgSender()] >= RATE_LIMIT, "Rate limit exceeded");
        lastActionTimestamp[_msgSender()] = block.timestamp;
        _;
    }

    function registerDID(string calldata did, string calldata ipfsHash) 
        external 
        nonReentrant 
        checkRateLimit 
        whenNotPaused 
    {
        require(!registeredDIDs[did], "DID already registered");
        require(bytes(did).length > 0, "DID cannot be empty");
        require(bytes(ipfsHash).length > 0, "IPFS hash cannot be empty");
        
        registeredDIDs[did] = true;
        emit DIDRegistered(did, _msgSender(), block.timestamp);
    }

    function revokeDID(string calldata did) 
        external 
        nonReentrant 
        whenNotPaused 
        onlyRole(ISSUER_ROLE) 
    {
        require(registeredDIDs[did], "DID not registered");
        
        registeredDIDs[did] = false;
        emit DIDRevoked(did, _msgSender(), block.timestamp);
    }

    function isDIDRegistered(string calldata did) external view returns (bool) {
        return registeredDIDs[did];
    }

    function addIssuer(address issuer) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(ISSUER_ROLE, issuer);
    }

    function removeIssuer(address issuer) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(ISSUER_ROLE, issuer);
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    // IPFS Controller Implementation
    function validateIPFSHash(string memory ipfsHash) public pure returns (bool) {
        bytes memory b = bytes(ipfsHash);
        if (b.length != 46) return false;  // IPFS hash length validation
        if (b[0] != 'Q' && b[0] != 'b') return false;  // IPFS hash prefix validation
        
        for (uint i = 1; i < b.length; i++) {
            bytes1 char = b[i];
            if (
                !(char >= 0x30 && char <= 0x39) && // 0-9
                !(char >= 0x41 && char <= 0x5A) && // A-Z
                !(char >= 0x61 && char <= 0x7A)    // a-z
            ) return false;
        }
        return true;
    }

    function getMetadataStructure(string memory did) external view returns (
        string memory ipfsHash,
        uint256 created,
        uint256 updated,
        bool exists
    ) {
        address identity = addressFromDID(did);
        DIDDocument storage doc = didDocuments[identity];
        
        return (
            doc.ipfsHash,
            doc.created,
            doc.updated,
            bytes(doc.ipfsHash).length > 0
        );
    }

    function addressFromDID(string memory did) internal pure returns (address) {
        // Extract address from DID format "did:dee:<address>"
        bytes memory didBytes = bytes(did);
        require(didBytes.length > 8, "Invalid DID format"); // "did:dee:" + address
        
        bytes memory addrBytes = new bytes(40);
        for(uint i = 0; i < 40 && i + 8 < didBytes.length; i++) {
            addrBytes[i] = didBytes[i + 8];
        }
        
        return address(uint160(uint256(keccak256(addrBytes))));
    }

    // Frontend Controller Implementation
    function getDIDsPaginated(uint256 offset, uint256 limit) external view returns (
        DIDQueryResult[] memory dids,
        uint256 total
    ) {
        uint256 resultCount = limit;
        if (offset + limit > allDIDs.length) {
            resultCount = allDIDs.length - offset;
        }
        
        dids = new DIDQueryResult[](resultCount);
        
        for (uint256 i = 0; i < resultCount; i++) {
            address identity = allDIDs[offset + i];
            DIDDocument storage doc = didDocuments[identity];
            dids[i] = DIDQueryResult({
                did: string(abi.encodePacked("did:dee:", identity.toHexString())),
                ipfsHash: doc.ipfsHash,
                updated: doc.updated,
                active: doc.active,
                owner: identity
            });
        }
        
        return (dids, allDIDs.length);
    }

    function searchDIDs(string memory query) external view returns (
        DIDQueryResult[] memory results
    ) {
        uint256 matchCount = 0;
        
        // First pass: count matches
        for (uint256 i = 0; i < allDIDs.length; i++) {
            address identity = allDIDs[i];
            if (containsQuery(identity.toHexString(), query)) {
                matchCount++;
            }
        }
        
        // Second pass: fill results
        results = new DIDQueryResult[](matchCount);
        uint256 resultIndex = 0;
        
        for (uint256 i = 0; i < allDIDs.length && resultIndex < matchCount; i++) {
            address identity = allDIDs[i];
            if (containsQuery(identity.toHexString(), query)) {
                DIDDocument storage doc = didDocuments[identity];
                results[resultIndex] = DIDQueryResult({
                    did: string(abi.encodePacked("did:dee:", identity.toHexString())),
                    ipfsHash: doc.ipfsHash,
                    updated: doc.updated,
                    active: doc.active,
                    owner: identity
                });
                resultIndex++;
            }
        }
        
        return results;
    }

    function containsQuery(string memory text, string memory query) internal pure returns (bool) {
        bytes memory textBytes = bytes(text);
        bytes memory queryBytes = bytes(query);
        
        if (queryBytes.length > textBytes.length) return false;
        
        for (uint256 i = 0; i <= textBytes.length - queryBytes.length; i++) {
            bool match = true;
            for (uint256 j = 0; j < queryBytes.length; j++) {
                if (textBytes[i + j] != queryBytes[j]) {
                    match = false;
                    break;
                }
            }
            if (match) return true;
        }
        
        return false;
    }

    // Implementation of interface functions will go here
    // ...existing code...

    // Backend Controller Implementation
    function emergencyStop() external override onlyRole(ADMIN_ROLE) {
        _pause();
        emit EmergencyStop(_msgSender(), block.timestamp);
    }

    function emergencyResume() external override onlyRole(ADMIN_ROLE) {
        _unpause();
        emit EmergencyResume(_msgSender(), block.timestamp);
    }

    function setRateLimit(uint256 newLimit) external override onlyRole(ADMIN_ROLE) {
        require(newLimit > 0, "Rate limit must be positive");
        rateLimit = newLimit;
        emit RateLimitUpdated(newLimit);
    }

    function checkRateLimit(address user) external view override returns (bool) {
        return block.timestamp - lastActionTimestamp[user] >= rateLimit;
    }

    // Stats functions
    function getTotalDIDs() external view returns (uint256) {
        return totalDIDs;
    }

    function getActiveDIDs() external view returns (uint256) {
        return activeDIDs;
    }

    function getCurrentRateLimit() external view returns (uint256) {
        return rateLimit;
    }

    // Roles
    function hasRole(bytes32 role, address account) external view override returns (bool) {
        return super.hasRole(role, account);
    }

    function grantRole(bytes32 role, address account) external override onlyRole(ADMIN_ROLE) {
        super.grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) external override onlyRole(ADMIN_ROLE) {
        super.revokeRole(role, account);
    }

    // Batch Credential Operations    function batchIssueCredentials(
        address[] calldata recipients,
        string[] calldata ipfsHashes,
        string[] calldata credentialTypes
    ) external onlyRole(ISSUER_ROLE) whenNotPaused returns (uint256[] memory) {
        require(address(credentialContract) != address(0), "Credential contract not set");
        require(
            recipients.length == ipfsHashes.length && 
            ipfsHashes.length == credentialTypes.length,
            "Array lengths must match"
        );
        require(recipients.length <= 50, "Batch too large"); // Prevent DOS

        uint256[] memory tokenIds = new uint256[](recipients.length);
        uint256 length = recipients.length;
        
        for(uint256 i = 0; i < length;) {
            require(bytes(didDocuments[recipients[i]].ipfsHash).length > 0, "Recipient DID not registered");
            require(didDocuments[recipients[i]].active, "Recipient DID not active");
            require(validateIPFSHash(ipfsHashes[i]), "Invalid IPFS hash format");
            require(validateCredentialType(credentialTypes[i]), "Invalid credential type format");
            
            tokenIds[i] = credentialContract.mint(
                recipients[i],
                ipfsHashes[i],
                credentialTypes[i]
            );
            
            unchecked { ++i; }
        }
        
        return tokenIds;
    }

    function batchRevokeCredentials(
        uint256[] calldata tokenIds
    ) external onlyRole(ISSUER_ROLE) whenNotPaused {
        require(address(credentialContract) != address(0), "Credential contract not set");
        
        for(uint256 i = 0; i < tokenIds.length; i++) {
            credentialContract.revoke(tokenIds[i]);
        }
    }

    // Enhanced credential queries
    function getCredentialStatus(uint256 tokenId) external view returns (bool isValid, address holder) {
        require(address(credentialContract) != address(0), "Credential contract not set");
        IDEECredential.Credential memory cred = credentialContract.getCredential(tokenId);
        return (!cred.revoked && didDocuments[cred.holder].active, cred.holder);
    }

    function getHolderCredentials(
        address holder,
        bool activeOnly
    ) external view returns (IDEECredential.Credential[] memory) {
        require(address(credentialContract) != address(0), "Credential contract not set");
        
        IDEECredential.Credential[] memory allCreds = credentialContract.getCredentialsByHolder(holder);
        if (!activeOnly) return allCreds;
        
        // Count active credentials
        uint256 activeCount = 0;
        for (uint256 i = 0; i < allCreds.length; i++) {
            if (!allCreds[i].revoked && didDocuments[holder].active) {
                activeCount++;
            }
        }
        
        // Filter active credentials
        IDEECredential.Credential[] memory activeCreds = new IDEECredential.Credential[](activeCount);
        uint256 j = 0;
        for (uint256 i = 0; i < allCreds.length && j < activeCount; i++) {
            if (!allCreds[i].revoked && didDocuments[holder].active) {
                activeCreds[j] = allCreds[i];
                j++;
            }
        }
        
        return activeCreds;
    }

    // Enhanced DID queries
    function getDIDsByStatus(bool active, uint256 offset, uint256 limit) external view returns (
        DIDQueryResult[] memory dids,
        uint256 total
    ) {
        uint256 matchCount = 0;
        
        // First pass: count matches
        for (uint256 i = 0; i < allDIDs.length; i++) {
            if (didDocuments[allDIDs[i]].active == active) {
                matchCount++;
            }
        }
        
        uint256 resultCount = limit;
        if (offset >= matchCount) {
            return (new DIDQueryResult[](0), matchCount);
        }
        if (offset + limit > matchCount) {
            resultCount = matchCount - offset;
        }
        
        // Second pass: collect results
        dids = new DIDQueryResult[](resultCount);
        uint256 resultIndex = 0;
        uint256 skipCount = offset;
        
        for (uint256 i = 0; i < allDIDs.length && resultIndex < resultCount; i++) {
            address identity = allDIDs[i];
            if (didDocuments[identity].active == active) {
                if (skipCount > 0) {
                    skipCount--;
                    continue;
                }
                DIDDocument storage doc = didDocuments[identity];
                dids[resultIndex] = DIDQueryResult({
                    did: string(abi.encodePacked("did:dee:", identity.toHexString())),
                    ipfsHash: doc.ipfsHash,
                    updated: doc.updated,
                    active: doc.active,
                    owner: identity
                });
                resultIndex++;
            }
        }
        
        return (dids, matchCount);
    }

    function getDIDMetadata(string memory did) external view returns (
        string[] memory keys,
        string[] memory values
    ) {
        address identity = addressFromDID(did);
        require(bytes(didDocuments[identity].ipfsHash).length > 0, "DID does not exist");
        
        // For now, we return empty arrays as metadata is stored in IPFS
        // This function can be extended in the future to store more on-chain metadata
        return (new string[](0), new string[](0));
    }

    function validateDID(string memory did) external pure returns (bool) {
        if (bytes(did).length < 49) return false; // "did:dee:" + 40 chars address
        
        bytes memory didBytes = bytes(did);
        if (didBytes[0] != 'd' || didBytes[1] != 'i' || didBytes[2] != 'd' ||
            didBytes[3] != ':' || didBytes[4] != 'd' || didBytes[5] != 'e' ||
            didBytes[6] != 'e' || didBytes[7] != ':') {
            return false;
        }
        
        // Validate address part
        for (uint i = 8; i < didBytes.length; i++) {
            bytes1 char = didBytes[i];
            if (
                !(char >= '0' && char <= '9') &&
                !(char >= 'a' && char <= 'f') &&
                !(char >= 'A' && char <= 'F')
            ) return false;
        }
        
        return true;
    }

    // Timelock functions
    function queueOperation(bytes32 operationHash) external onlyRole(ADMIN_ROLE) {
        timelockOperations[operationHash] = TimelockOperation({
            operationHash: operationHash,
            timestamp: block.timestamp,
            executed: false
        });
        
        emit OperationQueued(operationHash, block.timestamp);
    }

    function executeOperation(bytes32 operationHash) external onlyRole(ADMIN_ROLE) {
        TimelockOperation storage op = timelockOperations[operationHash];
        require(op.timestamp > 0, "Operation not found");
        require(!op.executed, "Operation already executed");
        require(block.timestamp >= op.timestamp + TIMELOCK_PERIOD, "Timelock period not yet passed");
        
        op.executed = true;
        
        emit OperationExecuted(operationHash, block.timestamp);
    }

    // Timelock Management Functions
    function queueOperation(bytes32 operationHash) internal {
        timelockOperations[operationHash] = TimelockOperation({
            operationHash: operationHash,
            timestamp: block.timestamp,
            executed: false
        });
        
        emit OperationQueued(operationHash, block.timestamp);
    }
    
    function isOperationReady(bytes32 operationHash) internal view returns (bool) {
        TimelockOperation storage operation = timelockOperations[operationHash];
        return operation.timestamp > 0 && 
               !operation.executed && 
               block.timestamp >= operation.timestamp + TIMELOCK_PERIOD;
    }
    
    function executeOperation(bytes32 operationHash) internal {
        require(isOperationReady(operationHash), "Operation not ready or already executed");
        timelockOperations[operationHash].executed = true;
        emit OperationExecuted(operationHash, block.timestamp);
    }

    // Queue contract configuration update
    function queueContractConfigUpdate(bytes memory config) external onlyRole(ADMIN_ROLE) {
        bytes32 operationHash = keccak256(abi.encodePacked("CONFIG_UPDATE", config));
        queueOperation(operationHash);
    }

    // Update contract config with timelock
    function updateContractConfig(bytes memory config) external override onlyRole(ADMIN_ROLE) {
        bytes32 operationHash = keccak256(abi.encodePacked("CONFIG_UPDATE", config));
        executeOperation(operationHash);
        
        require(config.length >= 32, "Invalid config length");
        uint256 newRateLimit;
        assembly {
            newRateLimit := mload(add(config, 32))
        }
        
        rateLimit = newRateLimit;
        emit RateLimitUpdated(newRateLimit);
    }

    // Enhanced validation functions
    function validateMetadata(string memory metadata) internal pure returns (bool) {
        bytes memory data = bytes(metadata);
        if (data.length == 0 || data.length > 1024) return false;
        
        // Check for valid JSON structure (basic check)
        if (data[0] != '{' || data[data.length - 1] != '}') return false;
        
        // Check for basic JSON format and no script injection
        uint bracketCount = 0;
        for (uint i = 0; i < data.length; i++) {
            if (data[i] == '{') bracketCount++;
            if (data[i] == '}') bracketCount--;
            // Prevent script injection
            if (data[i] == '<' || data[i] == '>') return false;
        }
        
        return bracketCount == 0;
    }

    function validateCredentialType(string memory credentialType) internal pure returns (bool) {
        bytes memory typeData = bytes(credentialType);
        if (typeData.length == 0 || typeData.length > 32) return false;
        
        // Only allow alphanumeric and underscore
        for (uint i = 0; i < typeData.length; i++) {
            bytes1 char = typeData[i];
            if (!(
                (char >= 0x30 && char <= 0x39) || // 0-9
                (char >= 0x41 && char <= 0x5A) || // A-Z
                (char >= 0x61 && char <= 0x7A) || // a-z
                char == 0x5F                      // _
            )) return false;
        }
        
        return true;
    }
}
