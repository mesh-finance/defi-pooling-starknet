%lang starknet

# @title DefiPooling for depositing in L1 protocol directky from L2
# @author Mesh Finance
# @license MIT
# @dev an ERC20 token

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_block_timestamp, get_contract_address
from starkware.cairo.common.math import assert_le, assert_not_zero, assert_not_equal
from starkware.cairo.common.math_cmp import is_le, is_le_felt
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import (Uint256, uint256_le, uint256_lt, uint256_check, uint256_eq, uint256_sqrt, uint256_unsigned_div_rem)
from contracts.utils.math import uint256_checked_add, uint256_checked_sub_lt, uint256_checked_mul, uint256_felt_checked_mul,uint256_checked_sub_le
from starkware.starknet.common.messages import send_message_to_l1


const MESSAGE_WITHDRAWAL_REQUEST = 1

#
# Interfaces
#
@contract_interface
namespace IERC20:
    
    func balanceOf(account: felt) -> (balance: Uint256):
    end

    func transfer(recipient: felt, amount: Uint256) -> (success: felt):
    end

    func transferFrom(
            sender: felt, 
            recipient: felt, 
            amount: Uint256
        ) -> (success: felt):
    end
end


#
# Storage ERC20
#

# @dev Name of the token
@storage_var
func _name() -> (res: felt):
end

# @dev Symbol of the token
@storage_var
func _symbol() -> (res: felt):
end

# @dev Decimals of the token
@storage_var
func _decimals() -> (res: felt):
end

# @dev Total Supply of the token
@storage_var
func total_supply() -> (res: Uint256):
end

# @dev Balances of the token for each account
@storage_var
func balances(account: felt) -> (res: Uint256):
end

# @dev Allowances of the token for owner-spender pair 
@storage_var
func allowances(owner: felt, spender: felt) -> (res: Uint256):
end


#
# Storage Ownable
#

# @dev Address of the owner of the contract
@storage_var
func _owner() -> (address: felt):
end

# @dev Address of the future owner of the contract
@storage_var
func _future_owner() -> (address: felt):
end

# An event emitted whenever initiate_ownership_transfer() is called.
@event
func owner_change_initiated(current_owner: felt, future_owner: felt):
end

# An event emitted whenever accept_ownership() is called.
@event
func owner_change_completed(current_owner: felt, future_owner: felt):
end


#
# Storage DefiPooling
#

# @dev underlying token
@storage_var
func _underlying_token() -> (res: felt):
end

# @dev L1 contract address
@storage_var
func _l1_contract_address() -> (res: felt):
end


# @dev total deposit for each deposit to L1
@storage_var
func _total_deposit(deposit_id: Uint256) -> (res: Uint256):
end

# @dev deposit id
@storage_var
func _deposit_id() -> (id: Uint256):
end

# @dev array to store all the depositor address
@storage_var
func _depositors(deposit_id: Uint256, index: felt) -> ( depositors: felt):
end

# @dev array to store all the depositor address
@storage_var
func _depositors_len(deposit_id: Uint256) -> (res: felt):
end

# @dev array to store depositor info
@storage_var
func _deposit_amount(deposit_id: Uint256, depositor: felt) -> (amount: Uint256):
end

# @dev total withdraw for each withdraw call to L1
@storage_var
func _total_withdraw(withdraw_id: Uint256) -> (res: Uint256):
end

# @dev withdraw id
@storage_var
func _withdraw_id() -> (id: Uint256):
end

# @dev array to store all the withdraw address
@storage_var
func _withdraws(withdraw_id: Uint256,index:felt) -> (withdraws: felt):
end

# @dev array to store all the withdraw address
@storage_var
func _withdraws_len(withdraw_id: Uint256) -> (withdraws_len: felt):
end

# @dev array to store withdraw info
@storage_var
func _withdraw_amount(withdraw_id: Uint256, withdrawer: felt) -> (amount: Uint256):
end

# @notice An event emitted whenever token is transferred.
@event
func Transfer(from_address: felt, to_address: felt, amount: Uint256):
end

# @notice An event emitted whenever allowances is updated
@event
func Approval(owner: felt, spender: felt, amount: Uint256):
end

# @notice An event emitted whenever mint() is called.
@event
func Mint(to: felt, amount: Uint256):
end

# @notice An event emitted whenever burn() is called.
@event
func Burn(account: felt, amount: Uint256):
end


