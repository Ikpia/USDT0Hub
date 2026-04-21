#!/bin/bash
set -e

source .env

RPC="https://evmtest.confluxrpc.com"
PK="$PRIVATE_KEY"
DEPLOYER=$(cast wallet address --private-key $PK)

echo "=== USDT0Hub Testnet Deployment ==="
echo "Deployer: $DEPLOYER"
echo "RPC: $RPC"
echo ""

# Check balance
BAL=$(cast balance $DEPLOYER --rpc-url $RPC)
echo "Balance: $BAL wei"
echo ""

# 1. Deploy MockUSDT0
echo "1. Deploying MockUSDT0..."
USDT0=$(forge create src/mocks/MockERC20.sol:MockERC20 \
  --constructor-args "USDT0 (Test)" "USDT0" 6 \
  --rpc-url $RPC --private-key $PK --legacy --broadcast \
  --gas-limit 2000000 2>&1 | grep "Deployed to:" | awk '{print $3}')
echo "   MockUSDT0: $USDT0"

# 2. Deploy MockAxCNH
echo "2. Deploying MockAxCNH..."
AXCNH=$(forge create src/mocks/MockERC20.sol:MockERC20 \
  --constructor-args "AxCNH (Test)" "AxCNH" 18 \
  --rpc-url $RPC --private-key $PK --legacy --broadcast \
  --gas-limit 2000000 2>&1 | grep "Deployed to:" | awk '{print $3}')
echo "   MockAxCNH: $AXCNH"

# 3. Deploy MockPyth
echo "3. Deploying MockPyth..."
PYTH=$(forge create src/mocks/MockPyth.sol:MockPyth \
  --rpc-url $RPC --private-key $PK --legacy --broadcast \
  --gas-limit 1000000 2>&1 | grep "Deployed to:" | awk '{print $3}')
echo "   MockPyth: $PYTH"

# 4. Set Pyth prices
echo "4. Setting Pyth prices..."
USDT_FEED="0x2b89b9dc8fdf9f34709a5b106b472f0f39bb6ca9ce04b0fd7f2e971688e2e53b"
CNH_FEED="0x0000000000000000000000000000000000000000000000000000000000000001"

cast send $PYTH "setPrice(bytes32,int64,uint64,int32)" \
  $USDT_FEED 100000000 1000000 -8 \
  --rpc-url $RPC --private-key $PK --legacy --gas-limit 100000 2>&1 | grep -E "status|transactionHash"

cast send $PYTH "setPrice(bytes32,int64,uint64,int32)" \
  $CNH_FEED 13700000 500000 -8 \
  --rpc-url $RPC --private-key $PK --legacy --gas-limit 100000 2>&1 | grep -E "status|transactionHash"

# 5. Deploy USDT0Router
echo "5. Deploying USDT0Router..."
ROUTER=$(forge create src/USDT0Router.sol:USDT0Router \
  --constructor-args $USDT0 $DEPLOYER $DEPLOYER 75 \
  --rpc-url $RPC --private-key $PK --legacy --broadcast \
  --gas-limit 5000000 2>&1 | grep "Deployed to:" | awk '{print $3}')
echo "   USDT0Router: $ROUTER"

# 6. Deploy USDT0AxCNHPair
echo "6. Deploying USDT0AxCNHPair..."
PAIR=$(forge create src/USDT0AxCNHPair.sol:USDT0AxCNHPair \
  --constructor-args $USDT0 $AXCNH $PYTH $USDT_FEED $CNH_FEED $DEPLOYER \
  --rpc-url $RPC --private-key $PK --legacy --broadcast \
  --gas-limit 5000000 2>&1 | grep "Deployed to:" | awk '{print $3}')
echo "   USDT0AxCNHPair: $PAIR"

# 7. Deploy BridgeReceiver
echo "7. Deploying USDT0BridgeReceiver..."
BRIDGE=$(forge create src/USDT0BridgeReceiver.sol:USDT0BridgeReceiver \
  --constructor-args $USDT0 $ROUTER $DEPLOYER $DEPLOYER \
  --rpc-url $RPC --private-key $PK --legacy --broadcast \
  --gas-limit 3000000 2>&1 | grep "Deployed to:" | awk '{print $3}')
echo "   USDT0BridgeReceiver: $BRIDGE"

# 8. Deploy SponsorManager
echo "8. Deploying USDT0HubSponsorManager..."
SPONSOR=$(forge create src/USDT0HubSponsorManager.sol:USDT0HubSponsorManager \
  --constructor-args $DEPLOYER \
  --rpc-url $RPC --private-key $PK --legacy --broadcast \
  --gas-limit 2000000 2>&1 | grep "Deployed to:" | awk '{print $3}')
echo "   USDT0HubSponsorManager: $SPONSOR"

# 9. Mint test tokens
echo "9. Minting test tokens..."
cast send $USDT0 "mint(address,uint256)" $DEPLOYER 1000000000000 \
  --rpc-url $RPC --private-key $PK --legacy --gas-limit 100000 2>&1 | grep "status"
cast send $AXCNH "mint(address,uint256)" $DEPLOYER 7300000000000000000000000 \
  --rpc-url $RPC --private-key $PK --legacy --gas-limit 100000 2>&1 | grep "status"

echo ""
echo "=== Deployment Complete ==="
echo "MockUSDT0:              $USDT0"
echo "MockAxCNH:              $AXCNH"
echo "MockPyth:               $PYTH"
echo "USDT0Router:            $ROUTER"
echo "USDT0AxCNHPair:         $PAIR"
echo "USDT0BridgeReceiver:    $BRIDGE"
echo "USDT0HubSponsorManager: $SPONSOR"
echo ""
echo "Update frontend/src/config/contracts.ts with these addresses!"
