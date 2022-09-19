%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.starknet.common.syscalls import get_caller_address, deploy, get_contract_address
from starkware.cairo.common.uint256 import Uint256, uint256_add, uint256_sub, uint256_unsigned_div_rem
from starkware.cairo.common.pow import pow
from starkware.cairo.common.alloc import alloc
from contracts.utils.math import uint256_checked_mul
from tests.protostar_tests.interfaces import IDefiPooling, ITokenBridge, IERC20

const PRECISION = 1000000000

@external
func __setup__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}():
    alloc_locals

    local deployer_signer = 1
    local user_1_signer = 2
    local user_2_signer = 3
    local deployer_address
    local token_0_address
    local token_bridge_address
    local l1_contract = 907507751940624169017 # str_to_felt('123456789')
    local l1_bridge_contract = 1055515178193424429617 # str_to_felt('987654321')
    local contract_address

    %{
        context.deployer_signer = ids.deployer_signer
        context.user_1_signer = ids.user_1_signer
        context.user_2_signer = ids.user_2_signer
        context.l1_contract = ids.l1_contract
        context.l1_bridge_contract = ids.l1_bridge_contract
        context.user_1_address = deploy_contract("./contracts/test/Account.cairo", [context.user_1_signer]).contract_address
        context.user_2_address = deploy_contract("./contracts/test/Account.cairo", [context.user_2_signer]).contract_address
        context.deployer_address = deploy_contract("./contracts/test/Account.cairo", [context.deployer_signer]).contract_address
        context.token_bridge_address = deploy_contract("./contracts/token_bridge.cairo", [context.deployer_address]).contract_address
        context.token_0_address = deploy_contract("./contracts/test/token/ERC20.cairo", [11, 1, 18, context.deployer_address, context.token_bridge_address]).contract_address
        context.contract_address = deploy_contract("./contracts/DefiPooling.cairo", [
            1111, #"Jedi Interest Bearing USDC",
            1010, #"jUSDC",
            context.token_0_address,
            context.token_bridge_address,
            context.deployer_address
        ]).contract_address
        ids.deployer_address = context.deployer_address
        ids.token_0_address = context.token_0_address
        ids.token_bridge_address = context.token_bridge_address
        ids.contract_address = context.contract_address
    %}

    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.contract_address) %}
    IDefiPooling.update_l1_contract(contract_address=contract_address, new_l1_contract=l1_contract)
    %{ stop_prank() %}
    
    let (_l1_contract) = IDefiPooling.l1_contract_address(contract_address=contract_address)
    assert l1_contract = _l1_contract

    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.token_bridge_address) %}
    ITokenBridge.set_l1_bridge(contract_address=token_bridge_address, l1_bridge_address=l1_bridge_contract)
    ITokenBridge.set_l2_token(contract_address=token_bridge_address, l2_token_address=token_0_address)
    %{ stop_prank() %}

    let (_l1_bridge) = ITokenBridge.get_l1_bridge(contract_address=token_bridge_address)
    assert l1_bridge_contract = _l1_bridge

    let (_l2_token) = ITokenBridge.get_l2_token(contract_address=token_bridge_address)
    assert token_0_address = _l2_token

    return ()
end


