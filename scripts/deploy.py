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
    
    ## Deploy defiPooling 
    
    usdc = await Contract.from_address(usdc_address, current_client)
    # print(f"usdc deployed: {usdc.address}, {hex(usdc.address)}")

    bridge_contract = await Contract.from_address(stargate_usdc_bridge, current_client)
    print(f"bridge_contract deployed: {bridge_contract.address}, {hex(bridge_contract.address)}")


    deployment_result = await Contract.deploy(client=current_client, compiled_contract=Path("artifacts/DefiPooling.json").read_text(), constructor_args=[str_to_felt("mesh USDC"),str_to_felt("mUSDC"),usdc.address,bridge_contract.address,deployer.address])
    await deployment_result.wait_for_acceptance()
    defiPooling = deployment_result.deployed_contract
    print(f"defiPooling new deployed: {defiPooling.address}, {hex(defiPooling.address)}")

if __name__ == "__main__":
    asyncio.run(main())
