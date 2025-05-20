# Deployment Guide

## Prerequisites
1. Node.js v14+ and npm
2. Hardhat environment setup
3. Access to Polygon network (Amoy testnet or Mainnet)
4. MATIC tokens for deployment

## Installation
```bash
npm install
```

## Configuration
1. Create `.env` file with:
```env
PRIVATE_KEY=your_private_key
POLYGONSCAN_API_KEY=your_polygonscan_api_key
POLYGON_RPC_URL=your_polygon_rpc_url
```

## Deployment Steps

### 1. Deploy Contracts
```bash
# Deploy to Amoy testnet
npx hardhat run scripts/deploy-with-did.js --network amoy

# Deploy to Mainnet
npx hardhat run scripts/deploy-with-did.js --network polygon
```

### 2. Verify Contracts
```bash
npx hardhat run scripts/verify-contracts.js --network amoy
```

### 3. Post-Deployment Setup
1. Grant ISSUER_ROLE to trusted parties
2. Set rate limits for operations
3. Configure credential contract parameters
4. Set timelock parameters
   - Verify TIMELOCK_PERIOD is set correctly (24 hours)
   - Test timelock operation flow
5. Configure batch operation limits
   - Verify MAX_BATCH_SIZE_DIDS (100)
   - Verify MAX_BATCH_SIZE_CREDENTIALS (50)
6. Set up monitoring for events
   - Configure event listeners
   - Set up alerts for critical operations
7. Test all security features
   - Verify access controls
   - Test emergency pause
   - Validate timelock operations
8. Unpause the contract

## Testing
```bash
# Run all tests
npx hardhat test

# Run specific test
npx hardhat test test/DIDRegistry.js
```

## Security Considerations
1. Always use MultiSig for admin operations
2. Regularly monitor events
3. Have emergency procedures ready
4. Follow rate limiting best practices
5. Monitor timelock operations
   - Track proposed operations
   - Verify execution times
   - Have procedures for emergency cancellations
6. Configure batch limits appropriately
   - Monitor gas usage patterns
   - Adjust limits based on network conditions
7. Implement proper validation
   - Validate all metadata formats
   - Check credential types against whitelist
   - Verify IPFS hash formats
8. Gas optimization monitoring
   - Track gas usage patterns
   - Monitor batch operation costs
   - Optimize large-scale operations

## Integration Points
1. IPFS Integration
2. Frontend Integration
3. Backend Integration
4. AI Service Integration
