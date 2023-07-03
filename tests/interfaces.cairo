%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IERC20{
    
    func name() -> (name: felt){
    }

    func symbol() -> (symbol: felt){
    }

    func totalSupply() -> (totalSupply: Uint256){
    }

    func decimals() -> (decimals: felt){
    }

    func mint(recipient : felt, amount : Uint256){
    }

    func approve(spender: felt, amount: Uint256) -> (success: felt){
    }

    func balanceOf(account: felt) -> (balance: Uint256){
    }

}

@contract_interface
namespace IDefiPooling{

    func owner() -> (owner: felt){
    }

    func current_deposit_id() -> (id: felt){
    }

    func total_deposit_amount(deposit_id: felt) -> (total_deposit_amount: Uint256){
    }

    func deposit(amount: Uint256) -> (total_deposit: Uint256){
    }

    func withdraw(amount: Uint256) -> (total_withdraw: Uint256){
    }

    func mint(shares: Uint256) -> (total_deposit: Uint256){
    }

    func redeem(shares: Uint256) -> (total_withdraw: Uint256){
    }

    func cancel_deposit() -> (total_deposit: Uint256){
    }

    func cancel_withdraw() -> (total_deposit: Uint256){
    }

    func depositors_len(deposit_id: felt) -> (depositors_len: felt){
    }

    func depositors(deposit_id: felt, index:felt) -> (depositors: felt){
    }

    func deposit_amount(deposit_id: felt, depositor:felt) -> (deposit_amount: Uint256){
    }

    func current_withdraw_id() -> (id: felt){
    }

    func total_withdraw_amount(withdraw_id: felt) -> (total_withdraw_amount: Uint256){
    }

    func withdraws_len(withdraw_id: felt) -> (withdraws_len: felt){
    }

    func withdraws(withdraw_id: felt, index:felt) -> (withdrawer: felt){
    }

    func withdraw_amount(withdraw_id: felt, withdrawer:felt) -> (withdraw_amount: Uint256){
    }

    func asset() -> (asset: felt){
    }

    func l1_contract_address() -> (l1_contract_address: felt){
    }

    func token_bridge() -> (token_bridge: felt){
    }

    func assets_per_share() -> (assets_per_share: Uint256){
    }

    func total_assets() -> (total_assets: Uint256){
    }

    func assetsOf(account: felt) -> (assets_of: Uint256){
    }

    func preview_deposit(assets: Uint256) -> (shares: Uint256){
    }

    func preview_mint(shares: Uint256) -> (assets: Uint256){
    }

    func preview_withdraw(assets: Uint256) -> (shares: Uint256){
    }

    func preview_redeem(shares: Uint256) -> (assets: Uint256){
    }
    
    func update_l1_contract(new_l1_contract : felt){
    }

    func deposit_assets_to_l1() -> (deposit_id: felt){
    }

    func send_withdrawal_request_to_l1() -> (withdraw_id: felt){
    }

    func handle_distribute_share(from_address : felt, id : felt, shares : Uint256){
    }

    func handle_distribute_asset(from_address : felt, id : felt, assets : Uint256){
    }
}

@contract_interface
namespace ITokenBridge{
    func get_governor() -> (res : felt){
    }

    func get_l1_bridge() -> (res : felt){
    }

    func get_l2_token() -> (res : felt){
    }

    func set_l1_bridge(l1_bridge_address : felt){
    }

    func set_l2_token(l2_token_address : felt){
    }

    func initiate_withdraw(l1_recipient : felt, amount : Uint256){
    }
}