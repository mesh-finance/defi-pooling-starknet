from secrets import token_urlsafe
import pytest
import asyncio
import math

def uint(a):
    return(a, 0)

MESSAGE_WITHDRAWAL_REQUEST = 1
PRECISION = 1000000000


@pytest.mark.asyncio
async def test_redeem(defiPooling,token_0,deployer,random_acc,user_1,user_2,starknet,l1_contract):
    user_1_signer, user_1_account = user_1
    user_2_signer, user_2_account = user_2
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
    
    print("Depositing from user_1")
    amount_to_deposit_user_1 = 40 * (10 ** token_0_decimals)
    await user_1_signer.send_transaction(user_1_account, token_0.contract_address, 'approve', [defiPooling.contract_address, *uint(amount_to_deposit_user_1)])
    execution_info = await user_1_signer.send_transaction(user_1_account, defiPooling.contract_address, 'deposit', [
        *uint(amount_to_deposit_user_1), 
        
    ])
    print("Depositing from user_2")
    amount_to_deposit_user_2 = 60 * (10 ** token_0_decimals)
    await user_2_signer.send_transaction(user_2_account, token_0.contract_address, 'approve', [defiPooling.contract_address, *uint(amount_to_deposit_user_2)])
    execution_info = await user_2_signer.send_transaction(user_2_account, defiPooling.contract_address, 'deposit', [
        *uint(amount_to_deposit_user_2), 
        
    ])

    print("Bridging to L1")
    execution_info = await deployer_signer.send_transaction(deployer_account, defiPooling.contract_address, 'deposit_assets_to_l1', [        
    ])

    
    print("Distributing shares receieved from L1 for deposit id 0")
    shares_receieved = 80 * 10**18
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
    assets_per_share_after_deposit = execution_info.result.assets_per_share[0]
    print(f"{assets_per_share_after_deposit}")
    
    assert float(assets_per_share_after_deposit) == pytest.approx((amount_to_deposit_user_1 + amount_to_deposit_user_2) * PRECISION / shares_receieved)
    
    # execution_info = await deployer_signer.send_transaction(deployer_account, defiPooling.contract_address, 'distribute_share', [
    #     token_0.contract_address,  # dummy value - check is bypass in contract for unit testing
    #     *uint(0),
    #     *uint(shares_receieved)
    # ])
        
    execution_info = await defiPooling.balanceOf(user_1_account.contract_address).call()
    share_balance_user_1 = execution_info.result.balance[0]
    print(f"{share_balance_user_1}")

    
    execution_info = await defiPooling.balanceOf(user_2_account.contract_address).call()
    share_balance_user_2 = execution_info.result.balance[0]
    print(f"{share_balance_user_2}")
    
    # *********** approving to shares token s not required ********************
    # print("Approve shares tokens to be spent by Defi-Pooling")
    # await user_1_signer.send_transaction(user_1_account, defiPooling.contract_address, 'approve', [defiPooling.contract_address, *uint(amount_to_deposit_user_1)])
    # await user_2_signer.send_transaction(user_2_account, defiPooling.contract_address, 'approve', [defiPooling.contract_address, *uint(amount_to_deposit_user_1)])

    shares_to_withdraw_user_1 = share_balance_user_1
    shares_to_withdraw_user_2 = int(int(share_balance_user_2)/2)
    
    print("Redeeming from user_1")
    execution_info = await user_1_signer.send_transaction(user_1_account, defiPooling.contract_address, 'redeem', [
        *uint(shares_to_withdraw_user_1), 
        
    ])
    total_withdraw = execution_info.result.response[0]
    print(f"{total_withdraw}")
    
    assert total_withdraw == shares_to_withdraw_user_1

    execution_info = await defiPooling.balanceOf(user_1_account.contract_address).call()
    user_1_shares_balance = execution_info.result.balance[0]
    print(f"{user_1_shares_balance}")
    
    assert user_1_shares_balance == share_balance_user_1 - shares_to_withdraw_user_1
    
    print("Redeeming from user_2")
    execution_info = await user_2_signer.send_transaction(user_2_account, defiPooling.contract_address, 'redeem', [
        *uint(shares_to_withdraw_user_2), 
        
    ])
    new_total_withdraw = execution_info.result.response[0]
    print(f"{new_total_withdraw}")
    assert new_total_withdraw == total_withdraw + shares_to_withdraw_user_2
    
    execution_info = await defiPooling.balanceOf(user_2_account.contract_address).call()
    user_2_shares_balance = execution_info.result.balance[0]
    print(f"{user_2_shares_balance}")
    
    assert user_2_shares_balance == share_balance_user_2 - shares_to_withdraw_user_2
    
    
    print("Verifying total withdraw from withdraw id")
    
    execution_info = await defiPooling.current_withdraw_id().call()
    id = execution_info.result.id
    print(f"{id}")
    
    execution_info = await defiPooling.total_withdraw_amount(id).call()
    total_withdraw_amount = execution_info.result.total_withdraw_amount[0]
    print(f"{total_withdraw_amount}")
    
    assert total_withdraw_amount == new_total_withdraw
    
    
    print("Veryfing the withdrawers list and amount")
    
    execution_info = await defiPooling.withdraws_len(id).call()
    withdraws_len = execution_info.result.withdraws_len
    print(f"{withdraws_len}")
    
    assert withdraws_len == 2
    
    execution_info = await defiPooling.withdraws(id,0).call()
    withdrawer_1 = execution_info.result.withdrawer
    print(f"{withdrawer_1}")
    assert withdrawer_1 == user_1_account.contract_address

    execution_info = await defiPooling.withdraw_amount(id,withdrawer_1).call()
    withdraw_amount_user_1 = execution_info.result.withdraw_amount[0]
    print(f"{withdraw_amount_user_1}")
    assert withdraw_amount_user_1 == shares_to_withdraw_user_1

    execution_info = await defiPooling.withdraws(id,1).call()
    withdrawer_2 = execution_info.result.withdrawer
    print(f"{withdrawer_2}")
    assert withdrawer_2 == user_2_account.contract_address
    
    execution_info = await defiPooling.withdraw_amount(id,withdrawer_2).call()
    withdraw_amount_user_2 = execution_info.result.withdraw_amount[0]
    print(f"{withdraw_amount_user_2}")
    assert withdraw_amount_user_2 == shares_to_withdraw_user_2
    
    print("Sending withdrawal Request to L1")
    execution_info = await deployer_signer.send_transaction(deployer_account, defiPooling.contract_address, 'send_withdrawal_request_to_l1', [
        
    ])
    new_withdraw_id = execution_info.result.response[0]
    
    payload = [MESSAGE_WITHDRAWAL_REQUEST, 0, *uint(new_total_withdraw)]
    starknet.consume_message_from_l2(
        from_address = defiPooling.contract_address,
        to_address= l1_contract,
        payload=payload,
    )
    execution_info = await defiPooling.current_withdraw_id().call()
    id = execution_info.result.id
    print(f"{id}")
    assert id == new_withdraw_id
    assert id == 1 # manual check also
    
    
    execution_info = await token_0.balanceOf(withdrawer_1).call()
    token_0_balance_withdrawer_1_before = execution_info.result.balance[0]
   
    execution_info = await token_0.balanceOf(withdrawer_2).call()
    token_0_balance_withdrawer_2_before = execution_info.result.balance[0]
    
    print("Distributing underlying token receieved from L1 for withdraw id 0")
    underlying_receieved = 120 * 10**18
    
    print("Minting underlying token to defiPooling contract to distribute")
    await random_signer.send_transaction(random_account, token_0.contract_address, 'mint', [defiPooling.contract_address, *uint(underlying_receieved)])

    tx = await starknet.send_message_to_l2(
        from_address=l1_contract,
        to_address=defiPooling.contract_address,
        selector="handle_distribute_asset",
        payload=[
            0,
            *uint(underlying_receieved)
        ],
    )
    
    execution_info = await defiPooling.assets_per_share().call()
    assets_per_share_after_withdraw = execution_info.result.assets_per_share[0]
    print(f"{assets_per_share_after_withdraw}")
    
    assert float(assets_per_share_after_withdraw) == pytest.approx((underlying_receieved * PRECISION) / new_total_withdraw)
    
    execution_info = await defiPooling.total_assets().call()
    total_assets = execution_info.result.total_assets[0]
    print(f"{total_assets}")
    
    assert float(total_assets) == pytest.approx( assets_per_share_after_withdraw * (shares_receieved-new_total_withdraw) / PRECISION)
    
    # execution_info = await deployer_signer.send_transaction(deployer_account, defiPooling.contract_address, 'distribute_underlying', [
    #     token_0.contract_address,  # dummy value check in bypass in contract for unit testing
    #     *uint(0),
    #     *uint(underlying_receieved)
    # ])
    
    
    print("checking underlying balance of withdrawers")
    
    execution_info = await token_0.balanceOf(withdrawer_1).call()
    token_0_balance_withdrawer_1 = execution_info.result.balance[0]
    print(f"{token_0_balance_withdrawer_1}")
    assert float(token_0_balance_withdrawer_1) == pytest.approx(token_0_balance_withdrawer_1_before + (underlying_receieved * shares_to_withdraw_user_1) / total_withdraw_amount)
    
    execution_info = await token_0.balanceOf(withdrawer_2).call()
    token_0_balance_withdrawer_2 = execution_info.result.balance[0]
    print(f"{token_0_balance_withdrawer_2}")
    assert float(token_0_balance_withdrawer_2) == pytest.approx(token_0_balance_withdrawer_2_before + (underlying_receieved * shares_to_withdraw_user_2) / total_withdraw_amount)
    
    
    print("Checking that the new withdraw are now stored corresponding to updated withdraw id")
    
    shares_to_withdraw_user_2_id_1 = share_balance_user_2 - shares_to_withdraw_user_2
    
    print("Redeeming from user_2 for id_1")
    execution_info = await user_2_signer.send_transaction(user_2_account, defiPooling.contract_address, 'redeem', [
        *uint(shares_to_withdraw_user_2_id_1), 
        
    ])
    total_withdraw_id_1 = execution_info.result.response[0]
    print(f"{total_withdraw_id_1}")
    assert total_withdraw_id_1 == shares_to_withdraw_user_2_id_1
    
    print("Verifying total withdraw from withdraw id for id=1")
    
    execution_info = await defiPooling.current_withdraw_id().call()
    id = execution_info.result.id
    print(f"{id}")
    
    execution_info = await defiPooling.total_withdraw_amount(id).call()
    total_withdraw_amount = execution_info.result.total_withdraw_amount[0]
    print(f"{total_withdraw_amount}")
    
    assert total_withdraw_amount == total_withdraw_id_1
    

    


