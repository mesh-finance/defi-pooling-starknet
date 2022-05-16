from secrets import token_urlsafe
import pytest
import asyncio
import math
from starkware.starknet.testing.starknet import Starknet
from starkware.starknet.testing.contract import StarknetContract
from starkware.starkware_utils.error_handling import StarkException
from starkware.starknet.definitions.error_codes import StarknetErrorCode
# from conftest import to_split_uint, to_uint

from starkware.starknet.business_logic.transaction_execution_objects import Event
from starkware.starknet.public.abi import get_selector_from_name
from itertools import chain

MESSAGE_DEPOSIT_REQUEST = 2
PRECISION = 1000000000


def uint(a):
    return(a, 0)


@pytest.mark.asyncio
async def test_mint(defiPooling,token_0,deployer,random_acc,user_1,user_2,user_3,l1_contract,starknet):
    user_1_signer, user_1_account = user_1
    user_2_signer, user_2_account = user_2
    user_3_signer, user_3_account = user_3
    random_signer, random_account = random_acc
    deployer_signer, deployer_account = deployer
    
    print("\nMint loads of tokens_0 to user_1 to deposit")
    execution_info = await token_0.decimals().call()
    token_0_decimals = execution_info.result.decimals
    amount_to_mint_user_1 = 60 * (10 ** token_0_decimals)
    ## Mint token_0 to user_1
    await random_signer.send_transaction(random_account, token_0.contract_address, 'mint', [user_1_account.contract_address, *uint(amount_to_mint_user_1)])
    
    print("\nMint loads of tokens_0 to user_2 to deposit")
    execution_info = await token_0.decimals().call()
    token_0_decimals = execution_info.result.decimals
    amount_to_mint_user_2 = 60 * (10 ** token_0_decimals)
    ## Mint token_0 to user_2
    await random_signer.send_transaction(random_account, token_0.contract_address, 'mint', [user_2_account.contract_address, *uint(amount_to_mint_user_2)])
    
    print("\nMint loads of tokens_0 to user_3 to deposit")
    execution_info = await token_0.decimals().call()
    token_0_decimals = execution_info.result.decimals
    amount_to_mint_user_3 = 60 * (10 ** token_0_decimals)
    ## Mint token_0 to user_3
    await random_signer.send_transaction(random_account, token_0.contract_address, 'mint', [user_3_account.contract_address, *uint(amount_to_mint_user_3)])
    


    ###################### Depositing with id=0 to set assets per share.###########################3
    
    amount_to_deposit_user_3 = 10 * (10 ** token_0_decimals)
    
    print("Approve required tokens to be spent by Defi-Pooling")
    await user_3_signer.send_transaction(user_3_account, token_0.contract_address, 'approve', [defiPooling.contract_address, *uint(amount_to_deposit_user_3)])
    
    print("Depositing")
    execution_info = await user_3_signer.send_transaction(user_3_account, defiPooling.contract_address, 'deposit', [
        *uint(amount_to_deposit_user_3), 
        
    ])
    total_deposit_id_0 = execution_info.result.response[0]
    print(f"{total_deposit_id_0}")
    
    print("Bridging to L1")
    execution_info = await deployer_signer.send_transaction(deployer_account, defiPooling.contract_address, 'deposit_assets_to_l1', [
        
    ])
    new_deposit_id = execution_info.result.response[0]
    
    payload = [MESSAGE_DEPOSIT_REQUEST, 0, *uint(total_deposit_id_0)]
    starknet.consume_message_from_l2(
        from_address = defiPooling.contract_address,
        to_address= l1_contract,
        payload=payload,
    )

    execution_info = await defiPooling.current_deposit_id().call()
    id = execution_info.result.id
    print(f"{id}")
    assert id == new_deposit_id
    assert id == 1 # maunal check also
    
    print("Distributing shares receieved from L1 for deposit id 0")

    shares_receieved = 8 * 10**18
    tx = await starknet.send_message_to_l2(
        from_address=l1_contract,
        to_address=defiPooling.contract_address,
        selector="handle_distribute_share",
        payload=[
            0,
            *uint(shares_receieved)
        ],
    )
    
    execution_info = await defiPooling.assets_per_share().call()
    assets_per_share_after_deposit_id_0 = execution_info.result.assets_per_share[0]
    print(f"{assets_per_share_after_deposit_id_0}")
    
    execution_info = await defiPooling.total_assets().call()
    total_assets_after_deposit_id_0 = execution_info.result.total_assets[0]
    print(f"{total_assets_after_deposit_id_0}")
    
    
    ##########################################################################
    ############ asset per share is set Testing mint function ####################
    #########################################################################
    
    shares_decimal = 18
    shares_to_mint_user_1 = 25 * (10 ** shares_decimal)
    expected_asset_required_to_mint_user_1 = int(shares_to_mint_user_1 * assets_per_share_after_deposit_id_0 / PRECISION)
    # expected_asset_required_to_approve_user_1 = expected_asset_required_to_mint_user_1 + (10 *10** shares_decimal)
    
    execution_info = await token_0.balanceOf(user_1_account.contract_address).call()
    user1_token_0_balance_before = execution_info.result.balance[0]
    print(f"{user1_token_0_balance_before}")
    
    print("Approve required tokens to be spent by Defi-Pooling")
    await user_1_signer.send_transaction(user_1_account, token_0.contract_address, 'approve', [defiPooling.contract_address, *uint(expected_asset_required_to_mint_user_1)])
    
    print("Minting shares from user 1")
    execution_info = await user_1_signer.send_transaction(user_1_account, defiPooling.contract_address, 'mint', [
        *uint(shares_to_mint_user_1), 
        
    ])
    
    total_deposit = execution_info.result.response[0]
    print(f"{total_deposit}")
    
    assert total_deposit == expected_asset_required_to_mint_user_1
    
    execution_info = await token_0.balanceOf(user_1_account.contract_address).call()
    user1_token_0_balance = execution_info.result.balance[0]
    print(f"{user1_token_0_balance}")
    
    assert user1_token_0_balance == user1_token_0_balance_before - expected_asset_required_to_mint_user_1
    
    print("Minting shares from user_2")
    
    shares_to_mint_user_2 = 35 * (10 ** shares_decimal)
    expected_asset_required_to_mint_user_2 = int(shares_to_mint_user_2 * assets_per_share_after_deposit_id_0 / PRECISION)
        
    print("Approve required tokens to be spent by Defi-Pooling")
    await user_2_signer.send_transaction(user_2_account, token_0.contract_address, 'approve', [defiPooling.contract_address, *uint(expected_asset_required_to_mint_user_2)])
    
    print("Minting")
    execution_info = await user_2_signer.send_transaction(user_2_account, defiPooling.contract_address, 'mint', [
        *uint(shares_to_mint_user_2), 
        
    ])
    
    new_total_deposit = execution_info.result.response[0]
    print(f"{new_total_deposit}")
    assert new_total_deposit == total_deposit + expected_asset_required_to_mint_user_2
    
    
    print("Verifying total deposit from deposit id")
    
    execution_info = await defiPooling.current_deposit_id().call()
    id = execution_info.result.id
    print(f"{id}")
    
    execution_info = await defiPooling.total_deposit_amount(id).call()
    total_deposit_amount = execution_info.result.total_deposit_amount[0]
    print(f"{total_deposit_amount}")
    
    assert total_deposit_amount == new_total_deposit
    
    
    print("Veryfing the depositors list and amount")
    
    execution_info = await defiPooling.depositors_len(id).call()
    depositors_len = execution_info.result.depositors_len
    print(f"{depositors_len}")
    
    assert depositors_len == 2 #manual check
    
    execution_info = await defiPooling.depositors(id,0).call()
    depositors_1 = execution_info.result.depositors
    print(f"{depositors_1}")
    assert depositors_1 == user_1_account.contract_address

    execution_info = await defiPooling.deposit_amount(id,depositors_1).call()
    deposit_amount_user_1 = execution_info.result.deposit_amount[0]
    print(f"{deposit_amount_user_1}")
    assert deposit_amount_user_1 == expected_asset_required_to_mint_user_1

    execution_info = await defiPooling.depositors(id,1).call()
    depositors_2 = execution_info.result.depositors
    print(f"{depositors_2}")
    assert depositors_2 == user_2_account.contract_address
    
    execution_info = await defiPooling.deposit_amount(id,depositors_2).call()
    deposit_amount_user_2 = execution_info.result.deposit_amount[0]
    print(f"{deposit_amount_user_2}")
    assert deposit_amount_user_2 == expected_asset_required_to_mint_user_2
    
    
    print("Bridging to L1")
    execution_info = await deployer_signer.send_transaction(deployer_account, defiPooling.contract_address, 'deposit_assets_to_l1', [
        
    ])
    new_deposit_id = execution_info.result.response[0]
    
    payload = [MESSAGE_DEPOSIT_REQUEST, 1, *uint(new_total_deposit)]
    starknet.consume_message_from_l2(
        from_address = defiPooling.contract_address,
        to_address= l1_contract,
        payload=payload,
    )

    execution_info = await defiPooling.current_deposit_id().call()
    id = execution_info.result.id
    print(f"{id}")
    assert id == new_deposit_id
    assert id == 2 # maunal check also
    
    print("Distributing shares receieved from L1 for deposit id 1")
    # calculating shares receieved by keeping assets per share constant (so that shares_to_mint == actual shares minted)
    shares_receieved = int((new_total_deposit * PRECISION) / assets_per_share_after_deposit_id_0)
    
    tx = await starknet.send_message_to_l2(
        from_address=l1_contract,
        to_address=defiPooling.contract_address,
        selector="handle_distribute_share",
        payload=[
            1,
            *uint(shares_receieved)
        ],
    )
    
    execution_info = await defiPooling.assets_per_share().call()
    assets_per_share_after_deposit_id_1 = execution_info.result.assets_per_share[0]
    print(f"{assets_per_share_after_deposit_id_1}")
    
    assert float(assets_per_share_after_deposit_id_1) == pytest.approx((new_total_deposit*PRECISION) / shares_receieved)
    
    execution_info = await defiPooling.total_assets().call()
    total_assets_after_deposit_id_1 = execution_info.result.total_assets[0]
    print(f"{total_assets_after_deposit_id_1}")
    
    assert float(total_assets_after_deposit_id_1) == pytest.approx(total_assets_after_deposit_id_0 + new_total_deposit)

    
    # execution_info = await deployer_signer.send_transaction(deployer_account, defiPooling.contract_address, 'handle_distribute_share', [
    #     token_0.contract_address,  # dummy value check in bypass in contract for unit testing
    #     *uint(0),
    #     *uint(shares_receieved)
    # ])
    
    print("checking shares balance of depositors")
    
    execution_info = await defiPooling.balanceOf(depositors_1).call()
    share_balance_depositor_1 = execution_info.result.balance[0]
    print(f"{share_balance_depositor_1}")
    assert share_balance_depositor_1 == shares_to_mint_user_1
    
    execution_info = await defiPooling.assetsOf(user_1_account.contract_address).call()
    assets_of_user_1 = execution_info.result.assets_of[0]
    # print(f"{assets_of_user_1}")
    assert float(assets_of_user_1) == pytest.approx(expected_asset_required_to_mint_user_1)
    
    execution_info = await defiPooling.balanceOf(depositors_2).call()
    share_balance_depositor_2 = execution_info.result.balance[0]
    print(f"{share_balance_depositor_2}")
    assert share_balance_depositor_2 == shares_to_mint_user_2
    
    execution_info = await defiPooling.assetsOf(user_2_account.contract_address).call()
    assets_of_user_2 = execution_info.result.assets_of[0]
    # print(f"{assets_of_user_2}")
    assert float(assets_of_user_2) == pytest.approx(expected_asset_required_to_mint_user_2)
    


