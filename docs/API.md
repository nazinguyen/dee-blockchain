# DEE Blockchain API Reference

## Smart Contract APIs

### DIDRegistry

#### DID Management

##### createDID
```solidity
function createDID(string memory ipfsHash) external returns (string memory)
```
Creates a new decentralized identity.
- Parameters:
  - ipfsHash: IPFS hash of the DID document
- Returns: DID identifier
- Emits: DIDCreated
- Requirements:
  - Caller doesn't have an existing DID
  - Valid IPFS hash format
  - Contract not paused

##### updateDID
```solidity
function updateDID(string memory newIpfsHash) external
```
Updates DID document hash.
- Parameters:
  - newIpfsHash: New IPFS hash
- Emits: DIDUpdated
- Requirements:
  - Caller owns the DID
  - Valid IPFS hash
  - DID is active

##### deactivateDID
```solidity
function deactivateDID() external
```
Deactivates caller's DID.
- Emits: DIDDeactivated
- Requirements:
  - Caller owns an active DID

#### Delegate Management

##### addDelegate
```solidity
function addDelegate(string memory delegate) external
```
Adds a delegate to caller's DID.
- Parameters:
  - delegate: Delegate identifier
- Emits: DelegateAdded
- Requirements:
  - Caller owns an active DID
  - Delegate doesn't exist

##### removeDelegate
```solidity
function removeDelegate(string memory delegate) external
```
Removes a delegate.
- Parameters:
  - delegate: Delegate identifier
- Emits: DelegateRemoved
- Requirements:
  - Caller owns the DID
  - Delegate exists

#### Credential Management

##### issueCredential
```solidity
function issueCredential(
    address to,
    string memory ipfsHash,
    string memory credentialType
) external returns (uint256)
```
Issues a new credential.
- Parameters:
  - to: Recipient address
  - ipfsHash: Credential metadata hash
  - credentialType: Type of credential
- Returns: Credential token ID
- Requirements:
  - Caller has ISSUER_ROLE
  - Recipient has active DID
  - Valid inputs

##### revokeCredential
```solidity
function revokeCredential(uint256 tokenId) external
```
Revokes a credential.
- Parameters:
  - tokenId: Credential token ID
- Requirements:
  - Caller has ISSUER_ROLE
  - Credential exists and not revoked

#### Batch Operations

##### batchCreateDIDs
```solidity
function batchCreateDIDs(
    address[] memory owners,
    string[] memory ipfsHashes
) external returns (string[] memory)
```
Creates multiple DIDs.
- Parameters:
  - owners: Array of DID owners
  - ipfsHashes: Array of IPFS hashes
- Returns: Array of DID identifiers
- Requirements:
  - Arrays same length
  - Max 100 DIDs per batch
  - Valid inputs

##### batchIssueCredentials
```solidity
function batchIssueCredentials(
    address[] memory recipients,
    string[] memory ipfsHashes,
    string[] memory credentialTypes
) external returns (uint256[] memory)
```
Issues multiple credentials.
- Parameters:
  - recipients: Credential recipients
  - ipfsHashes: Metadata hashes
  - credentialTypes: Credential types
- Returns: Array of token IDs
- Requirements:
  - Arrays same length
  - Max 50 credentials per batch
  - Valid inputs

### DEECredential

#### Token Management

##### mintCredential
```solidity
function mintCredential(
    address recipient,
    string memory ipfsHash,
    string memory credentialType
) external returns (uint256)
```
Mints a new credential token.
- Parameters:
  - recipient: Token recipient
  - ipfsHash: Metadata hash
  - credentialType: Credential type
- Returns: Token ID
- Requirements:
  - Caller is owner
  - Recipient has valid DID

##### transferCredential
```solidity
function transferCredential(
    address recipient,
    uint256 tokenId
) external
```
Transfers a credential.
- Parameters:
  - recipient: New owner
  - tokenId: Token ID
- Requirements:
  - Caller owns token
  - Recipient has valid DID