@pytest.mark.asyncio
async def test_cancel_withdraw(starknet,l1_contract,defiPooling,token_0,deployer,random_acc,user_1,user_2):
    user_1_signer, user_1_account = user_1
    user_2_signer, user_2_account = user_2
    random_signer, random_account = random_acc
    deployer_signer, deployer_account = deployer
    
    print("\nMint loads of tokens_0 to user_1 to deposit")
    execution_info = await token_0.decimals().call()
    token_0_decimals = execution_info.result.decimals
    amount_to_mint_user_1 = 60 * (10 ** token_0_decimals)
    ## Mint token_0 to user_1
    await random_signer.send_transaction(random_account, token_0.contract_address, 'mint', [user_1_account.contract_address, *uint(amount_to_mint_user_1)])
    
    print("Depositing from user_1")
    amount_to_deposit_user_1 = 40 * (10 ** token_0_decimals)
    await user_1_signer.send_transaction(user_1_account, token_0.contract_address, 'approve', [defiPooling.contract_address, *uint(amount_to_deposit_user_1)])
    execution_info = await user_1_signer.send_transaction(user_1_account, defiPooling.contract_address, 'deposit', [
        *uint(amount_to_deposit_user_1), 
        
    ])
    

    print("Bridging to L1")
    execution_info = await deployer_signer.send_transaction(deployer_account, defiPooling.contract_address, 'deposit_assets_to_l1', [        
    ])

    
    print("Distributing shares receieved from L1 for deposit id 0")
    shares_receieved = 80 * 10**18
    tx = await starknet.send_message_to_l2(
        from_address=l1_contract,
        to_address=defiPooling.contract_address,
        selector="handle_distribute_share",
        payload=[
            0,
            *uint(shares_receieved)
        ],
    )
        
    execution_info = await defiPooling.balanceOf(user_1_account.contract_address).call()
    share_balance_user_1 = execution_info.result.balance[0]
    print(f"{share_balance_user_1}")

    shares_to_withdraw_user_1 = share_balance_user_1
    
    print("Redeeming for user_1")
    execution_info = await user_1_signer.send_transaction(user_1_account, defiPooling.contract_address, 'redeem', [
        *uint(shares_to_withdraw_user_1), 
        
    ])
    total_withdraw = execution_info.result.response[0]
    print(f"{total_withdraw}")
    
    assert total_withdraw == shares_to_withdraw_user_1

    execution_info = await defiPooling.current_withdraw_id().call()
    id = execution_info.result.id
    
    execution_info = await defiPooling.balanceOf(user_1_account.contract_address).call()
    user_1_shares_balance = execution_info.result.balance[0]
    print(f"{user_1_shares_balance}")
    
    assert user_1_shares_balance == share_balance_user_1 - shares_to_withdraw_user_1
    
    print("Cancelling withdraw for user_1")
    execution_info = await user_1_signer.send_transaction(user_1_account, defiPooling.contract_address, 'cancel_withdraw', [
        
    ])
    new_total_withdraw = execution_info.result.response[0]
    print(f"{new_total_withdraw}")
    
    assert new_total_withdraw == total_withdraw - shares_to_withdraw_user_1
    
    execution_info = await defiPooling.balanceOf(user_1_account.contract_address).call()
    user1_shares_new_balance = execution_info.result.balance[0]
    print(f"{user1_shares_new_balance}")
    
    assert user1_shares_new_balance == user_1_shares_balance + shares_to_withdraw_user_1
    
    execution_info = await defiPooling.withdraw_amount(id,user_1_account.contract_address).call()
    withdraw_amount_user_1_after_cancel = execution_info.result.withdraw_amount[0]
    assert withdraw_amount_user_1_after_cancel == 0 #manual check
    