@pytest.mark.asyncio
async def test_cancel_deposit(starknet,defiPooling,token_0,deployer,random_acc,user_1,user_2,l1_contract):
    user_1_signer, user_1_account = user_1
    user_2_signer, user_2_account = user_2
    random_signer, random_account = random_acc
    deployer_signer, deployer_account = deployer
    
    
    print("\nMint loads of tokens_0 to user_2 to deposit")
    execution_info = await token_0.decimals().call()
    token_0_decimals = execution_info.result.decimals
    amount_to_mint_token_0 = 60 * (10 ** token_0_decimals)
    ## Mint token_0 to user_2
    await random_signer.send_transaction(random_account, token_0.contract_address, 'mint', [user_2_account.contract_address, *uint(amount_to_mint_token_0)])
    
    
     ###################### Depositing with id=0 to set assets per share.###########################3
    
    amount_to_deposit_user_2 = 10 * (10 ** token_0_decimals)
    
    print("Approve required tokens to be spent by Defi-Pooling")
    await user_2_signer.send_transaction(user_2_account, token_0.contract_address, 'approve', [defiPooling.contract_address, *uint(amount_to_deposit_user_2)])
    
    print("Depositing")
    execution_info = await user_2_signer.send_transaction(user_2_account, defiPooling.contract_address, 'deposit', [
        *uint(amount_to_deposit_user_2), 
        
    ])
    total_deposit_id_0 = execution_info.result.response[0]
    print(f"{total_deposit_id_0}")
    
    print("Bridging to L1")
    execution_info = await deployer_signer.send_transaction(deployer_account, defiPooling.contract_address, 'deposit_assets_to_l1', [
        
    ])
    new_deposit_id = execution_info.result.response[0]
    
    payload = [MESSAGE_DEPOSIT_REQUEST, 0, *uint(total_deposit_id_0)]
    starknet.consume_message_from_l2(
        from_address = defiPooling.contract_address,
        to_address= l1_contract,
        payload=payload,
    )

    execution_info = await defiPooling.current_deposit_id().call()
    id = execution_info.result.id
    
    print("Distributing shares receieved from L1 for deposit id 0")

    shares_receieved = 8 * 10**18
    tx = await starknet.send_message_to_l2(
        from_address=l1_contract,
        to_address=defiPooling.contract_address,
        selector="handle_distribute_share",
        payload=[
            0,
            *uint(shares_receieved)
        ],
    )
    
    execution_info = await defiPooling.assets_per_share().call()
    assets_per_share_after_deposit_id_0 = execution_info.result.assets_per_share[0]
    
    
    ##########################################################################
    ############ asset per share is set Testing mint function ####################
    #########################################################################
    
    
    print("\nMint loads of tokens_0 to user_1 to deposit")
    execution_info = await token_0.decimals().call()
    token_0_decimals = execution_info.result.decimals
    amount_to_mint_token_0 = 60 * (10 ** token_0_decimals)
    ## Mint token_0 to user_1
    await random_signer.send_transaction(random_account, token_0.contract_address, 'mint', [user_1_account.contract_address, *uint(amount_to_mint_token_0)])
    
    shares_decimal = 18
    shares_to_mint_user_1 = 25 * (10 ** shares_decimal)
    expected_asset_required_to_mint_user_1 = int(shares_to_mint_user_1 * assets_per_share_after_deposit_id_0 / PRECISION)
    
    print("Approve required tokens to be spent by Defi-Pooling")
    await user_1_signer.send_transaction(user_1_account, token_0.contract_address, 'approve', [defiPooling.contract_address, *uint(expected_asset_required_to_mint_user_1)])
    
    print("Depositing")
    execution_info = await user_1_signer.send_transaction(user_1_account, defiPooling.contract_address, 'mint', [
        *uint(shares_to_mint_user_1), 
        
    ])
    total_deposit = execution_info.result.response[0]
    print(f"{total_deposit}")
    
    assert total_deposit == expected_asset_required_to_mint_user_1
    
    execution_info = await token_0.balanceOf(user_1_account.contract_address).call()
    user1_token_0_balance = execution_info.result.balance[0]
    print(f"{user1_token_0_balance}")
    
    assert user1_token_0_balance == amount_to_mint_token_0 - expected_asset_required_to_mint_user_1
    
    execution_info = await defiPooling.current_deposit_id().call()
    id = execution_info.result.id
    
    execution_info = await defiPooling.depositors(id,0).call()
    depositors_1 = execution_info.result.depositors
    print(f"{depositors_1}")
    assert depositors_1 == user_1_account.contract_address

    execution_info = await defiPooling.deposit_amount(id,depositors_1).call()
    deposit_amount_user_1 = execution_info.result.deposit_amount[0]
    print(f"{deposit_amount_user_1}")
    assert deposit_amount_user_1 == expected_asset_required_to_mint_user_1
    
    print("cancelling Deposit")
    execution_info = await user_1_signer.send_transaction(user_1_account, defiPooling.contract_address, 'cancel_deposit', [
        
    ])
    new_total_deposit = execution_info.result.response[0]
    print(f"{new_total_deposit}")
    
    assert new_total_deposit == total_deposit - expected_asset_required_to_mint_user_1
    
    execution_info = await token_0.balanceOf(user_1_account.contract_address).call()
    user1_token_0_new_balance = execution_info.result.balance[0]
    print(f"{user1_token_0_new_balance}")
    
    assert user1_token_0_new_balance == user1_token_0_balance + expected_asset_required_to_mint_user_1
    
    execution_info = await defiPooling.deposit_amount(id,user_1_account.contract_address).call()
    deposit_amount_user_1_after_cancel = execution_info.result.deposit_amount[0]
    print(f"{deposit_amount_user_1_after_cancel}")
    assert deposit_amount_user_1_after_cancel == 0 #manual check
    
    
    
    
    