@external
func test_deposit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}():
    alloc_locals

    local contract_address
    local token_0_address
    local user_1_address
    local user_2_address

    %{
        ids.contract_address = context.contract_address
        ids.token_0_address = context.token_0_address
        ids.user_1_address = context.user_1_address
        ids.user_2_address = context.user_2_address
    %}

    let (token_0_decimals) = IERC20.decimals(contract_address=token_0_address)
    let (token_0_multiplier) = pow(10, token_0_decimals)
    
    # Mint loads of token 0 to user 1 to deposit

    let amount_to_mint_user_1 = 100 * token_0_multiplier
    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.token_0_address) %}
    IERC20.mint(contract_address=token_0_address, recipient=user_1_address, amount=Uint256(amount_to_mint_user_1, 0))
    %{ stop_prank() %}

    # Mint loads of token 0 to user 2 to deposit

    let amount_to_mint_user_2 = 100 * token_0_multiplier
    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.token_0_address) %}
    IERC20.mint(contract_address=token_0_address, recipient=user_2_address, amount=Uint256(amount_to_mint_user_2, 0))
    %{ stop_prank() %}

    # Approve tokens required to spent by Defi Pooling

    let amount_to_deposit_user_1 = 40 * token_0_multiplier

    %{ stop_prank = start_prank(context.user_1_address, target_contract_address=ids.token_0_address) %}
    IERC20.approve(contract_address=token_0_address, spender=contract_address, amount=Uint256(amount_to_deposit_user_1, 0))
    %{ stop_prank() %}

    # Deposit
    %{ stop_prank = start_prank(context.user_1_address, target_contract_address=ids.contract_address) %}
    let (total_deposit) = IDefiPooling.deposit(contract_address=contract_address, amount=Uint256(amount_to_deposit_user_1, 0))
    %{ stop_prank() %}
    
    assert total_deposit = Uint256(amount_to_deposit_user_1, 0)
    
    let (user_1_token_0_balance) = IERC20.balanceOf(contract_address=token_0_address, account=user_1_address)
    let expected_user_1_balance = amount_to_mint_user_1 - amount_to_deposit_user_1
    assert user_1_token_0_balance = Uint256(expected_user_1_balance, 0)

    # Deposit from user 2

    # Approve tokens required to spent by Defi Pooling

    let amount_to_deposit_user_2 = 60 * token_0_multiplier

    %{ stop_prank = start_prank(context.user_2_address, target_contract_address=ids.token_0_address) %}
    IERC20.approve(contract_address=token_0_address, spender=contract_address, amount=Uint256(amount_to_deposit_user_2, 0))
    %{ stop_prank() %}

    # Deposit
    %{ stop_prank = start_prank(context.user_2_address, target_contract_address=ids.contract_address) %}
    let (new_total_deposit) = IDefiPooling.deposit(contract_address=contract_address, amount=Uint256(amount_to_deposit_user_2, 0))
    %{ stop_prank() %}
    
    let (expected_total_deposit: Uint256, carry: felt) = uint256_add(total_deposit, Uint256(amount_to_deposit_user_2, 0))
    assert new_total_deposit = expected_total_deposit
    
    # Verifying total deposit from deposit id

    let (id) = IDefiPooling.current_deposit_id(contract_address=contract_address)
    let (total_deposit_amount) = IDefiPooling.total_deposit_amount(contract_address=contract_address, deposit_id=id)

    assert total_deposit_amount = new_total_deposit

    # Verifying the depositors list and amount

    let (depositors_len) = IDefiPooling.depositors_len(contract_address=contract_address, deposit_id=id)
    assert depositors_len = 2

    let (depositors_1) = IDefiPooling.depositors(contract_address=contract_address, deposit_id=id, index=0)
    assert depositors_1 = user_1_address

    let (deposit_amount_user_1) = IDefiPooling.deposit_amount(contract_address=contract_address, deposit_id=id, depositor=depositors_1)
    assert deposit_amount_user_1 = Uint256(amount_to_deposit_user_1, 0)

    let (depositors_2) = IDefiPooling.depositors(contract_address=contract_address, deposit_id=id, index=1)
    assert depositors_2 = user_2_address

    let (deposit_amount_user_2) = IDefiPooling.deposit_amount(contract_address=contract_address, deposit_id=id, depositor=depositors_2)
    assert deposit_amount_user_2 = Uint256(amount_to_deposit_user_2, 0)

    # Store balance before bridging to L1

    let (defiPooling_token_0_balance_before_deposit) = IERC20.balanceOf(contract_address=token_0_address, account=contract_address)

    # Bridging to L1

    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.contract_address) %}
    let (new_deposit_id) = IDefiPooling.deposit_assets_to_l1(contract_address=contract_address)
    %{ stop_prank() %}

    let (id) = IDefiPooling.current_deposit_id(contract_address=contract_address)
    assert id = new_deposit_id

    let (defiPooling_token_0_balance_after_deposit) = IERC20.balanceOf(contract_address=token_0_address, account=contract_address)
    let (expected_defiPooling_token_0_balance_after_deposit: Uint256) = uint256_sub(defiPooling_token_0_balance_before_deposit, new_total_deposit)
    assert defiPooling_token_0_balance_after_deposit = expected_defiPooling_token_0_balance_after_deposit

    # Note: Skip L1 message handling

    # Distributing shares received from L1 for deposit id 0

    let shares_received = 80 * 10**18
    %{ stop_prank = start_prank(context.l1_contract, target_contract_address=ids.contract_address) %}
    let (_l1_contract) = IDefiPooling.l1_contract_address(contract_address=contract_address)
    # TODO: how to call handle_distribute_share in cairo without needing to update function to @external
    IDefiPooling.handle_distribute_share(contract_address=contract_address, from_address=_l1_contract, id=0, shares=Uint256(shares_received, 0))
    %{ stop_prank() %}

    let (assets_per_share) = IDefiPooling.assets_per_share(contract_address=contract_address)
    let (total_shares) = uint256_checked_mul(new_total_deposit, Uint256(PRECISION, 0))
    let (expected_assets_per_share, _) = uint256_unsigned_div_rem(total_shares, Uint256(shares_received, 0))
    assert assets_per_share = expected_assets_per_share

    let (total_assets) = IDefiPooling.total_assets(contract_address=contract_address)
    assert total_assets = new_total_deposit

    # Verify shares balance of depositors

    # Depositor 1
    let (share_balance_depositor_1) = IERC20.balanceOf(contract_address=contract_address, account=depositors_1)
    let (total_deposit_depositor_1) = uint256_checked_mul(Uint256(shares_received, 0), deposit_amount_user_1)
    let (expected_share_balance_depositor_1, _) = uint256_unsigned_div_rem(total_deposit_depositor_1, total_deposit_amount)
    assert share_balance_depositor_1 = expected_share_balance_depositor_1

    let (assets_of_user_1) = IDefiPooling.assetsOf(contract_address=contract_address, account=depositors_1)
    assert assets_of_user_1 = Uint256(amount_to_deposit_user_1, 0)

    # Depositor 2
    let (share_balance_depositor_2) = IERC20.balanceOf(contract_address=contract_address, account=depositors_2)
    let (total_deposit_depositor_2) = uint256_checked_mul(Uint256(shares_received, 0), deposit_amount_user_2)
    let (expected_share_balance_depositor_2, _) = uint256_unsigned_div_rem(total_deposit_depositor_2, total_deposit_amount)
    assert share_balance_depositor_2 = expected_share_balance_depositor_2

    let (assets_of_user_2) = IDefiPooling.assetsOf(contract_address=contract_address, account=depositors_2)
    assert assets_of_user_2 = Uint256(amount_to_deposit_user_2, 0)

    return ()
