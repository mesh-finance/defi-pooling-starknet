%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IERC20:
    
    func name() -> (name: felt):
    end

    func symbol() -> (symbol: felt):
    end

    func totalSupply() -> (totalSupply: Uint256):
    end

    func decimals() -> (decimals: felt):
    end

    func mint(recipient : felt, amount : Uint256):
    end

    func approve(spender: felt, amount: Uint256) -> (success: felt):
    end

    func balanceOf(account: felt) -> (balance: Uint256):
    end

end

@contract_interface
namespace IDefiPooling:

    func owner() -> (owner: felt):
    end

    func current_deposit_id() -> (id: felt):
    end

    func total_deposit_amount(deposit_id: felt) -> (total_deposit_amount: Uint256):
    end

    func deposit(amount: Uint256) -> (total_deposit: Uint256):
    end

    func withdraw(amount: Uint256) -> (total_withdraw: Uint256):
    end

    func mint(shares: Uint256) -> (total_deposit: Uint256):
    end

    func redeem(shares: Uint256) -> (total_withdraw: Uint256):
    end

    func cancel_deposit() -> (total_deposit: Uint256):    
    end

    func cancel_withdraw() -> (total_deposit: Uint256):    
    end

    func depositors_len(deposit_id: felt) -> (depositors_len: felt):
    end

    func depositors(deposit_id: felt, index:felt) -> (depositors: felt):
    end

    func deposit_amount(deposit_id: felt, depositor:felt) -> (deposit_amount: Uint256):
    end

    func current_withdraw_id() -> (id: felt):
    end

    func total_withdraw_amount(withdraw_id: felt) -> (total_withdraw_amount: Uint256):
    end

    func withdraws_len(withdraw_id: felt) -> (withdraws_len: felt):
    end

    func withdraws(withdraw_id: felt, index:felt) -> (withdrawer: felt):
    end

    func withdraw_amount(withdraw_id: felt, withdrawer:felt) -> (withdraw_amount: Uint256):
    end

    func asset() -> (asset: felt):
    end

    func l1_contract_address() -> (l1_contract_address: felt):
    end

    func token_bridge() -> (token_bridge: felt):
    end

    func assets_per_share() -> (assets_per_share: Uint256):
    end

    func total_assets() -> (total_assets: Uint256):
    end

    func assetsOf(account: felt) -> (assets_of: Uint256):
    end

    func preview_deposit(assets: Uint256) -> (shares: Uint256):
    end

    func preview_mint(shares: Uint256) -> (assets: Uint256):
    end

    func preview_withdraw(assets: Uint256) -> (shares: Uint256):
    end

    func preview_redeem(shares: Uint256) -> (assets: Uint256):
    end
    
    func update_l1_contract(new_l1_contract : felt):
    end

    func deposit_assets_to_l1() -> (deposit_id: felt):
    end

    func send_withdrawal_request_to_l1() -> (withdraw_id: felt):
    end

    func handle_distribute_share(from_address : felt, id : felt, shares : Uint256):
    end

    func handle_distribute_asset(from_address : felt, id : felt, assets : Uint256):
    end
end

@contract_interface
namespace ITokenBridge:
    func get_governor() -> (res : felt):
    end

    func get_l1_bridge() -> (res : felt):
    end

    func get_l2_token() -> (res : felt):
    end

    func set_l1_bridge(l1_bridge_address : felt):
    end

    func set_l2_token(l2_token_address : felt):
    end

    func initiate_withdraw(l1_recipient : felt, amount : Uint256):
    end
end