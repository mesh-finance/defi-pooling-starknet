%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.starknet.common.syscalls import get_caller_address, deploy, get_contract_address
from starkware.cairo.common.uint256 import Uint256, uint256_add, uint256_sub, uint256_unsigned_div_rem
from starkware.cairo.common.pow import pow
from starkware.cairo.common.alloc import alloc
from contracts.utils.math import uint256_checked_mul
from tests.interfaces import IDefiPooling, ITokenBridge, IERC20

const PRECISION = 1000000000;

@external
func __setup__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(){
    alloc_locals;

    local deployer_signer = 1;
    local user_1_signer = 2;
    local user_2_signer = 3;
    local deployer_address;
    local token_0_address;
    local token_bridge_address;
    local l1_contract = 907507751940624169017; // str_to_felt('123456789')
    local l1_bridge_contract = 1055515178193424429617; // str_to_felt('987654321')
    local contract_address;

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
    IDefiPooling.update_l1_contract(contract_address=contract_address, new_l1_contract=l1_contract);
    %{ stop_prank() %}
    
    let (_l1_contract) = IDefiPooling.l1_contract_address(contract_address=contract_address);
    assert l1_contract = _l1_contract;

    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.token_bridge_address) %}
    ITokenBridge.set_l1_bridge(contract_address=token_bridge_address, l1_bridge_address=l1_bridge_contract);
    ITokenBridge.set_l2_token(contract_address=token_bridge_address, l2_token_address=token_0_address);
    %{ stop_prank() %}

    let (_l1_bridge) = ITokenBridge.get_l1_bridge(contract_address=token_bridge_address);
    assert l1_bridge_contract = _l1_bridge;

    let (_l2_token) = ITokenBridge.get_l2_token(contract_address=token_bridge_address);
    assert token_0_address = _l2_token;

    return ();
}


