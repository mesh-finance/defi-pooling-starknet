import asyncio
from starknet_py.contract import Contract
from starknet_py.net.client import Client
from starknet_py.net.account.account_client import AccountClient, KeyPair
from starknet_py.net.models import StarknetChainId
from pathlib import Path
# from common import *
import json

# Local network
local_network = "http://127.0.0.1:5050"
testnet_network = "https://alpha4.starknet.io"
local_network_client = Client(local_network, chain=StarknetChainId.TESTNET)
testnet_network_client = Client('testnet')

def str_to_felt(text):
    b_text = bytes(text, 'UTF-8')
    return int.from_bytes(b_text, "big")

async def main():
    current_network = testnet_network

    if current_network == local_network:
        from config.local import DEPLOYER, deployer_address, defiPooling_address, usdc_address, usdc_decimals, stargate_usdc_bridge
        current_client = local_network_client
        if deployer_address is None:
            deployer = await AccountClient.create_account(current_network, DEPLOYER, chain=StarknetChainId.TESTNET)
        else:
            deployer = AccountClient(address=deployer_address, key_pair=KeyPair.from_private_key(DEPLOYER),  net=current_network, chain=StarknetChainId.TESTNET)
    elif current_network == testnet_network:
        from config.testnet import DEPLOYER, deployer_address, defiPooling_address, usdc_address, usdc_decimals, stargate_usdc_bridge
        current_client = testnet_network_client
        if deployer_address is None:
            deployer = await AccountClient.create_account('testnet', DEPLOYER)
        else:
            deployer = AccountClient(address=deployer_address, key_pair=KeyPair.from_private_key(DEPLOYER),  net='testnet')

    print(f"Deployer Address: {deployer.address}, {hex(deployer.address)}")
    
    
    
    defiPooling = await Contract.from_address(defiPooling_address, deployer)
    defiPooling_with_account = await Contract.from_address(defiPooling.address, deployer)
    # update the argument to L1 contract address (decimal form)
    invocation = await defiPooling_with_account.functions["update_l1_contract"].invoke(668796889076714125739297365269816469093897265064, max_fee=500000000000000)
    await invocation.wait_for_acceptance()
    

if __name__ == "__main__":
    asyncio.run(main())