# ********** method 2****************
# @dev array to store depositor info
# @storage_var
# func depositors(deposit_id: Uint256) -> (depositors_len: felt, depositors: Depositor*):
# end

# # @dev struct to store depositor info
# struct Depositor:
#     member userAddress : felt
#     member amount : Uint256
# end
# ***********************************************

#
# Constructor
#

# @notice Contract constructor
# @param name Name of the pair token
# @param symbol Symbol of the pair token
@constructor
func constructor{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        name: felt,
        symbol: felt,
        l1_contract_address: felt,
        underlying_token: felt,
        owner: felt,
    ):
    with_attr error_message("DefiPooling::constructor::all arguments must be non zero"):
        assert_not_zero(name)
        assert_not_zero(symbol)
        assert_not_zero(l1_contract_address)
        assert_not_zero(underlying_token)
        assert_not_zero(owner)

    end
    _name.write(name)
    _symbol.write(symbol)
    _decimals.write(18)
    # _percesion.write(9)
    _l1_contract_address.write(l1_contract_address)
    _underlying_token.write(underlying_token)
    _owner.write(owner)
   _deposit_id.write(Uint256(0,0))

    _depositors_len.write(Uint256(0,0),0)
    #_withdraws_len.write(Uint256(0,0),0)

# ********** method 2****************    
    # initialising the depositor array for deposit id 0
    # let (depositor_array : Depositor*) = alloc()
    # depositors.write(Uint256(0,0),0,depositor_array)
# *********************************************
    return ()
end



#
# Getters ERC20
#