end


@external
func test_cancel_deposit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}():

    alloc_locals

    local deployer_address
    local user_1_address
    local user_2_address
    local token_0_address
    local contract_address

    %{
        ids.deployer_address = context.deployer_address
        ids.user_1_address = context.user_1_address
        ids.user_2_address = context.user_2_address
        ids.token_0_address = context.token_0_address
        ids.contract_address = context.contract_address
    %}

    # Mint loads of tokens_0 to user_1 to deposit

    let (token_0_decimals) = IERC20.decimals(contract_address=token_0_address)
    let (token_0_multiplier) = pow(10, token_0_decimals)

    let amount_to_mint_user_1 = 100 * token_0_multiplier
    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.token_0_address) %}
    IERC20.mint(contract_address=token_0_address, recipient=user_1_address, amount=Uint256(amount_to_mint_user_1, 0))
    %{ stop_prank() %}

    # Approve tokens required to spent by Defi Pooling

    let amount_to_deposit_user_1 = 40 * token_0_multiplier

    %{ stop_prank = start_prank(context.user_1_address, target_contract_address=ids.token_0_address) %}
    IERC20.approve(contract_address=token_0_address, spender=contract_address, amount=Uint256(amount_to_deposit_user_1, 0))
    %{ stop_prank() %}

    # Deposit
    %{ stop_prank = start_prank(context.user_1_address, target_contract_address=ids.contract_address) %}
    let (total_deposit) = IDefiPooling.deposit(contract_address=contract_address, amount=Uint256(amount_to_deposit_user_1, 0))
    %{ stop_prank() %}
    
    assert total_deposit = Uint256(amount_to_deposit_user_1, 0)
    
    let (user_1_token_0_balance) = IERC20.balanceOf(contract_address=token_0_address, account=user_1_address)
    let expected_user_1_balance = amount_to_mint_user_1 - amount_to_deposit_user_1
    assert user_1_token_0_balance = Uint256(expected_user_1_balance, 0)

    let (id) = IDefiPooling.current_deposit_id(contract_address=contract_address)
    let (deposit_amount_user_1) = IDefiPooling.deposit_amount(contract_address=contract_address, deposit_id=id, depositor=user_1_address)
    assert deposit_amount_user_1 = Uint256(amount_to_deposit_user_1, 0)

    # Read balance before cancelling deposit

    let (user_balance_before_cancel_deposit) = IERC20.balanceOf(contract_address=token_0_address, account=user_1_address)


    # Cancelling deposit

    %{ stop_prank = start_prank(context.user_1_address, target_contract_address=ids.contract_address) %}
    let (new_total_deposit) = IDefiPooling.cancel_deposit(contract_address=contract_address)
    %{ stop_prank() %}

    # Verify balances

    let (expected_total_deposit: Uint256) = uint256_sub(total_deposit, Uint256(amount_to_deposit_user_1, 0))
    assert new_total_deposit = expected_total_deposit
    
    let (new_user_balance) = IERC20.balanceOf(contract_address=token_0_address, account=user_1_address)
    let (expected_new_user_balance: Uint256, carry: felt) = uint256_add(user_balance_before_cancel_deposit, Uint256(amount_to_deposit_user_1, 0))
    assert new_user_balance = expected_new_user_balance

    # Verifying the depositors amount

    let (deposit_amount_user_1) = IDefiPooling.deposit_amount(contract_address=contract_address, deposit_id=id, depositor=user_1_address)
    assert deposit_amount_user_1 = Uint256(0, 0)

    return ()
end