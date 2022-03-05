from secrets import token_urlsafe
import pytest
import asyncio
import math

def uint(a):
    return(a, 0)


@pytest.mark.asyncio
async def test_deposit(defiPooling,token_0,deployer,random_acc,user_1,user_2):
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
    

    amount_to_deposit_user_1 = 40 * (10 ** token_0_decimals)
    
    print("Approve required tokens to be spent by Defi-Pooling")
    await user_1_signer.send_transaction(user_1_account, token_0.contract_address, 'approve', [defiPooling.contract_address, *uint(amount_to_deposit_user_1)])
    
    print("Depositing")
    execution_info = await user_1_signer.send_transaction(user_1_account, defiPooling.contract_address, 'deposit', [
        *uint(amount_to_deposit_user_1), 
        
    ])
    
    total_deposit = execution_info.result.response[0]
    print(f"{total_deposit}")
    
    assert total_deposit == amount_to_deposit_user_1
    
    execution_info = await token_0.balanceOf(user_1_account.contract_address).call()
    user1_token_0_balance = execution_info.result.balance[0]
    print(f"{user1_token_0_balance}")
    
    assert user1_token_0_balance == amount_to_mint_user_1 - amount_to_deposit_user_1
    
    print("Depositing from user_2")
    
    amount_to_deposit_user_2 = 60 * (10 ** token_0_decimals)
    
    print("Approve required tokens to be spent by Defi-Pooling")
    await user_2_signer.send_transaction(user_2_account, token_0.contract_address, 'approve', [defiPooling.contract_address, *uint(amount_to_deposit_user_2)])
    
    print("Depositing")
    execution_info = await user_2_signer.send_transaction(user_2_account, defiPooling.contract_address, 'deposit', [
        *uint(amount_to_deposit_user_2), 
        
    ])
    
    new_total_deposit = execution_info.result.response[0]
    print(f"{new_total_deposit}")
    assert new_total_deposit == total_deposit + amount_to_deposit_user_2
    
    
    print("Verifying total deposit from deposit id")
    
    execution_info = await defiPooling.current_deposit_id().call()
    id = execution_info.result.id[0]
    print(f"{id}")
    
    execution_info = await defiPooling.total_deposit_amount((id,0)).call()
    total_deposit_amount = execution_info.result.total_deposit_amount[0]
    print(f"{total_deposit_amount}")
    
    assert total_deposit_amount == new_total_deposit
    
    
    print("Veryfing the depositors list and amount")
    
    execution_info = await defiPooling.depositors_len((id,0)).call()
    depositors_len = execution_info.result.depositors_len
    print(f"{depositors_len}")
    
    assert depositors_len == 2
    
    execution_info = await defiPooling.depositors((id,0),0).call()
    depositors_1 = execution_info.result.depositors
    print(f"{depositors_1}")
    assert depositors_1 == user_1_account.contract_address

    execution_info = await defiPooling.deposit_amount((id,0),depositors_1).call()
    deposit_amount_user_1 = execution_info.result.deposit_amount[0]
    print(f"{deposit_amount_user_1}")
    assert deposit_amount_user_1 == amount_to_deposit_user_1

    execution_info = await defiPooling.depositors((id,0),1).call()
    depositors_2 = execution_info.result.depositors
    print(f"{depositors_2}")
    assert depositors_2 == user_2_account.contract_address
    
    execution_info = await defiPooling.deposit_amount((id,0),depositors_2).call()
    deposit_amount_user_2 = execution_info.result.deposit_amount[0]
    print(f"{deposit_amount_user_2}")
    assert deposit_amount_user_2 == amount_to_deposit_user_2
    
    
    print("Bridging to L1")
    execution_info = await deployer_signer.send_transaction(deployer_account, defiPooling.contract_address, 'deposit_to_l1', [
        
    ])
    new_deposit_id = execution_info.result.response[0]

    execution_info = await defiPooling.current_deposit_id().call()
    id = execution_info.result.id[0]
    print(f"{id}")
    assert id == new_deposit_id
    assert id == 1 # maunal check also
    
    
    print("Distributing shares receieved from L1 for deposit id 0")
    shares_receieved = 80 * 10**18
    execution_info = await deployer_signer.send_transaction(deployer_account, defiPooling.contract_address, 'distribute_share', [
        token_0.contract_address,  # dummy value check in bypass in contract for unit testing
        *uint(0),
        *uint(shares_receieved)
    ])
    
    print("checking shares balance of depositors")
    
    execution_info = await defiPooling.balanceOf(depositors_1).call()
    share_balance_depositor_1 = execution_info.result.balance[0]
    print(f"{share_balance_depositor_1}")
    assert share_balance_depositor_1 == (shares_receieved * deposit_amount_user_1) / total_deposit_amount
    
    execution_info = await defiPooling.balanceOf(depositors_2).call()
    share_balance_depositor_2 = execution_info.result.balance[0]
    print(f"{share_balance_depositor_2}")
    assert share_balance_depositor_2 == (shares_receieved * deposit_amount_user_2) / total_deposit_amount
    
    


@pytest.mark.asyncio
async def test_cancel_deposit(defiPooling,token_0,deployer,random_acc,user_1,user_2):
    user_1_signer, user_1_account = user_1
    user_2_signer, user_2_account = user_2
    random_signer, random_account = random_acc
    deployer_signer, deployer_account = deployer
    
    print("\nMint loads of tokens_0 to user_1 to deposit")
    execution_info = await token_0.decimals().call()
    token_0_decimals = execution_info.result.decimals
    amount_to_mint_token_0 = 60 * (10 ** token_0_decimals)
    ## Mint token_0 to user_1
    await random_signer.send_transaction(random_account, token_0.contract_address, 'mint', [user_1_account.contract_address, *uint(amount_to_mint_token_0)])
    
    amount_to_deposit = 40 * (10 ** token_0_decimals)
    
    print("Approve required tokens to be spent by Defi-Pooling")
    await user_1_signer.send_transaction(user_1_account, token_0.contract_address, 'approve', [defiPooling.contract_address, *uint(amount_to_deposit)])
    
    print("Depositing")
    execution_info = await user_1_signer.send_transaction(user_1_account, defiPooling.contract_address, 'deposit', [
        *uint(amount_to_deposit), 
        
    ])
    
    total_deposit = execution_info.result.response[0]
    print(f"{total_deposit}")
    
    assert total_deposit == amount_to_deposit
    
    execution_info = await token_0.balanceOf(user_1_account.contract_address).call()
    user1_token_0_balance = execution_info.result.balance[0]
    print(f"{user1_token_0_balance}")
    
    assert user1_token_0_balance == amount_to_mint_token_0 - amount_to_deposit
    
    print("cancelling Deposit")
    execution_info = await user_1_signer.send_transaction(user_1_account, defiPooling.contract_address, 'cancel_deposit', [
        
    ])
    new_total_deposit = execution_info.result.response[0]
    print(f"{new_total_deposit}")
    
    assert new_total_deposit == total_deposit - amount_to_deposit
    
    execution_info = await token_0.balanceOf(user_1_account.contract_address).call()
    user1_token_0_new_balance = execution_info.result.balance[0]
    print(f"{user1_token_0_new_balance}")
    
    assert user1_token_0_new_balance == user1_token_0_balance + amount_to_deposit
    
    
    
    
    