@external
func test_redeem{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(){
    alloc_locals;

    local contract_address;
    local token_0_address;
    local user_1_address;
    local user_2_address;

    %{
        ids.contract_address = context.contract_address
        ids.token_0_address = context.token_0_address
        ids.user_1_address = context.user_1_address
        ids.user_2_address = context.user_2_address
    %}

    let (token_0_decimals) = IERC20.decimals(contract_address=token_0_address);
    let (token_0_multiplier) = pow(10, token_0_decimals);
    
    // Mint loads of token 0 to user 1 to deposit
    let amount_to_mint_user_1 = 60 * token_0_multiplier;
    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.token_0_address) %}
    IERC20.mint(contract_address=token_0_address, recipient=user_1_address, amount=Uint256(amount_to_mint_user_1, 0));
    %{ stop_prank() %}

    // Mint loads of token 0 to user 2 to deposit
    let amount_to_mint_user_2 = 60 * token_0_multiplier;
    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.token_0_address) %}
    IERC20.mint(contract_address=token_0_address, recipient=user_2_address, amount=Uint256(amount_to_mint_user_2, 0));
    %{ stop_prank() %}

    // Depositing from user 1
    let amount_to_deposit_user_1 = 40 * token_0_multiplier;
    %{ stop_prank = start_prank(context.user_1_address, target_contract_address=ids.token_0_address) %}
    IERC20.approve(contract_address=token_0_address, spender=contract_address, amount=Uint256(amount_to_deposit_user_1, 0));
    %{ stop_prank() %}
    %{ stop_prank = start_prank(context.user_1_address, target_contract_address=ids.contract_address) %}
    let (total_deposit) = IDefiPooling.deposit(contract_address=contract_address, amount=Uint256(amount_to_deposit_user_1, 0));
    %{ stop_prank() %}

    // Depositing from user 2
    let amount_to_deposit_user_2 = 60 * token_0_multiplier;
    %{ stop_prank = start_prank(context.user_2_address, target_contract_address=ids.token_0_address) %}
    IERC20.approve(contract_address=token_0_address, spender=contract_address, amount=Uint256(amount_to_deposit_user_2, 0));
    %{ stop_prank() %}
    %{ stop_prank = start_prank(context.user_2_address, target_contract_address=ids.contract_address) %}
    let (new_total_deposit) = IDefiPooling.deposit(contract_address=contract_address, amount=Uint256(amount_to_deposit_user_2, 0));
    %{ stop_prank() %}

    // Bridging to L1
    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.contract_address) %}
    let (new_deposit_id) = IDefiPooling.deposit_assets_to_l1(contract_address=contract_address);
    %{ stop_prank() %}

    // Note: Skip L1 message handling

    // Distributing shares received from L1 for deposit id 0
    let shares_received = 80 * 10**18;
    %{
        # ID: 0, uint256(shares_received, 0)
        send_message_to_l2(fn_name="handle_distribute_share", from_address=context.l1_contract, to_address=context.contract_address, payload=[0, ids.shares_received, 0])
    %}

    let (assets_per_share_after_deposit) = IDefiPooling.assets_per_share(contract_address=contract_address);
    let (total_shares) = uint256_checked_mul(new_total_deposit, Uint256(PRECISION, 0));
    let (expected_assets_per_share_after_deposit, _) = uint256_unsigned_div_rem(total_shares, Uint256(shares_received, 0));
    assert assets_per_share_after_deposit = expected_assets_per_share_after_deposit;

    let (share_balance_user_1) = IERC20.balanceOf(contract_address=contract_address, account=user_1_address);
    let (share_balance_user_2) = IERC20.balanceOf(contract_address=contract_address, account=user_2_address);

    // ######################################################################
    // ########### Testing redeem: Assets are deposited ####################
    // ######################################################################

    let shares_to_withdraw_user_1 = share_balance_user_1;
    let (shares_to_withdraw_user_2, _) = uint256_unsigned_div_rem(share_balance_user_2, Uint256(2, 0));

    // Redeeming from user 1
    %{ stop_prank = start_prank(context.user_1_address, target_contract_address=ids.contract_address) %}
    let (total_withdraw) = IDefiPooling.redeem(contract_address=contract_address, shares=shares_to_withdraw_user_1);
    %{ stop_prank() %}
    assert total_withdraw = shares_to_withdraw_user_1;

    let (user_1_shares_balance) = IERC20.balanceOf(contract_address=contract_address, account=user_1_address);
    let (expected_user_1_shares_balance) = uint256_sub(share_balance_user_1, shares_to_withdraw_user_1);
    assert user_1_shares_balance = expected_user_1_shares_balance;

    // Redeeming from user 2
    %{ stop_prank = start_prank(context.user_2_address, target_contract_address=ids.contract_address) %}
    let (new_total_withdraw) = IDefiPooling.redeem(contract_address=contract_address, shares=shares_to_withdraw_user_2);
    %{ stop_prank() %}
    let (expected_new_total_withdraw, _) = uint256_add(total_withdraw, shares_to_withdraw_user_2);
    assert new_total_withdraw = expected_new_total_withdraw;

    let (user_2_shares_balance) = IERC20.balanceOf(contract_address=contract_address, account=user_2_address);
    let (expected_user_2_shares_balance) = uint256_sub(share_balance_user_2, shares_to_withdraw_user_2);
    assert user_2_shares_balance = expected_user_2_shares_balance;

    // Verifying total withdraw from withdraw id
    let (id) = IDefiPooling.current_withdraw_id(contract_address=contract_address);
    let (total_withdraw_amount) = IDefiPooling.total_withdraw_amount(contract_address=contract_address, withdraw_id=id);
    assert total_withdraw_amount = new_total_withdraw;

    // Verifying the withdrawers list and amount
    let (withdraws_len) = IDefiPooling.withdraws_len(contract_address=contract_address, withdraw_id=id);
    assert withdraws_len = 2; // Manual check;

    let (withdrawer_1) = IDefiPooling.withdraws(contract_address=contract_address, withdraw_id=id, index=0); // Index of 0
    assert withdrawer_1 = user_1_address;

    let (withdraw_amount_user_1) = IDefiPooling.withdraw_amount(contract_address=contract_address, withdraw_id=id, withdrawer=withdrawer_1);
    assert withdraw_amount_user_1 = shares_to_withdraw_user_1;

    let (withdrawer_2) = IDefiPooling.withdraws(contract_address=contract_address, withdraw_id=id, index=1); // Index of 1
    assert withdrawer_2 = user_2_address;

    let (withdraw_amount_user_2) = IDefiPooling.withdraw_amount(contract_address=contract_address, withdraw_id=id, withdrawer=withdrawer_2);
    assert withdraw_amount_user_2 = shares_to_withdraw_user_2;

    // Sending withdrawal Request to L1
    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.contract_address) %}
    let (new_withdraw_id) = IDefiPooling.send_withdrawal_request_to_l1(contract_address=contract_address);
    %{ stop_prank() %}
    let (id) = IDefiPooling.current_withdraw_id(contract_address=contract_address);
    assert id = new_withdraw_id;
    assert id = 1; // Manual check;

    // Note: Skip L1 message handling
    let underlying_received = 120 * 10**18;

    let (token_0_balance_withdrawer_1_before) = IERC20.balanceOf(contract_address=token_0_address, account=user_1_address);
    let (token_0_balance_withdrawer_2_before) = IERC20.balanceOf(contract_address=token_0_address, account=user_2_address);

    // Distributing underlying token received from L1 for withdraw id 0
    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.token_0_address) %}
    // Minting underlying token to DefiPooling contract to distribute
    IERC20.mint(contract_address=token_0_address, recipient=contract_address, amount=Uint256(underlying_received, 0));
    %{ stop_prank() %}

    %{
        # ID: 0, uint256(underlying_received, 0)
        send_message_to_l2(fn_name="handle_distribute_asset", from_address=context.l1_contract, to_address=context.contract_address, payload=[0, ids.underlying_received, 0])
    %}

    // Verify assets per share after withdraw
    let (assets_per_share_after_withdraw) = IDefiPooling.assets_per_share(contract_address=contract_address);
    let (underlying_received_PRECISION) = uint256_checked_mul(Uint256(underlying_received, 0), Uint256(PRECISION, 0));
    let (expected_assets_per_share_after_withdraw, _) = uint256_unsigned_div_rem(underlying_received_PRECISION, new_total_withdraw);
    assert assets_per_share_after_withdraw = expected_assets_per_share_after_withdraw;

    // Verify total assets after withdraw
    let (total_assets) = IDefiPooling.total_assets(contract_address=contract_address);
    let (shares_remaining) = uint256_sub(Uint256(shares_received, 0), new_total_withdraw);
    let (expected_total_assets_PRECISION) = uint256_checked_mul(shares_remaining, assets_per_share_after_withdraw);
    let (expected_total_assets, _) = uint256_unsigned_div_rem(expected_total_assets_PRECISION, Uint256(PRECISION, 0));
    assert total_assets = expected_total_assets;

    // Checking underlying balance of withdrawers
    let (token_0_balance_withdrawer_1) = IERC20.balanceOf(contract_address=token_0_address, account=user_1_address);
    let (assets_to_withdraw_user_1_temp) = uint256_checked_mul(Uint256(underlying_received, 0), shares_to_withdraw_user_1);
    let (assets_to_withdraw_user_1, _) = uint256_unsigned_div_rem(assets_to_withdraw_user_1_temp, total_withdraw_amount);
    let (expected_token_0_balance_withdrawer_1, _) = uint256_add(token_0_balance_withdrawer_1_before, assets_to_withdraw_user_1);
    assert token_0_balance_withdrawer_1 = expected_token_0_balance_withdrawer_1;

    let (token_0_balance_withdrawer_2) = IERC20.balanceOf(contract_address=token_0_address, account=user_2_address);
    let (assets_to_withdraw_user_2_temp) = uint256_checked_mul(Uint256(underlying_received, 0), shares_to_withdraw_user_2);
    let (assets_to_withdraw_user_2, _) = uint256_unsigned_div_rem(assets_to_withdraw_user_2_temp, total_withdraw_amount);
    let (expected_token_0_balance_withdrawer_2, _) = uint256_add(token_0_balance_withdrawer_2_before, assets_to_withdraw_user_2);
    assert token_0_balance_withdrawer_2 = expected_token_0_balance_withdrawer_2;

    // Checking that the new withdraw are now stored corresponding to updated withdraw id
    let (shares_to_withdraw_user_2_id_1) = uint256_sub(share_balance_user_2, shares_to_withdraw_user_2);
    
    // Redeeming from user_2 for id_1
    %{ stop_prank = start_prank(context.user_2_address, target_contract_address=ids.contract_address) %}
    let (total_withdraw_id_1) = IDefiPooling.redeem(contract_address=contract_address, shares=shares_to_withdraw_user_2_id_1);
    %{ stop_prank() %}
    assert total_withdraw_id_1 = shares_to_withdraw_user_2_id_1;

    // Verifying total withdraw from withdraw id for id=1
    let (id) = IDefiPooling.current_withdraw_id(contract_address=contract_address);
    let (total_withdraw_amount) = IDefiPooling.total_withdraw_amount(contract_address=contract_address, withdraw_id=id);
    assert total_withdraw_amount = total_withdraw_id_1;

    return ();
}

