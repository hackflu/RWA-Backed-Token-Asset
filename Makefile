-include .env

.PHONY: deploy

deploy:
	forge script script/DeployDTsla.s.sol:DeployDTsla \
	--sender 0x0E6A032eD498633a1FB24b3FA96bF99bBBE4B754 \
	--account need --rpc-url ${SEPOLIA_RPC_URL} \
	--etherscan-api-key ${ETHERSCAN_API_KEY} \
	--verify --broadcast