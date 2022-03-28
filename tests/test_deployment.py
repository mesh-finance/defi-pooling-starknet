import pytest
import asyncio


@pytest.mark.asyncio
async def test_defi_pooling(defiPooling,token_0,deployer,token_name,token_symbol,token_bridge):
    deployer_signer, deployer_account = deployer
    execution_info = await defiPooling.name().call()
    assert execution_info.result[0] == token_name
    execution_info = await defiPooling.symbol().call()
    assert execution_info.result[0] == token_symbol
    execution_info = await defiPooling.decimals().call()
    assert execution_info.result[0] == 18
    execution_info = await defiPooling.owner().call()
    assert execution_info.result[0] == deployer_account.contract_address
    execution_info = await defiPooling.underlying_token().call()
    assert execution_info.result[0] == token_0.contract_address
    execution_info = await defiPooling.token_bridge().call()
    assert execution_info.result[0] == token_bridge.contract_address