func test_cancel_withdraw{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(){
    alloc_locals;

    local contract_address;
    local token_0_address;
    local user_1_address;
    local user_2_address;

    %{
        ids.contract_address = context.contract_address
        ids.token_0_address = context.token_0_address
        ids.user_1_address = context.user_1_address
        ids.user_2_address = context.user_2_address
    %}

    let (token_0_decimals) = IERC20.decimals(contract_address=token_0_address);
    let (token_0_multiplier) = pow(10, token_0_decimals);
    
    // Mint loads of token 0 to user 1 to deposit
    let amount_to_mint_user_1 = 60 * token_0_multiplier;
    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.token_0_address) %}
    IERC20.mint(contract_address=token_0_address, recipient=user_1_address, amount=Uint256(amount_to_mint_user_1, 0));
    %{ stop_prank() %}

    // Depositing from user 1
    let amount_to_deposit_user_1 = 40 * token_0_multiplier;
    %{ stop_prank = start_prank(context.user_1_address, target_contract_address=ids.token_0_address) %}
    IERC20.approve(contract_address=token_0_address, spender=contract_address, amount=Uint256(amount_to_deposit_user_1, 0));
    %{ stop_prank() %}
    %{ stop_prank = start_prank(context.user_1_address, target_contract_address=ids.contract_address) %}
    let (total_deposit) = IDefiPooling.deposit(contract_address=contract_address, amount=Uint256(amount_to_deposit_user_1, 0));
    %{ stop_prank() %}

    // Bridging to L1
    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.contract_address) %}
    let (new_deposit_id) = IDefiPooling.deposit_assets_to_l1(contract_address=contract_address);
    %{ stop_prank() %}

    // Note: Skip L1 message handling

    // Distributing shares received from L1 for deposit id 0
    let shares_received = 80 * 10**18;
    %{
        # ID: 0, uint256(shares_received, 0)
        send_message_to_l2(fn_name="handle_distribute_share", from_address=context.l1_contract, to_address=context.contract_address, payload=[0, ids.shares_received, 0])
    %}

    let (share_balance_user_1) = IERC20.balanceOf(contract_address=contract_address, account=user_1_address);
    let shares_to_withdraw_user_1 = share_balance_user_1;

    // Redeeming from user 1
    %{ stop_prank = start_prank(context.user_1_address, target_contract_address=ids.contract_address) %}
    let (total_withdraw) = IDefiPooling.redeem(contract_address=contract_address, shares=shares_to_withdraw_user_1);
    %{ stop_prank() %}
    assert total_withdraw = shares_to_withdraw_user_1;

    let (id) = IDefiPooling.current_withdraw_id(contract_address=contract_address);

    // Verifying balances pre cancel
    let (user_1_shares_balance) = IERC20.balanceOf(contract_address=contract_address, account=user_1_address);
    let (expected_user_1_shares_balance) = uint256_sub(share_balance_user_1, shares_to_withdraw_user_1);
    assert user_1_shares_balance = expected_user_1_shares_balance;

    // Cancelling withdraw for user_1
    %{ stop_prank = start_prank(context.user_1_address, target_contract_address=ids.contract_address) %}
    let (new_total_withdraw) = IDefiPooling.cancel_withdraw(contract_address=contract_address);
    %{ stop_prank() %}

    // Verify balances post cancel
    let (expected_new_total_withdraw: Uint256) = uint256_sub(total_withdraw, shares_to_withdraw_user_1);
    assert new_total_withdraw = expected_new_total_withdraw;

    let (user_1_shares_new_balance) = IERC20.balanceOf(contract_address=contract_address, account=user_1_address);
    let (expected_user_1_shares_new_balance: Uint256, _) = uint256_add(user_1_shares_balance, shares_to_withdraw_user_1);
    assert user_1_shares_new_balance = expected_user_1_shares_new_balance;

    // Verifying the withdraw amount
    let (withdraw_amount_user_1_after_cancel) = IDefiPooling.withdraw_amount(contract_address=contract_address, withdraw_id=id, withdrawer=user_1_address);
    assert withdraw_amount_user_1_after_cancel = Uint256(0, 0); // Manual check;

    return ();
}