# @notice Name of the token
# @return name
@view
func name{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (name: felt):
    let (name) = _name.read()
    return (name)
end

# @notice Symbol of the token
# @return symbol
@view
func symbol{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (symbol: felt):
    let (symbol) = _symbol.read()
    return (symbol)
end

# @notice Total Supply of the token
# @return totalSupply
@view
func totalSupply{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (totalSupply: Uint256):
    let (totalSupply: Uint256) = total_supply.read()
    return (totalSupply)
end

# @notice Decimals of the token
# @return decimals
@view
func decimals{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (decimals: felt):
    let (decimals) = _decimals.read()
    return (decimals)
end

# @notice Balance of `account`
# @param account Account address whose balance is fetched
# @return balance Balance of `account`
@view
func balanceOf{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(account: felt) -> (balance: Uint256):
    let (balance: Uint256) = balances.read(account=account)
    return (balance)
end

# @notice Allowance which `spender` can spend on behalf of `owner`
# @param owner Account address whose tokens are spent
# @param spender Account address which can spend the tokens
# @return remaining
@view
func allowance{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(owner: felt, spender: felt) -> (remaining: Uint256):
    let (remaining: Uint256) = allowances.read(owner=owner, spender=spender)
    return (remaining)
end


#
# Getters Defi Pooling
#

# @notice Get contract owner address
# @return owner
@view
func owner{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (owner: felt):
    let (owner) = _owner.read()
    return (owner)
end

@view
func current_deposit_id{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (id: Uint256):
    let (id:Uint256) =_deposit_id.read()
    return (id)
end

@view
func total_deposit_amount{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(deposit_id: Uint256) -> (total_deposit_amount: Uint256):
    let (total_deposit_amount: Uint256) = _total_deposit.read(deposit_id)
    return (total_deposit_amount)
end

@view
func depositors_len{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(deposit_id: Uint256) -> (depositors_len: felt):
    let (depositors_len: felt) = _depositors_len.read(deposit_id)
    return (depositors_len)
end

@view
func depositors{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(deposit_id: Uint256, index:felt) -> (depositors: felt):
    let (depositors: felt) = _depositors.read(deposit_id,index)
    return (depositors)
end

@view
func deposit_amount{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(deposit_id: Uint256, depositor:felt) -> (deposit_amount: Uint256):
    let (deposit_amount: Uint256) = _deposit_amount.read(deposit_id,depositor)
    return (deposit_amount)
end

@view
func current_withdraw_id{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (id: Uint256):
    let (id:Uint256) =_withdraw_id.read()
    return (id)
end

@view
func total_withdraw_amount{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(withdraw_id: Uint256) -> (total_withdraw_amount: Uint256):
    let (total_withdraw_amount: Uint256) = _total_withdraw.read(withdraw_id)
    return (total_withdraw_amount)
end

@view
func withdraws_len{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(withdraw_id: Uint256) -> (withdraws_len: felt):
    let (withdraws_len: felt) = _withdraws_len.read(withdraw_id)
    return (withdraws_len)
end

@view
func withdraws{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(withdraw_id: Uint256, index:felt) -> (withdrawer: felt):
    let (withdrawer: felt) = _withdraws.read(withdraw_id,index)
    return (withdrawer)
end

@view
func withdraw_amount{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(withdraw_id: Uint256, withdrawer:felt) -> (withdraw_amount: Uint256):
    let (withdraw_amount: Uint256) = _withdraw_amount.read(withdraw_id,withdrawer)
    return (withdraw_amount)
end

@view
func underlying_token{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (underlying_token: felt):
    let (underlying_token) = _underlying_token.read()
    return (underlying_token)
end

@view
func l1_contract_address{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (l1_contract_address: felt):
    let (l1_contract_address) = _l1_contract_address.read()
    return (l1_contract_address)
end

#
# Setters
#
@external
func update_l1_contract{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(new_l1_contract : felt):
    _only_owner()

    with_attr error_message("DefiPooling::update_l1_contract::l1 contract must be non zero"):
        assert_not_zero(new_l1_contract)
    end

    _l1_contract_address.write(new_l1_contract)

    return ()
end


#
# Setters Ownable
#

# @notice Change ownership to `future_owner`
# @dev Only owner can change. Needs to be accepted by future_owner using accept_ownership
# @param future_owner Address of new owner
@external
func initiate_ownership_transfer{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(future_owner: felt) -> (future_owner: felt):
    _only_owner()
    let (current_owner) = _owner.read()
    with_attr error_message("Registry::initiate_ownership_transfer::New owner can not be zero"):
        assert_not_zero(future_owner)
    end
    _future_owner.write(future_owner)
    owner_change_initiated.emit(current_owner=current_owner, future_owner=future_owner)
    return (future_owner=future_owner)
end

# @notice Change ownership to future_owner
# @dev Only future_owner can accept. Needs to be initiated via initiate_ownership_transfer
@external
func accept_ownership{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    let (current_owner) = _owner.read()
    let (future_owner) = _future_owner.read()
    let (caller) = get_caller_address()
    with_attr error_message("Registry::accept_ownership::Only future owner can accept"):
        assert future_owner = caller
    end
    _owner.write(future_owner)
    owner_change_completed.emit(current_owner=current_owner, future_owner=future_owner)
    return ()
end




#
# Externals ERC20
#

# @notice Transfer `amount` tokens from `caller` to `recipient`
# @param recipient Account address to which tokens are transferred
# @param amount Amount of tokens to transfer
# @return success 0 or 1
@external
func transfer{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(recipient: felt, amount: Uint256) -> (success: felt):
    let (sender) = get_caller_address()
    _transfer(sender, recipient, amount)

    # Cairo equivalent to 'return (true)'
    return (1)
end

# @notice Transfer `amount` tokens from `sender` to `recipient`
# @dev Checks for allowance.
# @param sender Account address from which tokens are transferred
# @param recipient Account address to which tokens are transferred
# @param amount Amount of tokens to transfer
# @return success 0 or 1
@external
func transferFrom{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        sender: felt, 
        recipient: felt, 
        amount: Uint256
    ) -> (success: felt):
    alloc_locals
    let (local caller) = get_caller_address()
    let (local caller_allowance: Uint256) = allowances.read(owner=sender, spender=caller)

    # validates amount <= caller_allowance and returns 1 if true   
    let (enough_balance) = uint256_le(amount, caller_allowance)
    with_attr error_message("Pair::transferFrom::amount exceeds allowance"):
        assert_not_zero(enough_balance)
    end

    _transfer(sender, recipient, amount)

    # subtract allowance
    let (new_allowance: Uint256) = uint256_checked_sub_le(caller_allowance, amount)
    allowances.write(sender, caller, new_allowance)
    Approval.emit(owner=sender, spender=caller, amount=new_allowance)

    # Cairo equivalent to 'return (true)'
    return (1)
end

# @notice Approve `spender` to transfer `amount` tokens on behalf of `caller`
# @dev Approval may only be from zero -> nonzero or from nonzero -> zero in order
#      to mitigate the potential race condition described here:
#      https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
# @param spender The address which will spend the funds
# @param amount The amount of tokens to be spent
# @return success 0 or 1
@external
func approve{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(spender: felt, amount: Uint256) -> (success: felt):
    alloc_locals
    let (caller) = get_caller_address()
    let (current_allowance: Uint256) = allowances.read(caller, spender)
    let (local current_allowance_mul_amount: Uint256) = uint256_checked_mul(current_allowance, amount)
    let (either_current_allowance_or_amount_is_0) =  uint256_eq(current_allowance_mul_amount, Uint256(0, 0))
    with_attr error_message("Pair::approve::Can only go from 0 to amount or amount to 0"):
        assert either_current_allowance_or_amount_is_0 = 1
    end
    _approve(caller, spender, amount)

    # Cairo equivalent to 'return (true)'
    return (1)
end

# @notice Increase allowance of `spender` to transfer `added_value` more tokens on behalf of `caller`
# @param spender The address which will spend the funds
# @param added_value The increased amount of tokens to be spent
# @return success 0 or 1
@external
func increaseAllowance{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(spender: felt, added_value: Uint256) -> (success: felt):
    alloc_locals
    uint256_check(added_value)
    let (local caller) = get_caller_address()
    let (local current_allowance: Uint256) = allowances.read(caller, spender)

    # add allowance
    let (local new_allowance: Uint256) = uint256_checked_add(current_allowance, added_value)

    _approve(caller, spender, new_allowance)

    # Cairo equivalent to 'return (true)'
    return (1)
end

# @notice Decrease allowance of `spender` to transfer `subtracted_value` less tokens on behalf of `caller`
# @param spender The address which will spend the funds
# @param subtracted_value The decreased amount of tokens to be spent
# @return success 0 or 1
@external
func decreaseAllowance{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(spender: felt, subtracted_value: Uint256) -> (success: felt):
    alloc_locals
    uint256_check(subtracted_value)
    let (local caller) = get_caller_address()
    let (local current_allowance: Uint256) = allowances.read(owner=caller, spender=spender)
    let (local new_allowance: Uint256) = uint256_checked_sub_le(current_allowance, subtracted_value)

    # validates new_allowance < current_allowance and returns 1 if true   
    let (enough_allowance) = uint256_lt(new_allowance, current_allowance)
    with_attr error_message("Pair::decreaseAllowance::New allowance is greater than current allowance"):
        assert_not_zero(enough_allowance)
    end

    _approve(caller, spender, new_allowance)

    # Cairo equivalent to 'return (true)'
    return (1)
end



#
# Externals Defi Pooling
#

@external
func deposit{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount: Uint256) -> (total_deposit: Uint256):
    alloc_locals

    let (sender:felt) = get_caller_address()
    let (contract_address) = get_contract_address()
    let (underlying_token) = _underlying_token.read()

    IERC20.transferFrom(contract_address=underlying_token, sender=sender, recipient=contract_address, amount=amount)

    let (id:Uint256) =_deposit_id.read()
    # let (depositors_array_len: felt, depositors_array: felt*) = depositors(id)
    let (depositors_array_len: felt) = _depositors_len.read(id)
    # let (depositors_array: felt) = depositors.read(id,Uint256(0,0))

    let (deposited_amount: Uint256) = _deposit_amount.read(deposit_id=id,depositor=sender)
    local new_deposited_amount: Uint256
    # let deposited_amount = Uint256(deposited_amount_felt,0)

    let (is_deposit_amount_equals_to_zero) = uint256_eq(deposited_amount,Uint256(0,0))
    if is_deposit_amount_equals_to_zero == 1:
        _depositors_len.write(id, depositors_array_len+1)
        _depositors.write(id,depositors_array_len, sender)
        assert new_deposited_amount = amount
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        let (temp:Uint256) = uint256_checked_add(deposited_amount,amount)
        assert new_deposited_amount = temp
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    _deposit_amount.write(id,sender,new_deposited_amount)


# *****************Method 2**************************
    # let (depositors_array_len: felt, depositors_array: Depositor*) = depositors(id)
    # local new_depositor : Depositor = Depositor(userAddress = sender, amount = amount)
    # assert [depositors_array + depositors_array_len] = new_depositor
    # depositors_array_len = depositors_array_len + Depositor.SIZE
    # depositors.write(id,depositors_array_len,depositor_array)
# ************************************************************

    let (old_total_deposit) = _total_deposit.read(id)
    let (new_total_deposit: Uint256) = uint256_checked_add(old_total_deposit,amount)

    _total_deposit.write(id,new_total_deposit)

    return (new_total_deposit)
end


@external
func cancel_deposit{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }()->(total_deposit:Uint256):
    alloc_locals

    let (sender) = get_caller_address()
    let (id:Uint256) =_deposit_id.read()

    let (deposited_amount:Uint256) = _deposit_amount.read(id,sender)

    let (is_deposit_amount_equals_to_zero) = uint256_eq(deposited_amount,Uint256(0,0))
    with_attr error_message("DefiPooling::cancel_deposit::No deposit request found"):
        assert is_deposit_amount_equals_to_zero = 0
    end

    _deposit_amount.write(id,sender,Uint256(0,0))
    
    let (underlying_token) = _underlying_token.read()
    IERC20.transfer(contract_address=underlying_token, recipient=sender, amount=deposited_amount)

    let (old_total_deposit) = _total_deposit.read(id)
    let (new_total_deposit: Uint256) = uint256_checked_sub_le(old_total_deposit,deposited_amount)

    _total_deposit.write(id,new_total_deposit)
    return (new_total_deposit)
end


@external
func deposit_to_l1{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() ->(deposit_id: Uint256):
    alloc_locals
    _only_owner()

    let (id:Uint256) =_deposit_id.read()

    # total amount to bridge to L1
    let (amount_to_bridge:Uint256) = _total_deposit.read(id)

    # ###########
    # TODO: bridging underlying token to L1
    # ###########

    let (new_deposit_id:Uint256) = uint256_checked_add(id,Uint256(1,0))
   _deposit_id.write(new_deposit_id)

    _depositors_len.write(new_deposit_id,0)

    return(new_deposit_id)
end

# ********* changing to external function for testing*****************
# @l1_handler
@external
func distribute_share{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(from_address : felt, id : Uint256, amount : Uint256):

    let (l1_contract_address) = _l1_contract_address.read()
    # Make sure the message was sent by the intended L1 contract.
    # **** bypass for testing*********
    # assert from_address = l1_contract_address

    # Read the total deposit 
    let (total_deposit_amount) = _total_deposit.read(id)
    let (depositors_array_len: felt) = _depositors_len.read(id)

    _distribute_share(id,depositors_array_len, total_deposit_amount, amount)

    return ()
end

@external
func withdraw{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount: Uint256)->(total_withdraw:Uint256):
    alloc_locals

    uint256_check(amount)

    let (sender) = get_caller_address()
    let (contract_address) = get_contract_address()

    # *** not required as _burn will revert if this fails *******

    # let (balance: Uint256) = balances.read(account=sender)
    # let(is_amount_less_than_equals_to_balance) = uint256_le(amount,balance)
    # with_attr error_message("DefiPooling::withdraw::Insufficient withdrawal amount"):
    #     assert_not_zero(is_amount_less_than_equals_to_balance)
    # end

    

    # IERC20.transferFrom(contract_address=contract_address, sender=sender, recipient=contract_address, amount=amount)
    _burn(sender,amount)

    let (id:Uint256) =_withdraw_id.read()
    # let (withdrawer: felt) =_withdraws.read(id)
    let (withdraws_array_len: felt) =_withdraws_len.read(id)

    let (withdrawal_amount:Uint256) =_withdraw_amount.read(id,sender)
    local new_withdrawal_amount: Uint256

    let (is_withdrawal_amount_equals_to_zero) = uint256_eq(withdrawal_amount,Uint256(0,0))
    if is_withdrawal_amount_equals_to_zero == 1:
       _withdraws_len.write(id, withdraws_array_len+1)
       _withdraws.write(id,withdraws_array_len,sender)
        assert new_withdrawal_amount = amount
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        let (temp:Uint256) = uint256_checked_add(withdrawal_amount,amount)
        assert new_withdrawal_amount = temp
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

   _withdraw_amount.write(id,sender,new_withdrawal_amount)

    let (old_total_withdraw) = _total_withdraw.read(id)
    let (new_total_withdraw: Uint256) = uint256_checked_add(old_total_withdraw,amount)

    _total_withdraw.write(id,new_total_withdraw)

    return (new_total_withdraw)

end

@external
func cancel_withdraw{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }()->(total_withdraw:Uint256):
    alloc_locals

    let (sender) = get_caller_address()
    let (id:Uint256) =_withdraw_id.read()

    let (withdraw_amountal:Uint256) =_withdraw_amount.read(id,sender)

    let (is_withdraw_amountal_equals_to_zero) = uint256_eq(withdraw_amountal,Uint256(0,0))
    with_attr error_message("DefiPooling::cancel_deposit::No withdraw request found"):
        assert is_withdraw_amountal_equals_to_zero = 0
    end

   _withdraw_amount.write(id,sender,Uint256(0,0))

    # let (contract_address) = get_contract_address()
    # IERC20.transfer(contract_address=contract_address, recipient=sender, amount=withdraw_amount)
    _mint(sender,withdraw_amountal)

    let (old_total_withdraw) = _total_withdraw.read(id)
    let (new_total_withdraw: Uint256) = uint256_checked_sub_le(old_total_withdraw,withdraw_amountal)

    _total_withdraw.write(id,new_total_withdraw)
    return (new_total_withdraw)
end


@external
func send_withdrawal_request_to_l1{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }()->(withdraw_id: Uint256):
    alloc_locals
    _only_owner()

    let (id:Uint256) =_withdraw_id.read()

    # total amount to withdraw from L1
    let (amount_to_withdraw: Uint256) = _total_withdraw.read(id)

    let (l1_contract_address) = _l1_contract_address.read()

    # sending withdaw request to L1
    let (message_payload : felt*) = alloc()
    assert message_payload[0] = MESSAGE_WITHDRAWAL_REQUEST
    assert message_payload[1] = id.low                          # id,amount_to_withdraw are Uint256 and thus required 2 index to store
    assert message_payload[2] = amount_to_withdraw.low
    send_message_to_l1(
        to_address=l1_contract_address,
        payload_size=3,
        payload=message_payload)

    let (new_withdraw_id: Uint256) = uint256_checked_add(id,Uint256(1,0))
   _withdraw_id.write(new_withdraw_id)

    # let (withdraw_array : felt*) = alloc()
    #_withdraws.write(new_withdraw_id,0,withdraw_array)

    return(new_withdraw_id)
end

# ********* changing to external function for testing*****************
# @l1_handler
@external
func distribute_underlying{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(from_address : felt, id : Uint256, amount : Uint256):

    let (l1_contract_address) = _l1_contract_address.read()
    # Make sure the message was sent by the intended L1 contract.
    # **** bypass for testing*********
    # assert from_address = l1_contract_address

    # Read the total withdraw 
    let (total_withdraw_amount) = _total_withdraw.read(id)
    let (withdraws_array_len:felt) =_withdraws_len.read(id)

    _distribute_underlying(id,withdraws_array_len, total_withdraw_amount, amount)

    return ()
end








# 
# Internal Defi Pooling
# 
func _distribute_share{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }( id: Uint256, depositors_len: felt, total_deposit: Uint256, amount: Uint256):
    alloc_locals

    if depositors_len == 0:
        return ()
    end

    let (depositor: felt) = _depositors.read(id,depositors_len-1)
    let (deposited_amount: Uint256) = _deposit_amount.read(id,depositor)
    let (deposited_amount_mul_amount: Uint256) = uint256_checked_mul(deposited_amount,amount)
    let (amount_to_mint: Uint256, _) = uint256_unsigned_div_rem(deposited_amount_mul_amount,total_deposit)

    let (is_amount_to_mint_less_than_zero) = uint256_le(amount_to_mint,Uint256(0,0))
    if is_amount_to_mint_less_than_zero == 0:
        _mint(depositor,amount_to_mint)
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr

    end
    local syscall_ptr: felt* = syscall_ptr
    local pedersen_ptr: HashBuiltin* = pedersen_ptr
    
    return _distribute_share(id = id, depositors_len = depositors_len - 1, total_deposit = total_deposit, amount = amount)
end

func _distribute_underlying{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }( id: Uint256, withdraws_len: felt, total_withdraw: Uint256, amount: Uint256):
    alloc_locals

    if withdraws_len == 0:
        return ()
    end

    let (withdrawer: felt) =_withdraws.read(id,withdraws_len-1)
    let (withdrawal_amount: Uint256) =_withdraw_amount.read(id,withdrawer)
    let (withdrawal_amount_mul_amount: Uint256) = uint256_checked_mul(withdrawal_amount,amount)
    let (amount_to_withdraw: Uint256, _) = uint256_unsigned_div_rem(withdrawal_amount_mul_amount,total_withdraw)
    let (underlying_token) = _underlying_token.read()


    let (is_amount_to_withdraw_less_than_zero) = uint256_le(amount_to_withdraw,Uint256(0,0))
    if is_amount_to_withdraw_less_than_zero == 0:
        IERC20.transfer(contract_address=underlying_token, recipient=withdrawer, amount=amount_to_withdraw)
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr

    end

    return _distribute_underlying(id = id, withdraws_len = withdraws_len - 1, total_withdraw = total_withdraw, amount = amount)
end









#
# Internals ERC20
#

func _mint{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(recipient: felt, amount: Uint256):
    alloc_locals
    with_attr error_message("Pair::_mint::recipient can not be zero"):
        assert_not_zero(recipient)
    end
    uint256_check(amount)

    let (balance: Uint256) = balances.read(account=recipient)
    # overflow is not possible because sum is guaranteed to be less than total supply
    # which we check for overflow below
    let (new_balance: Uint256) = uint256_checked_add(balance, amount)
    balances.write(recipient, new_balance)

    let (local supply: Uint256) = total_supply.read()
    let (local new_supply: Uint256) = uint256_checked_add(supply, amount)

    total_supply.write(new_supply)
    Mint.emit(to = recipient, amount = amount)
    return ()
end

func _burn{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(account: felt, amount: Uint256):
    alloc_locals
    with_attr error_message("Pair::_burn::account can not be zero"):
        assert_not_zero(account)
    end
    uint256_check(amount)

    let (balance: Uint256) = balances.read(account)
    # validates amount <= balance and returns 1 if true
    let (enough_balance) = uint256_le(amount, balance)
    with_attr error_message("Pair::_burn::not enough balance to burn"):
        assert_not_zero(enough_balance)
    end
    
    let (new_balance: Uint256) = uint256_checked_sub_le(balance, amount)
    balances.write(account, new_balance)

    let (supply: Uint256) = total_supply.read()
    let (new_supply: Uint256) = uint256_checked_sub_le(supply, amount)
    total_supply.write(new_supply)
    Burn.emit(account = account, amount = amount)
    return ()
end

func _transfer{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(sender: felt, recipient: felt, amount: Uint256):
    alloc_locals
    with_attr error_message("Pair::_transfer::sender can not be zero"):
        assert_not_zero(sender)
    end
    with_attr error_message("Pair::_transfer::recipient can not be zero"):
        assert_not_zero(recipient)
    end
    uint256_check(amount) # almost surely not needed, might remove after confirmation

    let (local sender_balance: Uint256) = balances.read(account=sender)

    # validates amount <= sender_balance and returns 1 if true
    let (enough_balance) = uint256_le(amount, sender_balance)
    with_attr error_message("Pair::_transfer::not enough balance for sender"):
        assert_not_zero(enough_balance)
    end

    # subtract from sender
    let (new_sender_balance: Uint256) = uint256_checked_sub_le(sender_balance, amount)
    balances.write(sender, new_sender_balance)

    # add to recipient
    let (recipient_balance: Uint256) = balances.read(account=recipient)
    # overflow is not possible because sum is guaranteed by mint to be less than total supply
    let (new_recipient_balance: Uint256) = uint256_checked_add(recipient_balance, amount)
    balances.write(recipient, new_recipient_balance)

    Transfer.emit(from_address=sender, to_address=recipient, amount=amount)
    return ()
end

func _approve{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(caller: felt, spender: felt, amount: Uint256):
    with_attr error_message("Pair::_approve::caller can not be zero"):
        assert_not_zero(caller)
    end
    with_attr error_message("Pair::_approve::spender can not be zero"):
        assert_not_zero(spender)
    end
    uint256_check(amount)
    allowances.write(caller, spender, amount)
    Approval.emit(owner=caller, spender=spender, amount=amount)
    return ()
end





#
# Internals Ownable
#

func _only_owner{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    let (owner) = _owner.read()
    let (caller) = get_caller_address()
    with_attr error_message("DefiPooling::_only_owner::Caller must be owner"):
        assert owner = caller
    end
    return ()
end