##### getCredential
```solidity
function getCredential(uint256 tokenId)
    external
    view
    returns (string memory, string memory, uint256, address)
```
Gets credential details.
- Parameters:
  - tokenId: Token ID
- Returns:
  - IPFS hash
  - Credential type
  - Issue date
  - DID holder
- Requirements:
  - Token exists

## Integration APIs

### Frontend Integration

#### getDIDsPaginated
```solidity
function getDIDsPaginated(
    uint256 offset,
    uint256 limit
) external view returns (DIDInfo[] memory)
```
Gets paginated DID list.
- Parameters:
  - offset: Starting index
  - limit: Number of results
- Returns: Array of DID info

#### searchDIDs
```solidity
function searchDIDs(
    string memory query
) external view returns (DIDInfo[] memory)
```
Searches DIDs by query.
- Parameters:
  - query: Search string
- Returns: Matching DIDs

### Backend Integration

#### getContractStats
```solidity
function getContractStats()
    external
    view
    returns (uint256, uint256, uint256, uint256)
```
Gets system statistics.
- Returns:
  - Total DIDs
  - Active DIDs
  - Total credentials
  - Active credentials

#### updateContractConfig
```solidity
function updateContractConfig(
    bytes memory config
) external
```
Updates contract configuration.
- Parameters:
  - config: New configuration
- Requirements:
  - Caller has ADMIN_ROLE
  - Valid configuration

### IPFS Integration

#### validateIPFSHash
```solidity
function validateIPFSHash(
    string memory ipfsHash
) external pure returns (bool)
```
Validates IPFS hash format.
- Parameters:
  - ipfsHash: Hash to validate
- Returns: Is valid

## Events

### DID Events

```solidity
event DIDCreated(string indexed did, address indexed owner, uint256 timestamp)
event DIDUpdated(string indexed did, string newIpfsHash)
event DIDDeactivated(string indexed did)
event DelegateAdded(address indexed identity, string delegate)
event DelegateRemoved(address indexed identity, string delegate)
```

### Credential Events

```solidity
event CredentialMinted(uint256 indexed tokenId, address indexed recipient)
event CredentialRevoked(uint256 indexed tokenId)
event CredentialTransferred(uint256 indexed tokenId, address indexed from, address indexed to)
```

### System Events

```solidity
event RateLimitUpdated(uint256 newLimit)
event EmergencyStop(address indexed by, uint256 timestamp)
event EmergencyResume(address indexed by, uint256 timestamp)
event OperationQueued(bytes32 indexed operationHash, uint256 timestamp)
event OperationExecuted(bytes32 indexed operationHash, uint256 timestamp)
```

## Error Codes

```solidity
error InvalidMetadata()
error UnauthorizedOperation()
error TimelockNotExpired()
error OperationAlreadyExecuted()
error BatchSizeTooLarge()
error InvalidCredentialType()
error DIDNotFound()
error DIDAlreadyExists()
error InvalidDIDFormat()
error InvalidDelegate()
error RateLimitExceeded()
error ContractPaused()
```

## Gas Optimization Guidelines

1. **Batch Operations**
   - Use batch functions for multiple operations
   - Keep batch sizes within limits
   - Handle errors appropriately

2. **Storage**
   - Use calldata for read-only string parameters
   - Minimize on-chain storage
   - Use events for historical data

3. **Computation**
   - Use unchecked blocks for counters
   - Cache frequently accessed values
   - Optimize loops and validations

## Security Best Practices

1. **Access Control**
   - Use appropriate roles
   - Validate caller permissions
   - Implement timelock for critical operations

2. **Input Validation**
   - Validate all parameters
   - Check array lengths
   - Verify formats and types

3. **Rate Limiting**
   - Respect rate limits
   - Handle batch limits
   - Implement cooldown periods

## Integration Guidelines

1. **Frontend Integration**
   - Use view functions for queries
   - Listen to relevant events
   - Implement proper error handling

2. **Backend Integration**
   - Monitor system stats
   - Handle administrative functions
   - Implement proper logging

3. **IPFS Integration**
   - Validate IPFS hashes
   - Handle metadata storage
   - Implement proper caching
