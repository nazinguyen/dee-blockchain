// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./DIDRegistry.sol";

contract DEECredential is ERC721, Ownable {
    uint256 private _tokenIdCounter;
    DIDRegistry private _didRegistry;

    struct Credential {
        string ipfsHash;
        string credentialType;
        uint256 issueDate;
        address didHolder;    // DID holder's address
    }
    
    mapping(uint256 => Credential) private _credentials;
    
    event CredentialMinted(uint256 indexed tokenId, address indexed recipient, string credentialType);
    event CredentialTransferred(uint256 indexed tokenId, address indexed from, address indexed to);

    // Base URI for token metadata
    string private _baseTokenURI;    constructor(address initialOwner, address didRegistryAddress) ERC721("DEECredential", "DEEC") Ownable(initialOwner) {
        _didRegistry = DIDRegistry(didRegistryAddress);
    }

    // Check if address has valid DID
    modifier hasValidDID(address holder) {
        try _didRegistry.resolveDID(holder) returns (string memory, uint256, bool active) {
            require(active, "DID is not active");
            _;
        } catch Error(string memory reason) {
            revert(reason); // This will pass through "DID does not exist"
        }
    }

    function _incrementTokenId() private returns (uint256) {
        // Hàm nội bộ để tăng bộ đếm và trả về giá trị mới
        _tokenIdCounter++;
        return _tokenIdCounter;
    }

    function mintCredential(
        address recipient,
        string memory ipfsHash,
        string memory credentialType
    ) public onlyOwner hasValidDID(recipient) returns (uint256) {
        uint256 newItemId = _incrementTokenId();
        _mint(recipient, newItemId);
        _credentials[newItemId] = Credential(
            ipfsHash,
            credentialType,
            block.timestamp,
            recipient
        );
        emit CredentialMinted(newItemId, recipient, credentialType);
        return newItemId;
    }    function getCredential(uint256 tokenId)
        public
        view
        returns (string memory, string memory, uint256, address)
    {
        require(_ownerOf(tokenId) != address(0), "Credential does not exist");
        Credential memory cred = _credentials[tokenId];
        return (
            cred.ipfsHash,
            cred.credentialType,
            cred.issueDate,
            cred.didHolder
        );
    }    function transferCredential(address recipient, uint256 tokenId) public hasValidDID(recipient) {
        require(_ownerOf(tokenId) != address(0), "Credential does not exist");
        require(ownerOf(tokenId) == msg.sender, "You are not the owner of this credential");
        
        _credentials[tokenId].didHolder = recipient;
        safeTransferFrom(msg.sender, recipient, tokenId);
        emit CredentialTransferred(tokenId, msg.sender, recipient);
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string memory baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    function updateCredentialMetadata(
        uint256 tokenId,
        string memory newIpfsHash,
        string memory newCredentialType
    ) public onlyOwner {
        require(_ownerOf(tokenId) != address(0), "Credential does not exist");
        _credentials[tokenId].ipfsHash = newIpfsHash;
        _credentials[tokenId].credentialType = newCredentialType;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}