%lang starknet

// @title DefiPooling for depositing in L1 protocol directky from L2
// @author Mesh Finance
// @license MIT
// @dev an ERC20 token

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_block_timestamp, get_contract_address
from starkware.cairo.common.math import assert_le, assert_not_zero, assert_not_equal
from starkware.cairo.common.math_cmp import is_le, is_le_felt
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import (Uint256, uint256_le, uint256_lt, uint256_check, uint256_eq, uint256_sqrt, uint256_unsigned_div_rem)
from contracts.utils.math import uint256_checked_add, uint256_checked_sub_lt, uint256_checked_mul, uint256_felt_checked_mul,uint256_checked_sub_le
from starkware.starknet.common.messages import send_message_to_l1


const MESSAGE_WITHDRAWAL_REQUEST = 1;
const MESSAGE_DEPOSIT_REQUEST = 2;
const PRECISION = 1000000000;

//
// Interfaces
//
@contract_interface
namespace IERC20{
    
    func balanceOf(account: felt) -> (balance: Uint256){
    }

    func transfer(recipient: felt, amount: Uint256) -> (success: felt){
    }

    func transferFrom(
            sender: felt, 
            recipient: felt, 
            amount: Uint256
        ) -> (success: felt){
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

//
// Storage ERC20
//

// @dev Name of the token
@storage_var
func _name() -> (res: felt){
}

// @dev Symbol of the token
@storage_var
func _symbol() -> (res: felt){
}

// @dev Decimals of the token
@storage_var
func _decimals() -> (res: felt){
}

// @dev Total Supply of the token
@storage_var
func total_supply() -> (res: Uint256){
}

// @dev Balances of the token for each account
@storage_var
func balances(account: felt) -> (res: Uint256){
}

// @dev Allowances of the token for owner-spender pair 
@storage_var
func allowances(owner: felt, spender: felt) -> (res: Uint256){
}


//
// Storage Ownable
//

// @dev Address of the owner of the contract
@storage_var
func _owner() -> (address: felt){
}

// @dev Address of the future owner of the contract
@storage_var
func _future_owner() -> (address: felt){
}

// An event emitted whenever initiate_ownership_transfer() is called.
@event
func owner_change_initiated(current_owner: felt, future_owner: felt){
}

// An event emitted whenever accept_ownership() is called.
@event
func owner_change_completed(current_owner: felt, future_owner: felt){
}


//
// Storage DefiPooling
//

// @dev asset
@storage_var
func _asset() -> (res: felt){
}

// @dev asset token bridge
@storage_var
func _token_bridge() -> (res: felt){
}

// @dev L1 contract address
@storage_var
func _l1_contract_address() -> (res: felt){
}


// @dev total deposit for each deposit to L1
@storage_var
func _total_deposit(deposit_id: felt) -> (res: Uint256){
}

// @dev deposit id
@storage_var
func _deposit_id() -> (id: felt){
}

// @dev array to store all the depositor address
@storage_var
func _depositors(deposit_id: felt, index: felt) -> ( depositors: felt){
}

// @dev array to store all the depositor address
@storage_var
func _depositors_len(deposit_id: felt) -> (res: felt){
}

// @dev array to store depositor info
@storage_var
func _deposit_amount(deposit_id: felt, depositor: felt) -> (amount: Uint256){
}

// @dev mapping to store distributed shares info
@storage_var
func _shares_distributed(deposit_id: felt) -> (res: Uint256){
}

// @dev total withdraw for each withdraw call to L1
@storage_var
func _total_withdraw(withdraw_id: felt) -> (res: Uint256){
}

// @dev withdraw id
@storage_var
func _withdraw_id() -> (id: felt){
}

// @dev array to store all the withdraw address
@storage_var
func _withdraws(withdraw_id: felt,index:felt) -> (withdraws: felt){
}

// @dev array to store all the withdraw address
@storage_var
func _withdraws_len(withdraw_id: felt) -> (withdraws_len: felt){
}

// @dev array to store withdraw info
@storage_var
func _withdraw_amount(withdraw_id: felt, withdrawer: felt) -> (amount: Uint256){
}

// @dev mapping to store distributed assets info
@storage_var
func _assets_distributed(withdraw_id: felt) -> (res: Uint256){
}

// @dev assets per share
@storage_var
func _assets_per_share() -> (res: Uint256){
}


// @notice An event emitted whenever token is transferred.
@event
func Transfer(from_address: felt, to_address: felt, amount: Uint256){
}

// @notice An event emitted whenever allowances is updated
@event
func Approval(owner: felt, spender: felt, amount: Uint256){
}

// @notice An event emitted whenever mint() is called.
@event
func Mint(to: felt, amount: Uint256){
}

// @notice An event emitted whenever burn() is called.
@event
func Burn(account: felt, amount: Uint256){
}


// ********** method 2****************
// @dev array to store depositor info
// @storage_var
// func depositors(deposit_id: Uint256) -> (depositors_len: felt, depositors: Depositor*){
// end

// // @dev struct to store depositor info
// struct Depositor:
//     member userAddress : felt
//     member amount : Uint256
// end
// ***********************************************

//
// Constructor
//

// @notice Contract constructor
// @param name Name of the pair token
// @param symbol Symbol of the pair token
@constructor
func constructor{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        name: felt,
        symbol: felt,
        // l1_contract_address: felt,
        asset: felt,
        token_bridge: felt,
        owner: felt,
    ){
    with_attr error_message("DefiPooling::constructor::all arguments must be non zero"){
        assert_not_zero(name);
        assert_not_zero(symbol);
        // assert_not_zero(l1_contract_address)
        assert_not_zero(asset);
        assert_not_zero(token_bridge);
        assert_not_zero(owner);
    }
    _name.write(name);
    _symbol.write(symbol);
    _decimals.write(18);
    // _percesion.write(9)
    // _l1_contract_address.write(l1_contract_address)
    _asset.write(asset);
    _token_bridge.write(token_bridge);
    _owner.write(owner);
   _deposit_id.write(0);

    _depositors_len.write(0,0);
    _assets_per_share.write(Uint256(0,0));
    //_withdraws_len.write(Uint256(0,0),0)

// ********** method 2****************    
    // initialising the depositor array for deposit id 0
    // let (depositor_array : Depositor*) = alloc()
    // depositors.write(Uint256(0,0),0,depositor_array)
// *********************************************
    return ();
}



//
// Getters ERC20
//

// @notice Name of the token
// @return name
@view
func name{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (name: felt){
    let (name) = _name.read();
    return (name=name);
}

// @notice Symbol of the token
// @return symbol
@view
func symbol{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (symbol: felt){
    let (symbol) = _symbol.read();
    return (symbol=symbol);
}

// @notice Total Supply of the token
// @return totalSupply
@view
func totalSupply{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (totalSupply: Uint256){
    let (totalSupply: Uint256) = total_supply.read();
    return (totalSupply=totalSupply);
}

// @notice Decimals of the token
// @return decimals
@view
func decimals{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (decimals: felt){
    let (decimals) = _decimals.read();
    return (decimals=decimals);
}

// @notice Balance of `account`
// @param account Account address whose balance is fetched
// @return balance Balance of `account`
@view
func balanceOf{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(account: felt) -> (balance: Uint256){
    let (balance: Uint256) = balances.read(account=account);
    return (balance=balance);
}

// @notice Allowance which `spender` can spend on behalf of `owner`
// @param owner Account address whose tokens are spent
// @param spender Account address which can spend the tokens
// @return remaining
@view
func allowance{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(owner: felt, spender: felt) -> (remaining: Uint256){
    let (remaining: Uint256) = allowances.read(owner=owner, spender=spender);
    return (remaining=remaining);
}


//
// Getters Defi Pooling
//

// @notice Get contract owner address
// @return owner
@view
func owner{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (owner: felt){
    let (owner) = _owner.read();
    return (owner=owner);
}

// @notice Get current deposit id
// @return id
@view
func current_deposit_id{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (id: felt){
    let (id:felt) =_deposit_id.read();
    return (id=id);
}

// @notice Get total deposit amount for a deposit id
// @param deposit_id id of which we want total deposit amount
// @return total_deposit_amount
@view
func total_deposit_amount{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(deposit_id: felt) -> (total_deposit_amount: Uint256){
    let (total_deposit_amount: Uint256) = _total_deposit.read(deposit_id);
    return (total_deposit_amount=total_deposit_amount);
}

// @notice Get total no. of depositors for a deposit id
// @param deposit_id id of which we want total depositors count
// @return depositors_len
@view
func depositors_len{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(deposit_id: felt) -> (depositors_len: felt){
    let (depositors_len: felt) = _depositors_len.read(deposit_id);
    return (depositors_len=depositors_len);
}

// @notice Get depositor address 
// @param deposit_id id of which we want depositor
// @param index index at which we want the depositor
// @return depositors
@view
func depositors{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(deposit_id: felt, index:felt) -> (depositors: felt){
    let (depositors: felt) = _depositors.read(deposit_id,index);
    return (depositors=depositors);
}

// @notice Get deposit amount of a depositor 
// @param deposit_id id of which we want deposit amount
// @param index depositor index of which we want amount
// @return deposit_amount
@view
func deposit_amount{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(deposit_id: felt, depositor:felt) -> (deposit_amount: Uint256){
    let (deposit_amount: Uint256) = _deposit_amount.read(deposit_id,depositor);
    return (deposit_amount=deposit_amount);
}

// @notice Get current withdraw id
// @return id
@view
func current_withdraw_id{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (id: felt){
    let (id:felt) =_withdraw_id.read();
    return (id=id);
}

// @notice Get total withdraw amount for a withdraw id
// @param withdraw_id id of which we want total withdraw amount
// @return total_withdraw_amount
@view
func total_withdraw_amount{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(withdraw_id: felt) -> (total_withdraw_amount: Uint256){
    let (total_withdraw_amount: Uint256) = _total_withdraw.read(withdraw_id);
    return (total_withdraw_amount=total_withdraw_amount);
}

// @notice Get total no. of withdrawers for a withdraw id
// @param withdraw_id id of which we want total withdrawers count
// @return withdraws_len
@view
func withdraws_len{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(withdraw_id: felt) -> (withdraws_len: felt){
    let (withdraws_len: felt) = _withdraws_len.read(withdraw_id);
    return (withdraws_len=withdraws_len);
}

// @notice Get withdrawer address 
// @param withdraw_id id of which we want withdrawer
// @param index index at which we want the withdrawer
// @return withdrawer
@view
func withdraws{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(withdraw_id: felt, index:felt) -> (withdrawer: felt){
    let (withdrawer: felt) = _withdraws.read(withdraw_id,index);
    return (withdrawer=withdrawer);
}

// @notice Get withdraw amount of a withdrawer 
// @param withdraw_id id of which we want withdraw amount
// @param index withdrawer index of which we want withdraw amount
// @return withdraw_amount
@view
func withdraw_amount{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(withdraw_id: felt, withdrawer:felt) -> (withdraw_amount: Uint256){
    let (withdraw_amount: Uint256) = _withdraw_amount.read(withdraw_id,withdrawer);
    return (withdraw_amount=withdraw_amount);
}

// @notice Get asset token
// @return asset_token
@view
func asset{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (asset: felt){
    let (asset) = _asset.read();
    return (asset=asset);
}

// @notice Get l1 contract address 
// @return l1_contract_address
@view
func l1_contract_address{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (l1_contract_address: felt){
    let (l1_contract_address) = _l1_contract_address.read();
    return (l1_contract_address=l1_contract_address);
}

// @notice Get token bridge
// @return token_bridge
@view
func token_bridge{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (token_bridge: felt){
    let (token_bridge) = _token_bridge.read();
    return (token_bridge=token_bridge);
}

// @notice Get assets per share
// @return assets_per_share
@view
func assets_per_share{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (assets_per_share: Uint256){
    let (assets_per_share) = _assets_per_share.read();
    return (assets_per_share=assets_per_share);
}

// @notice Get total asset locked
// @return total_assets
@view
func total_assets{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (total_assets: Uint256){
    let (totalSupply: Uint256) = total_supply.read();
    let (total_assets: Uint256) = _shares_to_assets(totalSupply);
    return (total_assets=total_assets);
}

// @notice Get total asset of a user
// @return assets_of
@view
func assetsOf{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(account: felt) -> (assets_of: Uint256){
    let (balance: Uint256) = balances.read(account = account);
    let (assets_of: Uint256) = _shares_to_assets(balance);
    return (assets_of=assets_of);
}

// @notice Get expected shares receieved on depositing
// @return shares
@view
func preview_deposit{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(assets: Uint256) -> (shares: Uint256){
    let (shares: Uint256) = _assets_to_shares(assets);
    return (shares=shares);
}

// @notice Get expected assets to mint shares
// @return assets
@view
func preview_mint{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(shares: Uint256) -> (assets: Uint256){
    let (assets: Uint256) = _shares_to_assets(shares);
    return (assets=assets);
}

// @notice Get expected shares to receive assets
// @return shares
@view
func preview_withdraw{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(assets: Uint256) -> (shares: Uint256){
    let (shares: Uint256) = _assets_to_shares(assets);
    return (shares=shares);
}

// @notice Get expected assets receieved on burning shares
// @return assets
@view
func preview_redeem{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(shares: Uint256) -> (assets: Uint256){
    let (assets: Uint256) = _shares_to_assets(shares);
    return (assets=assets);
}

//
// Setters
//

// @notice Change L1 contract address to `new_l1_contract`
// @dev Only owner can change.
// @param new_l1_contract Address of new L1 contract
@external
func update_l1_contract{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(new_l1_contract : felt){
    _only_owner();

    with_attr error_message("DefiPooling::update_l1_contract::l1 contract must be non zero"){
        assert_not_zero(new_l1_contract);
    }

    _l1_contract_address.write(new_l1_contract);

    return ();
}


//
// Setters Ownable
//

// @notice Change ownership to `future_owner`
// @dev Only owner can change. Needs to be accepted by future_owner using accept_ownership
// @param future_owner Address of new owner
@external
func initiate_ownership_transfer{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(future_owner: felt) -> (future_owner: felt){
    _only_owner();
    let (current_owner) = _owner.read();
    with_attr error_message("Registry::initiate_ownership_transfer::New owner can not be zero"){
        assert_not_zero(future_owner);
    }
    _future_owner.write(future_owner);
    owner_change_initiated.emit(current_owner=current_owner, future_owner=future_owner);
    return (future_owner=future_owner);
}

// @notice Change ownership to future_owner
// @dev Only future_owner can accept. Needs to be initiated via initiate_ownership_transfer
@external
func accept_ownership{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(){
    let (current_owner) = _owner.read();
    let (future_owner) = _future_owner.read();
    let (caller) = get_caller_address();
    with_attr error_message("Registry::accept_ownership::Only future owner can accept"){
        assert future_owner = caller;
    }
    _owner.write(future_owner);
    owner_change_completed.emit(current_owner=current_owner, future_owner=future_owner);
    return ();
}


//
// Externals ERC20
//

// @notice Transfer `amount` tokens from `caller` to `recipient`
// @param recipient Account address to which tokens are transferred
// @param amount Amount of tokens to transfer
// @return success 0 or 1
@external
func transfer{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(recipient: felt, amount: Uint256) -> (success: felt){
    let (sender) = get_caller_address();
    _transfer(sender, recipient, amount);

    // Cairo equivalent to 'return (true)'
    return (success=1);
}

// @notice Transfer `amount` tokens from `sender` to `recipient`
// @dev Checks for allowance.
// @param sender Account address from which tokens are transferred
// @param recipient Account address to which tokens are transferred
// @param amount Amount of tokens to transfer
// @return success 0 or 1
@external
func transferFrom{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        sender: felt, 
        recipient: felt, 
        amount: Uint256
    ) -> (success: felt){
    alloc_locals;
    let (local caller) = get_caller_address();
    let (local caller_allowance: Uint256) = allowances.read(owner=sender, spender=caller);

    // validates amount <= caller_allowance and returns 1 if true   
    let (enough_balance) = uint256_le(amount, caller_allowance);
    with_attr error_message("Pair::transferFrom::amount exceeds allowance"){
        assert_not_zero(enough_balance);
    }

    _transfer(sender, recipient, amount);

    // subtract allowance
    let (new_allowance: Uint256) = uint256_checked_sub_le(caller_allowance, amount);
    allowances.write(sender, caller, new_allowance);
    Approval.emit(owner=sender, spender=caller, amount=new_allowance);

    // Cairo equivalent to 'return (true)'
    return (success=1);
}

// @notice Approve `spender` to transfer `amount` tokens on behalf of `caller`
// @dev Approval may only be from zero -> nonzero or from nonzero -> zero in order
//      to mitigate the potential race condition described here:
//      https://github.com/ethereum/EIPs/issues/20//issuecomment-263524729
// @param spender The address which will spend the funds
// @param amount The amount of tokens to be spent
// @return success 0 or 1
@external
func approve{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(spender: felt, amount: Uint256) -> (success: felt){
    alloc_locals;
    let (caller) = get_caller_address();
    let (current_allowance: Uint256) = allowances.read(caller, spender);
    let (local current_allowance_mul_amount: Uint256) = uint256_checked_mul(current_allowance, amount);
    let (either_current_allowance_or_amount_is_0) =  uint256_eq(current_allowance_mul_amount, Uint256(0, 0));
    with_attr error_message("Pair::approve::Can only go from 0 to amount or amount to 0"){
        assert either_current_allowance_or_amount_is_0 = 1;
    }
    _approve(caller, spender, amount);

    // Cairo equivalent to 'return (true)'
    return (success=1);
}

// @notice Increase allowance of `spender` to transfer `added_value` more tokens on behalf of `caller`
// @param spender The address which will spend the funds
// @param added_value The increased amount of tokens to be spent
// @return success 0 or 1
@external
func increaseAllowance{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(spender: felt, added_value: Uint256) -> (success: felt){
    alloc_locals;
    uint256_check(added_value);
    let (local caller) = get_caller_address();
    let (local current_allowance: Uint256) = allowances.read(caller, spender);

    // add allowance
    let (local new_allowance: Uint256) = uint256_checked_add(current_allowance, added_value);

    _approve(caller, spender, new_allowance);

    // Cairo equivalent to 'return (true)'
    return (success=1);
}

// @notice Decrease allowance of `spender` to transfer `subtracted_value` less tokens on behalf of `caller`
// @param spender The address which will spend the funds
// @param subtracted_value The decreased amount of tokens to be spent
// @return success 0 or 1
@external
func decreaseAllowance{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(spender: felt, subtracted_value: Uint256) -> (success: felt){
    alloc_locals;
    uint256_check(subtracted_value);
    let (local caller) = get_caller_address();
    let (local current_allowance: Uint256) = allowances.read(owner=caller, spender=spender);
    let (local new_allowance: Uint256) = uint256_checked_sub_le(current_allowance, subtracted_value);

    // validates new_allowance < current_allowance and returns 1 if true   
    let (enough_allowance) = uint256_lt(new_allowance, current_allowance);
    with_attr error_message("Pair::decreaseAllowance::New allowance is greater than current allowance"){
        assert_not_zero(enough_allowance);
    }

    _approve(caller, spender, new_allowance);

    // Cairo equivalent to 'return (true)'
    return (success=1);
}



//
// Externals Defi Pooling
//

// @notice Deposit asset into contract, waiting to be bridged to L1
// @dev `caller` should have already given the cotract an allowance of at least 'amount' on asset
// @param amount The amount of token to deposit
// @return new_total_deposit The total amount of tokens deposited for current deposit_id
@external
func deposit{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount: Uint256) -> (total_deposit: Uint256){
    alloc_locals;

    let (total_deposit: Uint256) = _deposit(amount);
    return (total_deposit=total_deposit);
}


// @notice Deposit asset into contract, waiting to be bridged to L1
// @dev `caller` should have already given the cotract an allowance of at least 'amount' on asset
// @param shares The shares to receieved on depositing
// @return new_total_deposit The total amount of tokens deposited for current deposit_id
@external
func mint{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(shares: Uint256) -> (total_deposit: Uint256){
    alloc_locals;

    let (amount: Uint256) = preview_mint(shares);
    let (total_deposit: Uint256) = _deposit(amount);

    return (total_deposit=total_deposit);
}



// @notice Cancel deposit to withdraw back your asset
// @dev `caller` should have to call before the tokens are bridged to L1
// @return new_total_deposit The total amount of tokens deposited for current deposit_id
@external
func cancel_deposit{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }()->(total_deposit:Uint256){
    alloc_locals;

    let (sender) = get_caller_address();
    let (id:felt) =_deposit_id.read();

    let (deposited_amount:Uint256) = _deposit_amount.read(id,sender);

    let (is_deposit_amount_equals_to_zero) = uint256_eq(deposited_amount,Uint256(0,0));
    with_attr error_message("DefiPooling::cancel_deposit::No deposit request found"){
        assert is_deposit_amount_equals_to_zero = 0;
    }

    _deposit_amount.write(id,sender,Uint256(0,0));
    
    let (asset) = _asset.read();
    IERC20.transfer(contract_address=asset, recipient=sender, amount=deposited_amount);

    let (old_total_deposit) = _total_deposit.read(id);
    let (new_total_deposit: Uint256) = uint256_checked_sub_le(old_total_deposit,deposited_amount);

    _total_deposit.write(id,new_total_deposit);
    return (total_deposit=new_total_deposit);
}


// @notice Bridge asset to L1 for current deposit_id
// @dev only owner can call this
// @return new_deposit_id the new current deposit id
@external
func deposit_assets_to_l1{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() ->(deposit_id: felt){
    alloc_locals;
    _only_owner();

    let (id:felt) =_deposit_id.read();

    // total amount to bridge to L1
    let (amount_to_bridge:Uint256) = _total_deposit.read(id);

    
    // bridging asset token to L1
    let bridge: felt = _token_bridge.read();
    let (l1_contract_address: felt) = _l1_contract_address.read();
    //  commenting for running unit test
    ITokenBridge.initiate_withdraw(contract_address = bridge, l1_recipient = l1_contract_address, amount = amount_to_bridge);

    // sending deposit request to L1
    let (message_payload : felt*) = alloc();
    assert message_payload[0] = MESSAGE_DEPOSIT_REQUEST;
    assert message_payload[1] = id;
    assert message_payload[2] = amount_to_bridge.low;
    assert message_payload[3] = amount_to_bridge.high;
    send_message_to_l1(
        to_address=l1_contract_address,
        payload_size=4,
        payload=message_payload);

   _deposit_id.write(id+1);

    // _depositors_len.write(id+1,0)

    return(deposit_id=id+1);
}

// @notice Withdraw asset from contract, waiting to be bridged back to L2
// @dev `caller` should have Shares to withdraw
// @param assets The expected assets to receive on withdrawing
// @return new_total_withdraw The total amount of tokens withdraw request for current withdraw_id
@external
func withdraw{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(assets: Uint256)->(total_withdraw:Uint256){
    alloc_locals;

    uint256_check(assets);

    let (shares: Uint256) = preview_withdraw(assets);

    let (total_withdraw: Uint256) = _withdraw(shares);

    return (total_withdraw=total_withdraw);

}

// @notice Redeem asset from contract, waiting to be bridged back to L2
// @dev `caller` should have Shares to withdraw
// @param shares The shares to redeem assets
// @return new_total_withdraw The total amount of tokens withdraw request for current withdraw_id
@external
func redeem{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(shares: Uint256)->(total_withdraw:Uint256){
    alloc_locals;

    uint256_check(shares);

    let (total_withdraw: Uint256) = _withdraw(shares);

    return (total_withdraw=total_withdraw);

}


// @notice Cancel withdraw request
// @dev `caller` should have to call before the tokens are bridged back from L1
// @return new_total_withdraw The total amount of tokens wihdraw request for current withdraw_id
@external
func cancel_withdraw{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }()->(total_withdraw:Uint256){
    alloc_locals;

    let (sender) = get_caller_address();
    let (id:felt) =_withdraw_id.read();

    let (withdraw_amountal:Uint256) =_withdraw_amount.read(id,sender);

    let (is_withdraw_amountal_equals_to_zero) = uint256_eq(withdraw_amountal,Uint256(0,0));
    with_attr error_message("DefiPooling::cancel_withdraw::No withdraw request found"){
        assert is_withdraw_amountal_equals_to_zero = 0;
    }

   _withdraw_amount.write(id,sender,Uint256(0,0));

    // let (contract_address) = get_contract_address()
    // IERC20.transfer(contract_address=contract_address, recipient=sender, amount=withdraw_amount)
    _mint(sender,withdraw_amountal);

    let (old_total_withdraw) = _total_withdraw.read(id);
    let (new_total_withdraw: Uint256) = uint256_checked_sub_le(old_total_withdraw,withdraw_amountal);

    _total_withdraw.write(id,new_total_withdraw);
    return (total_withdraw=new_total_withdraw);
}

// @notice Send withdraw request to L1 for current withdraw_id
// @dev only owner can call this
// @return new_withdraw_id the new current withdraw id
@external
func send_withdrawal_request_to_l1{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }()->(withdraw_id: felt){
    alloc_locals;
    _only_owner();

    let (id:felt) =_withdraw_id.read();

    // total amount to withdraw from L1
    let (amount_to_withdraw: Uint256) = _total_withdraw.read(id);

    let (l1_contract_address) = _l1_contract_address.read();

    // sending withdaw request to L1
    let (message_payload : felt*) = alloc();
    assert message_payload[0] = MESSAGE_WITHDRAWAL_REQUEST;
    assert message_payload[1] = id;
    assert message_payload[2] = amount_to_withdraw.low;
    assert message_payload[3] = amount_to_withdraw.high;
    send_message_to_l1(
        to_address=l1_contract_address,
        payload_size=4,
        payload=message_payload);

   _withdraw_id.write(id + 1);

    // let (withdraw_array : felt*) = alloc()
    //_withdraws.write(new_withdraw_id,0,withdraw_array)

    return(withdraw_id=id+1);
}

// ********* changing to external function for testing*****************
// TODO: Must change @l1_handler to @external to run any tests
@l1_handler
func handle_distribute_asset{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(from_address : felt, id : felt, assets : Uint256){
    alloc_locals;
    let (distributed_assets: Uint256) = _assets_distributed.read(id);

    let (is_distributed_assets_equals_to_zero) = uint256_eq(distributed_assets, Uint256(0,0));
    // assert is_distributed_shares_equals_to_zero = 1
    with_attr error_message("DefiPooling::handle_distribute_asset::assets already distributed"){
        assert is_distributed_assets_equals_to_zero = 1;
        tempvar syscall_ptr = syscall_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar range_check_ptr = range_check_ptr;
    }
    let (l1_contract_address) = _l1_contract_address.read();
    // Make sure the message was sent by the intended L1 contract.
    // **** bypass for testing*********
    assert from_address = l1_contract_address;

    // Read the total withdraw 
    let (total_withdraw_amount) = _total_withdraw.read(id);
    let (withdraws_array_len:felt) =_withdraws_len.read(id);

    _assets_distributed.write(id, assets);

    let (assets_mul_PRECISION) = uint256_checked_mul(assets, Uint256(PRECISION,0));
    let (new_assets_per_share, _) = uint256_unsigned_div_rem(assets_mul_PRECISION, total_withdraw_amount);
    _assets_per_share.write(new_assets_per_share);

    _distribute_asset(id,withdraws_array_len, total_withdraw_amount, assets);

    return ();
}

// TODO: Must change @l1_handler to @external to run any tests
@l1_handler
func handle_distribute_share{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(from_address : felt, id : felt, shares : Uint256){
    alloc_locals;

    let (distributed_shares: Uint256) = _shares_distributed.read(id);

    let (is_distributed_shares_equals_to_zero) = uint256_eq(distributed_shares, Uint256(0,0));
    // assert is_distributed_shares_equals_to_zero = 1
    with_attr error_message("DefiPooling::handle_distribute_share::shares already distributed"){
        assert is_distributed_shares_equals_to_zero = 1;
        tempvar syscall_ptr = syscall_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar range_check_ptr = range_check_ptr;
    }

    let (l1_contract_address) = _l1_contract_address.read();
    // Make sure the message was sent by the intended L1 contract.
    // **** bypass for testing*********
    assert from_address = l1_contract_address;

    // Read the total deposit 
    let (total_deposit_amount) = _total_deposit.read(id);
    let (depositors_array_len: felt) = _depositors_len.read(id);

    _shares_distributed.write(id,shares);

    let (total_deposit_amount_mul_PRECISION) = uint256_checked_mul(total_deposit_amount, Uint256(PRECISION,0));
    let (new_assets_per_share, _) = uint256_unsigned_div_rem(total_deposit_amount_mul_PRECISION, shares);
    _assets_per_share.write(new_assets_per_share);

    _distribute_share(id,depositors_array_len, total_deposit_amount, shares);

    return ();
}

// 
// Internal Defi Pooling
// 

func _deposit{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount: Uint256) -> (total_deposit: Uint256){
    alloc_locals;

    let (sender:felt) = get_caller_address();
    let (contract_address) = get_contract_address();
    let (asset) = _asset.read();

    IERC20.transferFrom(contract_address=asset, sender=sender, recipient=contract_address, amount=amount);

    let (id:felt) =_deposit_id.read();
    // let (depositors_array_len: felt, depositors_array: felt*) = depositors(id)
    let (depositors_array_len: felt) = _depositors_len.read(id);
    // let (depositors_array: felt) = depositors.read(id,Uint256(0,0));

    let (deposited_amount: Uint256) = _deposit_amount.read(deposit_id=id,depositor=sender);
    local new_deposited_amount: Uint256;
    // let deposited_amount = Uint256(deposited_amount_felt,0);

    let (is_deposit_amount_equals_to_zero) = uint256_eq(deposited_amount,Uint256(0,0));
    if (is_deposit_amount_equals_to_zero == 1) {
        _depositors_len.write(id, depositors_array_len+1);
        _depositors.write(id,depositors_array_len, sender);
        assert new_deposited_amount = amount;
        tempvar syscall_ptr = syscall_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar range_check_ptr = range_check_ptr;
    } else {
        let (temp:Uint256) = uint256_checked_add(deposited_amount,amount);
        assert new_deposited_amount = temp;
        tempvar syscall_ptr = syscall_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar range_check_ptr = range_check_ptr;
    }

    _deposit_amount.write(id,sender,new_deposited_amount);


// *****************Method 2**************************
    // let (depositors_array_len: felt, depositors_array: Depositor*) = depositors(id)
    // local new_depositor : Depositor = Depositor(userAddress = sender, amount = amount)
    // assert [depositors_array + depositors_array_len] = new_depositor
    // depositors_array_len = depositors_array_len + Depositor.SIZE
    // depositors.write(id,depositors_array_len,depositor_array)
// ************************************************************

    let (old_total_deposit) = _total_deposit.read(id);
    let (new_total_deposit: Uint256) = uint256_checked_add(old_total_deposit,amount);

    _total_deposit.write(id,new_total_deposit);

    return (total_deposit=new_total_deposit);
}

func _withdraw{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount: Uint256)->(total_withdraw:Uint256){
    alloc_locals;

    uint256_check(amount);

    let (sender) = get_caller_address();
    let (contract_address) = get_contract_address();

    // *** not required as _burn will revert if this fails *******

    // let (balance: Uint256) = balances.read(account=sender)
    // let(is_amount_less_than_equals_to_balance) = uint256_le(amount,balance)
    // with_attr error_message("DefiPooling::withdraw::Insufficient withdrawal amount"){
    //     assert_not_zero(is_amount_less_than_equals_to_balance)
    // end


    // IERC20.transferFrom(contract_address=contract_address, sender=sender, recipient=contract_address, amount=amount)
    _burn(sender,amount);

    let (id:felt) =_withdraw_id.read();
    // let (withdrawer: felt) =_withdraws.read(id)
    let (withdraws_array_len: felt) =_withdraws_len.read(id);

    let (withdrawal_amount:Uint256) =_withdraw_amount.read(id,sender);
    local new_withdrawal_amount: Uint256;

    let (is_withdrawal_amount_equals_to_zero) = uint256_eq(withdrawal_amount,Uint256(0,0));
    if (is_withdrawal_amount_equals_to_zero == 1) {
       _withdraws_len.write(id, withdraws_array_len+1);
       _withdraws.write(id,withdraws_array_len,sender);
        assert new_withdrawal_amount = amount;
        tempvar syscall_ptr = syscall_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar range_check_ptr = range_check_ptr;
    } else {
        let (temp:Uint256) = uint256_checked_add(withdrawal_amount,amount);
        assert new_withdrawal_amount = temp;
        tempvar syscall_ptr = syscall_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar range_check_ptr = range_check_ptr;
    }

   _withdraw_amount.write(id,sender,new_withdrawal_amount);

    let (old_total_withdraw) = _total_withdraw.read(id);
    let (new_total_withdraw: Uint256) = uint256_checked_add(old_total_withdraw,amount);

    _total_withdraw.write(id,new_total_withdraw);

    return (total_withdraw=new_total_withdraw);

}


func _distribute_share{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(id: felt, depositors_len: felt, total_deposit: Uint256, amount: Uint256){
    alloc_locals;

    if (depositors_len == 0) {
        return ();
    }

    let (depositor: felt) = _depositors.read(id,depositors_len-1);
    let (deposited_amount: Uint256) = _deposit_amount.read(id,depositor);
    let (deposited_amount_mul_amount: Uint256) = uint256_checked_mul(deposited_amount,amount);
    let (amount_to_mint: Uint256, _) = uint256_unsigned_div_rem(deposited_amount_mul_amount,total_deposit);

    let (is_amount_to_mint_less_than_zero) = uint256_le(amount_to_mint,Uint256(0,0));
    if (is_amount_to_mint_less_than_zero == 0) {
        _mint(depositor,amount_to_mint);
        tempvar syscall_ptr = syscall_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar range_check_ptr = range_check_ptr;
    } else {
        tempvar syscall_ptr = syscall_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar range_check_ptr = range_check_ptr;
    }

    local syscall_ptr: felt* = syscall_ptr;
    local pedersen_ptr: HashBuiltin* = pedersen_ptr;
    
    return _distribute_share(id = id, depositors_len = depositors_len - 1, total_deposit = total_deposit, amount = amount);
}

func _distribute_asset{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(id: felt, withdraws_len: felt, total_withdraw: Uint256, amount: Uint256){
    alloc_locals;

    if (withdraws_len == 0) {
        return ();
    }

    let (withdrawer: felt) = _withdraws.read(id,withdraws_len-1);
    let (withdrawal_amount: Uint256) =_withdraw_amount.read(id,withdrawer);
    let (withdrawal_amount_mul_amount: Uint256) = uint256_checked_mul(withdrawal_amount,amount);
    let (amount_to_withdraw: Uint256, _) = uint256_unsigned_div_rem(withdrawal_amount_mul_amount,total_withdraw);
    let (asset) = _asset.read();

    let (is_amount_to_withdraw_less_than_zero) = uint256_le(amount_to_withdraw,Uint256(0,0));
    if (is_amount_to_withdraw_less_than_zero == 0) {
        IERC20.transfer(contract_address=asset, recipient=withdrawer, amount=amount_to_withdraw);
        tempvar syscall_ptr = syscall_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar range_check_ptr = range_check_ptr;
    } else {
        tempvar syscall_ptr = syscall_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar range_check_ptr = range_check_ptr;
    }

    return _distribute_asset(id = id, withdraws_len = withdraws_len - 1, total_withdraw = total_withdraw, amount = amount);
}



func _assets_to_shares{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(assets: Uint256)->(shares: Uint256){
    alloc_locals;

    let (assets_per_share: Uint256) = _assets_per_share.read();

    let (is_assets_per_share_is_equals_zero) = uint256_eq(assets_per_share, Uint256(0,0));
    
    if (is_assets_per_share_is_equals_zero == 1) {
        return (shares=Uint256(0,0));
    }
    let (assets_mul_PRECISION) = uint256_checked_mul(assets, Uint256(PRECISION,0));
    let (shares: Uint256, _) = uint256_unsigned_div_rem(assets_mul_PRECISION,assets_per_share);

    return (shares=shares);
}

func _shares_to_assets{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(shares: Uint256 )->(assets: Uint256){
    alloc_locals;

    let(assets_per_share: Uint256) = _assets_per_share.read();

    let (assets_mul_PRECISION: Uint256) = uint256_checked_mul(shares,assets_per_share);
    let (assets: Uint256, _) = uint256_unsigned_div_rem(assets_mul_PRECISION,Uint256(PRECISION,0));

    return (assets=assets);
}

//
// Internals ERC20
//

func _mint{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(recipient: felt, amount: Uint256){
    alloc_locals;
    with_attr error_message("Pair::_mint::recipient can not be zero"){
        assert_not_zero(recipient);
    }
    uint256_check(amount);

    let (balance: Uint256) = balances.read(account=recipient);
    // overflow is not possible because sum is guaranteed to be less than total supply
    // which we check for overflow below
    let (new_balance: Uint256) = uint256_checked_add(balance, amount);
    balances.write(recipient, new_balance);

    let (local supply: Uint256) = total_supply.read();
    let (local new_supply: Uint256) = uint256_checked_add(supply, amount);

    total_supply.write(new_supply);
    Mint.emit(to = recipient, amount = amount);
    return ();
}

func _burn{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(account: felt, amount: Uint256){
    alloc_locals;
    with_attr error_message("Pair::_burn::account can not be zero"){
        assert_not_zero(account);
    }
    uint256_check(amount);

    let (balance: Uint256) = balances.read(account);
    // validates amount <= balance and returns 1 if true
    let (enough_balance) = uint256_le(amount, balance);
    with_attr error_message("Pair::_burn::not enough balance to burn"){
        assert_not_zero(enough_balance);
    }
    
    let (new_balance: Uint256) = uint256_checked_sub_le(balance, amount);
    balances.write(account, new_balance);

    let (supply: Uint256) = total_supply.read();
    let (new_supply: Uint256) = uint256_checked_sub_le(supply, amount);
    total_supply.write(new_supply);
    Burn.emit(account = account, amount = amount);
    return ();
}

func _transfer{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(sender: felt, recipient: felt, amount: Uint256){
    alloc_locals;
    with_attr error_message("Pair::_transfer::sender can not be zero"){
        assert_not_zero(sender);
    }
    with_attr error_message("Pair::_transfer::recipient can not be zero"){
        assert_not_zero(recipient);
    }
    uint256_check(amount); // almost surely not needed, might remove after confirmation

    let (local sender_balance: Uint256) = balances.read(account=sender);

    // validates amount <= sender_balance and returns 1 if true
    let (enough_balance) = uint256_le(amount, sender_balance);
    with_attr error_message("Pair::_transfer::not enough balance for sender"){
        assert_not_zero(enough_balance);
    }

    // subtract from sender
    let (new_sender_balance: Uint256) = uint256_checked_sub_le(sender_balance, amount);
    balances.write(sender, new_sender_balance);

    // add to recipient
    let (recipient_balance: Uint256) = balances.read(account=recipient);
    // overflow is not possible because sum is guaranteed by mint to be less than total supply
    let (new_recipient_balance: Uint256) = uint256_checked_add(recipient_balance, amount);
    balances.write(recipient, new_recipient_balance);

    Transfer.emit(from_address=sender, to_address=recipient, amount=amount);
    return ();
}

func _approve{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(caller: felt, spender: felt, amount: Uint256){
    with_attr error_message("Pair::_approve::caller can not be zero"){
        assert_not_zero(caller);
    }
    with_attr error_message("Pair::_approve::spender can not be zero"){
        assert_not_zero(spender);
    }
    uint256_check(amount);
    allowances.write(caller, spender, amount);
    Approval.emit(owner=caller, spender=spender, amount=amount);
    return ();
}


//
// Internals Ownable
//

func _only_owner{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(){
    let (owner) = _owner.read();
    let (caller) = get_caller_address();
    with_attr error_message("DefiPooling::_only_owner::Caller must be owner"){
        assert owner = caller;
    }
    return ();
}



