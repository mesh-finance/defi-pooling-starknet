// @title DefiPooling for depositing in L1 protocol directly from L2
// @author Mesh Finance
// @license MIT
// @dev an ERC20 token
//      uses starkgate bridge for bridging tokens 


#[starknet::interface]
trait IERC20<T> {
    fn balance_of(self: @T, account: ContractAddress) -> u256;
    fn transfer(ref self: T, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(ref self: T, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;
}

#[starknet::interface]
trait ITokenBridge<T> {
    fn initiate_withdraw((ref self: T, l1_recipient: EthAddress, amount: u256);
}

#[starknet::interface]
trait IDefiPooling<TContractState> {
    // view functions
    fn name(self: @TContractState) -> felt252;
    fn symbol(self: @TContractState) -> felt252;
    fn total_supply(self: @TContractState) -> u256;
    fn decimals(self: @TContractState) -> u8;
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn owner(self: @TContractState) -> ContractAddress;
    fn current_deposit_id(self: @TContractState) -> u32;
    fn total_deposit_amount(self: @TContractState, depositId: u32) -> u256;
    fn deposit_amount(self: @TContractState, depositId: u32, depositor: ContractAddress) -> u256;
    fn current_withdraw_id(self: @TContractState) -> u32;
    fn total_withdaw_amount(self: @TContractState, withdrawId: u32) -> u256;
    fn withdraw_amount(self: @TContractState, withdrawId: u32, withdrawer: ContractAddress) -> u256;
    fn asset(self: @TContractState) -> ContractAddress;
    fn l1_contract_address(self: @TContractState) -> EthAddress;
    fn token_bridge(self: @TContractState) -> ContractAddress;
    fn assets_per_share(self: @TContractState) -> u256;
    fn total_assets(self: @TContractState) -> u256;
    fn assets_of(self: @TContractState, user: ContractAddress) -> u256;
    fn preview_deposit(self: @TContractState, amount: u256) -> u256;
    fn preview_mint(self: @TContractState, shares: u256) -> u256;
    fn preview_withdraw(self: @TContractState, amount: u256) -> u256;
    fn preview_redeem(self: @TContractState, shares: u256) -> u256;
    // external functions
    fn update_l1_contract(ref self: TContractState, new_l1_contract: EthAddress);
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;
    fn increase_allowance(ref self: TContractState, spender: ContractAddress, added_value: u256) -> bool;
    fn decrease_allowance(ref self: TContractState, spender: ContractAddress, subtracted_value: u256) -> bool;
    fn deposit(ref self: TContractState, amount: u256) -> u256;
    fn mint(ref self: TContractState, shares: u256) -> u256;
    fn cancel_deposit(ref self: TContractState) -> u256;
    fn deposit_assets_to_l1(ref self: TContractState) -> u32;
    fn withdraw(ref self: TContractState, amount: u256) -> u256;
    fn redeem(ref self: TContractState, shares: u256) -> u256;
    fn cancel_withdraw(ref self: TContractState) -> u256;
    fn send_withdrawal_request_to_l1(ref self: TContractState) -> u32;
}

#[starknet::contract]
mod DefiPooling {
    use DefiPooling::utils::erc20::ERC20;
    use DefiPooling::utils::ownable::Ownable;
    use option::OptionTrait;
    use array::ArrayTrait;
    use zeroable::Zeroable;
    use starknet::ContractAddress;
    use starknet::get_contract_address;
    use starknet::get_block_timestamp;
    use starknet::contract_address_const;
    use starknet::{
        ContractAddress, get_caller_address, EthAddress, EthAddressIntoFelt252, EthAddressSerde,
        EthAddressZeroable, syscalls::send_message_to_l1_syscall
    };

    use super::{
        IERC20Dispatcher, ITokenBridgeDispatcher
    };

    use integer::u128_try_from_felt252;

    //
    // Constants
    //
    const MESSAGE_WITHDRAWAL_REQUEST: felt252 = 1;
    const MESSAGE_DEPOSIT_REQUEST: felt252 = 2;
    const PRECISION: u32 = 1000000000_u32;


    //
    // Storage
    //
    struct Storage {
        _underlying_asset: ContractAddress, // @dev token address for underlying assest
        _token_bridge: ContractAddress, // @dev contract address for underlying assest starknet bridge
        _l1_contract_address: EthAddress, // @dev L1 contract address (to interact with Defi platform)
        _is_authorised: LegacyMap<ContractAddress, bool> // @dev mapping to store authorised contracts.
        _current_deposit_id: u32, // @dev current deposit ID
        _total_deposit: LegacyMap<u32, u256>, // @dev total assest deposit corresponding to deposit ID
        _depositors: Array<ContractAddress>, // @dev store all the depositor for current deposit ID //*** TODO: IS it needed ***
        _deposit_amount: LegacyMap<(u32, ContractAddress), u256> , // @dev deposit amount of user for specific deposit ID
        _shares_distributed: LegacyMap<u32, u256>, // @dev @dev mapping to store distributed shares info
        _current_withdraw_id: u32, // @dev current withdraw ID
        _total_withdraw: LegacyMap<u32, u256>, // @dev total withdraw for each withdraw call to L1
        _withdraws: Array<ContractAddress>, // @dev store all the withdraws for current withdraw ID //*** TODO: IS it needed ***
        _withdraw_amount: LegacyMap<(u32, ContractAddress), u256> , // @dev withdraw amount of user for specific deposit ID
        _assets_distributed: LegacyMap<u32, u256>, // @dev mapping to store distributed assets info
    }

    // #[event]
    // #[derive(Drop, starknet::Event)]
    // enum Event {
    //     Mint: Mint,
    //     Burn: Burn,
    //     Swap: Swap,
    //     Sync: Sync
    // }

    // // @notice An event emitted whenever mint() is called.
    // #[derive(Drop, starknet::Event)]
    // struct Mint {
    //     sender: ContractAddress, 
    //     amount0: u256, 
    //     amount1: u256
    // }


    //
    // Constructor
    //

    // @notice Contract constructor
    // @param name Name of the pair token
    // @param symbol Symbol of the pair token
    #[constructor]
    func constructor(
            ref self: ContractState, 
            // l1_contract_address: felt,
            underlying_asset: ContractAddress,
            token_bridge: ContractAddress,
            owner: ContractAddress,
        ){
        assert(underlying_asset.is_non_zero() & token_bridge.is_non_zero() & owner.is_non_zero(), 'ZERO_INPUT');
        let mut erc20_state = ERC20::unsafe_new_contract_state();
        ERC20::InternalImpl::initializer(ref erc20_state, 'mesh-USDC', 'mUSDC');
        let mut ownable_state = Ownable::unsafe_new_contract_state();
        Ownable::InternalImpl::initializer(ref ownable_state, owner);
        // _l1_contract_address.write(l1_contract_address)
        self._underlying_asset.write(underlying_asset);
        self._token_bridge.write(token_bridge);
        
        self._current_deposit_id.write(0_u32);
        _assets_per_share.write(0_u256);
        //_withdraws_len.write(Uint256(0,0),0)

    }


    #[external(v0)]
    impl DefiPooling of super::IDefiPooling<ContractState> {
        //
        // Getters ERC20
        //

        // @notice Name of the token
        // @return name
        fn name(self: @ContractState) -> felt252 {
            let erc20_state = ERC20::unsafe_new_contract_state();
            ERC20::ERC20::name(@erc20_state)
        }

        // @notice Symbol of the token
        // @return symbol
        fn symbol(self: @ContractState) -> felt252 {
            let erc20_state = ERC20::unsafe_new_contract_state();
            ERC20::ERC20::symbol(@erc20_state)
        }

        // @notice Total Supply of the token
        // @return total supply
        fn total_supply(self: @ContractState) -> u256 {
            let erc20_state = ERC20::unsafe_new_contract_state();
            ERC20::ERC20::total_supply(@erc20_state)
        }

        // @notice Decimals of the token
        // @return decimals
        fn decimals(self: @ContractState) -> u8 {
            let erc20_state = ERC20::unsafe_new_contract_state();
            ERC20::ERC20::decimals(@erc20_state)
        }

        // @notice Balance of `account`
        // @param account Account address whose balance is fetched
        // @return balance Balance of `account`
        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            let erc20_state = ERC20::unsafe_new_contract_state();
            ERC20::ERC20::balance_of(@erc20_state, account)
        }

        // @notice Allowance which `spender` can spend on behalf of `owner`
        // @param owner Account address whose tokens are spent
        // @param spender Account address which can spend the tokens
        // @return remaining
        fn allowance(self: @ContractState, owner: ContractAddress, spender: ContractAddress) -> u256 {
            let erc20_state = ERC20::unsafe_new_contract_state();
            ERC20::ERC20::allowance(@erc20_state, owner, spender)
        }

        //
        // Getters Ownable
        //

        // @notice Get contract owner address
        // @return owner
        fn owner(self: @ContractState) -> ContractAddress {
            let ownable_state = Ownable::unsafe_new_contract_state();
            Ownable::Ownable::owner(@ownable_state)
        }

        //
        // Getters Defi Pooling
        //

        // @notice Get current deposit id
        // @return id
        fn current_deposit_id(self: @ContractState) -> u32 {
            self._current_deposit_id.read()
        }

        // @notice Get total deposit amount for a deposit id
        // @param deposit_id id of which we want total deposit amount
        // @return total_deposit_amount
        fn total_deposit_amount(self: @ContractState, deposit_id: u32 ) -> u256 {
            self._total_deposit.read(deposit_id);
        }
   

        

        // // @notice Get depositor address 
        // // @param deposit_id id of which we want depositor
        // // @param index index at which we want the depositor
        // // @return depositors
        // @view
        // func depositors{
        //         syscall_ptr : felt*, 
        //         pedersen_ptr : HashBuiltin*,
        //         range_check_ptr
        //     }(deposit_id: felt, index:felt) -> (depositors: felt){
        //     let (depositors: felt) = _depositors.read(deposit_id,index);
        //     return (depositors=depositors);
        // }

        // @notice Get deposit amount of a depositor 
        // @param deposit_id id of which we want deposit amount
        // @param index depositor index of which we want amount
        // @return deposit_amount
        fn deposit_amount(self: @ContractState, deposit_id: u32, depositor: ContractAddress ) -> u256 {
            self._deposit_amount.read(deposit_id, depositor);
        }

        // @notice Get current withdraw id
        // @return id
        fn current_withdraw_id(self: @ContractState) -> u32 {
            self._current_withdraw_id.read()
        }

        // @notice Get total withdraw amount for a withdraw id
        // @param withdraw_id id of which we want total withdraw amount
        // @return total_withdraw_amount
        fn total_withdraw_amount(self: @ContractState, withdraw_id: u32 ) -> u256 {
            self._total_withdraw.read(withdraw_id);
        }

    

        // // @notice Get withdrawer address 
        // // @param withdraw_id id of which we want withdrawer
        // // @param index index at which we want the withdrawer
        // // @return withdrawer
        // @view
        // func withdraws{
        //         syscall_ptr : felt*, 
        //         pedersen_ptr : HashBuiltin*,
        //         range_check_ptr
        //     }(withdraw_id: felt, index:felt) -> (withdrawer: felt){
        //     let (withdrawer: felt) = _withdraws.read(withdraw_id,index);
        //     return (withdrawer=withdrawer);
        // }

        // @notice Get withdraw amount of a withdrawer 
        // @param withdraw_id id of which we want withdraw amount
        // @param index withdrawer index of which we want withdraw amount
        // @return withdraw_amount
        fn withdraw_amount(self: @ContractState, withdraw_id: u32, withdrawer: ContractAddress ) -> u256 {
            self._withdraw_amount.read(withdraw_id, withdrawer);
        }

        // @notice Get asset token
        // @return asset_token
        fn underlying_asset(self: @ContractState) -> ContractAddress {
            self._underlying_asset.read()
        }

        // @notice Get l1 contract address 
        // @return l1_contract_address
        fn l1_contract_address(self: @ContractState) -> EthAddress {
            self._l1_contract_address.read()
        }

        // @notice Get token bridge
        // @return token_bridge
        fn token_bridge(self: @ContractState) -> ContractAddress {
            self._token_bridge.read()
        }

        // @notice Get the authorised state of account
        // @return true if authorised else false
        fn is_authorised(self: @ContractState, account: ContractAddress) -> bool {
            self._is_authorised.read(account);
        }

        // @notice Get assets per share
        // @return assets_per_share
        fn assets_per_share(self: @ContractState) -> u256 {
            self._assets_per_share.read()
        }

        // *** TODO: Update the _total_assets function ****
        // @notice Get total asset locked
        // @return total_assets
        fn total_assets(self: @ContractState) -> u256 {
            InternalImpl::_total_assets(self)
        }
        // @view
        // func total_assets{
        //         syscall_ptr : felt*, 
        //         pedersen_ptr : HashBuiltin*,
        //         range_check_ptr
        //     }() -> (total_assets: Uint256){
        //     let (totalSupply: Uint256) = total_supply.read();
        //     let (total_assets: Uint256) = _shares_to_assets(totalSupply);
        //     return (total_assets=total_assets);
        // }

        // *** TODO: Update the _assets_of function ****
        // @notice Get total asset of a user
        // @return assets_of
        fn assets_of(self: @ContractState, account: ContractAddress) -> u256 {
            InternalImpl::_assets_of(self, account);
        }
        // @view
        // func assetsOf{
        //         syscall_ptr : felt*, 
        //         pedersen_ptr : HashBuiltin*,
        //         range_check_ptr
        //     }(account: felt) -> (assets_of: Uint256){
        //     let (balance: Uint256) = balances.read(account = account);
        //     let (assets_of: Uint256) = _shares_to_assets(balance);
        //     return (assets_of=assets_of);
        // }

        // @notice Get expected shares receieved on depositing
        // @return shares
        fn preview_deposit(self: @ContractState, amount: u256) -> u256 {
            InternalImpl::_preview_deposit(self, amount);
        }
        // @view
        // func preview_deposit{
        //         syscall_ptr : felt*, 
        //         pedersen_ptr : HashBuiltin*,
        //         range_check_ptr
        //     }(assets: Uint256) -> (shares: Uint256){
        //     let (shares: Uint256) = _assets_to_shares(assets);
        //     return (shares=shares);
        // }

        // @notice Get expected assets to mint shares
        // @return assets
        fn preview_mint(self: @ContractState, shares: u256) -> u256 {
            InternalImpl::_preview_deposit(self, shares);
        }
    

        // @notice Get expected shares to receive assets
        // @return shares
        fn preview_withdraw(self: @ContractState, amount: u256) -> u256 {
            InternalImpl::_preview_deposit(self, amount);
        }
 

        // @notice Get expected assets receieved on burning shares
        // @return assets
        fn preview_redeem(self: @ContractState, amount: u256) -> u256 {
            InternalImpl::_preview_deposit(self, amount);
        }
    

        //
        // Externals Ownable
        //

        // @notice Change ownership to `new_owner`
        // @dev Only owner can change. 
        // @param new_owner Address of new owner
        fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) -> bool {
            let mut ownable_state = Ownable::unsafe_new_contract_state();
            Ownable::Ownable::transfer_ownership(ref ownable_state, new_owner);
            true
        }


        //
        // Externals ERC20
        //

        // @notice Transfer `amount` tokens from `caller` to `recipient`
        // @param recipient Account address to which tokens are transferred
        // @param amount Amount of tokens to transfer
        // @return success 0 or 1
        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            let mut erc20_state = ERC20::unsafe_new_contract_state();
            ERC20::ERC20::transfer(ref erc20_state, recipient, amount);
            true
        }

        // @notice Transfer `amount` tokens from `sender` to `recipient`
        // @dev Checks for allowance.
        // @param sender Account address from which tokens are transferred
        // @param recipient Account address to which tokens are transferred
        // @param amount Amount of tokens to transfer
        // @return success 0 or 1
        fn transfer_from(ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool {
            let mut erc20_state = ERC20::unsafe_new_contract_state();
            ERC20::ERC20::transfer_from(ref erc20_state, sender, recipient, amount);
            true
        }

        // @notice Approve `spender` to transfer `amount` tokens on behalf of `caller`
        // @param spender The address which will spend the funds
        // @param amount The amount of tokens to be spent
        // @return success 0 or 1
        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            let mut erc20_state = ERC20::unsafe_new_contract_state();
            ERC20::ERC20::approve(ref erc20_state, spender, amount);
            true
        }

        // @notice Increase allowance of `spender` to transfer `added_value` more tokens on behalf of `caller`
        // @param spender The address which will spend the funds
        // @param added_value The increased amount of tokens to be spent
        // @return success 0 or 1
        fn increase_allowance(ref self: ContractState, spender: ContractAddress, added_value: u256) -> bool {
            let mut erc20_state = ERC20::unsafe_new_contract_state();
            ERC20::ERC20::increase_allowance(ref erc20_state, spender, added_value);
            true
        }

        // @notice Decrease allowance of `spender` to transfer `subtracted_value` less tokens on behalf of `caller`
        // @param spender The address which will spend the funds
        // @param subtracted_value The decreased amount of tokens to be spent
        // @return success 0 or 1
        fn decrease_allowance(ref self: ContractState, spender: ContractAddress, subtracted_value: u256) -> bool {
            let mut erc20_state = ERC20::unsafe_new_contract_state();
            ERC20::ERC20::decrease_allowance(ref erc20_state, spender, subtracted_value);
            true
        }


        //
        // Externals Defi Pooling
        //


        // @notice Change L1 contract address to `new_l1_contract`
        // @dev Only owner can change.
        // @param new_l1_contract Address of new L1 contract
        fn update_l1_contract(ref self: ContractState, new_l1_contract: EthAddress) -> bool {
            assert(new_l1_contract.is_non_zero(), 'ZERO_L1_ADDRESS');
            self._l1_contract_address.write(new_l1_contract);
            true
        }

        // @notice Change L1 contract address to `new_l1_contract`
        // @dev Only owner can change.
        // @param new_l1_contract Address of new L1 contract
        fn authorise(ref self: ContractState, account: ContractAddress, new_state: bool) -> bool {
            assert(_is_authorised.read(account) != new_state, 'ALREADY_SET');
            self._is_authorised.write(account, new_state);
            true
        }
    
        // @notice Deposit asset into contract, waiting to be bridged to L1
        // @dev `caller` should have already given the cotract an allowance of at least 'amount' on asset
        // @param amount The amount of token to deposit
        // @return new_total_deposit The total amount of tokens deposited for current deposit_id
        fn deposit(ref self: ContractState, amount: u256) -> u256 {
            let total_deposit = InternalImpl::_deposit(ref self, amount)
            total_deposit
        }


        // @notice Deposit asset into contract, waiting to be bridged to L1
        // @dev `caller` should have already given the cotract an allowance of at least 'amount' on asset
        // @param shares The shares to receieved on depositing
        // @return new_total_deposit The total amount of tokens deposited for current deposit_id
        fn mint(ref self: ContractState, shares: u256) -> u256 {
            let amount = InternalImpl::_preview_mint(shares);
            let total_deposit = InternalImpl::_deposit(ref self, amount)
            total_deposit
        }


        // @notice Cancel deposit to withdraw back your asset
        // @dev `caller` should have to call before the tokens are bridged to L1
        // @return new_total_deposit The total amount of tokens deposited for current deposit_id
        fn cancel_deposit(ref self: ContractState) -> u256 {
            let caller_address = get_caller_address();
            let deposit_id = self._current_deposit_id.read();
            let deposited_amount = self._deposit_amount.read(id, caller_address)

            assert(deposited_amount.is_non_zero(), 'NO_DEPOSIT_REQUEST_FOUND');

            self._deposit_amount.write((deposit_id, caller_address), 0_u256);
            let underlying_asset = self._underlying_asset.read();
            let underlying_asset_dispatcher = IERC20Dispatcher { contract_address: underlying_asset };
            underlying_asset_dispatcher.transfer(caller_address, deposited_amount);

            let old_total_deposit = self._total_deposit.read(deposit_id);
            let new_total_deposit = old_total_deposit - deposited_amount
            self._total_deposit.write(new_total_deposit);
            new_total_deposit
            
        }



        // @notice Bridge asset to L1 for current deposit_id
        // @dev only authorised contract/user can call this
        // @return new_deposit_id the new current deposit id
        fn deposit_assets_to_l1(ref self: ContractState) -> u32 {
            //TODO: TO DECIDE IF ITS ONLY AUTHORISED OR ANYONE CAN CALL
            assert(_is_authorised.read(get_caller_address), 'AUTHORISED_ONLY');
            let deposit_id = self._current_deposit_id.read();
            let amount_to_bridge = self._total_deposit.read(deposit_id);

            // bridging underlying asset token to L1
            let bridge = self._token_bridge.read();
            let l1_contract_address = self._l1_contract_address.read();

            let bridgeDispatcher = ITokenBridgeDispatcher{contract_address: bridge};
            ITokenBridgeDispatcher.initiate_withdraw(l1_contract_address, amount_to_bridge);

            // Send the message.
            let mut message_payload: Array<felt252> = array![
                MESSAGE_DEPOSIT_REQUEST, deposit_id.into(), amount_to_bridge.low.into(), amount_to_bridge.high.into()
            ];
            send_message_to_l1_syscall(
                to_address: l1_contract_address, payload: message_payload.span()
            );

            self._current_deposit_id.write(deposit_id + 1);
            deposit_id + 1
        }


        // @notice Withdraw asset from contract, waiting to be bridged back to L2
        // @dev `caller` should have Shares to withdraw
        // @param assets The expected assets to receive on withdrawing
        // @return new_total_withdraw The total amount of tokens withdraw request for current withdraw_id
        fn withdraw(ref self: ContractState, amount: u256) -> u256 {
            let shares = InternalImpl::_preview_withdraw(amount);
            let total_withdraw = InternalImpl::_withdraw(ref self, shares)
            total_withdraw
        }

        // @notice Redeem asset from contract, waiting to be bridged back to L2
        // @dev `caller` should have Shares to withdraw
        // @param shares The shares to redeem assets
        // @return new_total_withdraw The total amount of tokens withdraw request for current withdraw_id
        fn redeem(ref self: ContractState, shares: u256) -> u256 {
            let total_withdraw = InternalImpl::_withdraw(ref self, shares)
            total_withdraw
        }


        // @notice Cancel withdraw request
        // @dev `caller` should have to call before the tokens are bridged back from L1
        // @return new_total_withdraw The total amount of tokens wihdraw request for current withdraw_id
        fn cancel_deposit(ref self: ContractState) -> u256 {
            let caller_address = get_caller_address();
            let withdraw_id = self._current_withdraw_id.read();
            let withdrawal_amount = self._withdraw_amount.read(withdraw_id, caller_address)

            assert(withdrawal_amount.is_non_zero(), 'NO_WITHDRAW_REQUEST_FOUND');

            self._withdraw_amount.write((withdraw_id, caller_address), 0_u256);
            InternalImpl::_mint(ref self, caller_address, withdrawal_amount)

            let old_total_withdraw = self._total_withdraw.read(deposit_id);
            let new_total_withdraw = old_total_withdraw - withdrawal_amount
            self._total_withdraw.write(new_total_withdraw);
            new_total_withdraw
        }

    

        // @notice Send withdraw request to L1 for current withdraw_id
        // @dev only owner can call this
        // @return new_withdraw_id the new current withdraw id
        fn send_withdrawal_request_to_l1(ref self: ContractState) -> u32 {
            //TODO: TO DECIDE IF ITS ONLY AUTHORISED OR ANYONE CAN CALL
            assert(_is_authorised.read(get_caller_address), 'AUTHORISED_ONLY');
            let withdraw_id = self._current_withdraw_id.read();
            let amount_to_withdraw = self._total_withdraw.read(withdraw_id);
            let l1_contract_address = self._l1_contract_address.read();

            // Send the message.
            let mut message_payload: Array<felt252> = array![
                MESSAGE_WITHDRAWAL_REQUEST, withdraw_id.into(), amount_to_withdraw.low.into(), amount_to_withdraw.high.into()
            ];
            send_message_to_l1_syscall(
                to_address: l1_contract_address, payload: message_payload.span()
            );

            self._current_withdrawt_id.write(withdraw_id + 1);
            withdraw_id + 1
        }

        #[l1_handler]
        fn handle_distribute_asset( ref self: ContractState, from_address: felt252, id: u32, amount: u256) {
            let assets_distributed = self._assets_distributed.read(id);
            assert(assets_distributed.is_zero(), 'ALREADY_PROCESSED');
            let l1_contract_address = self._l1_contract_address.read();

            // Make sure the message was sent by the intended L1 contract.
            assert(from_address == l1_contract_address, 'INCORRECT_FROM_ADDRESS');

            let total_withdraw_shares = self._total_withdraw.read(id);
            self._assets_distributed.write(id, amount);
            let amount_mul_PRECISION = amount * PRECISION;

            let new_assets_per_share = assets_mul_PRECISION / total_withdaw_shares;
            self._assets_per_share.write(new_assets_per_share);
            InternalImpl::_distribute_asset(id, total_withdaw_shares, amount);
        }

        #[l1_handler]
        fn handle_distribute_share( ref self: ContractState, from_address: felt252, id: u32, shares: u256) {   
            let shares_distributed = self._shares_distributed.read(id);
            assert(shares_distributed.is_zero(), 'ALREADY_PROCESSED');

            let l1_contract_address = self._l1_contract_address.read();

            // Make sure the message was sent by the intended L1 contract.
            assert(from_address == l1_contract_address, 'INCORRECT_FROM_ADDRESS');

            let total_deposit_amount = self._total_deposit.read(id);
            self._shares_distributed.write(id, shares);
            let total_deposit_amount_mul_PRECISION = total_deposit_amount * PRECISION;

            let new_assets_per_share = total_deposit_amount_mul_PRECISION / shares;
            self._assets_per_share.write(new_assets_per_share);
            InternalImpl::_distribute_share(id, total_deposit_amount, shares);
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {

        // 
        // Internal Defi Pooling
        // 
        fn _deposit(ref self: ContractState, amount: u256) -> u256 {
            let caller_address = get_caller_address();
            let contract_address = get_contract_address();
            let underlying_asset = self._underlying_asset.read();

            let tokenDispatcher = IERC20Dispatcher { contract_address: underlying_asset };
            tokenDispatcher.transfer_from(caller_address, contract_address, amount);

            let id = self._current_deposit_id.read();

            let deposited_amount = self._deposit_amount.read(id, caller_address);
            if (deposited_amount == 0_u256) {
                // TODO: append to deposit array
            }

            let new_deposited_amount = deposited_amount + amount;
            self._deposit_amount.write((id, caller_address), new_deposited_amount);

            let previous_total_deposit = self._total_deposit.read(id);
            let new_total_deposit = previous_total_deposit + amount;
            self._total_deposit.write(id, new_total_deposit);
            new_total_deposit
        }


        fn _withdraw(ref self: ContractState, shares: u256) -> u256 {
            let caller_address = get_caller_address();
            let contract_address = get_contract_address();

            let mut erc20_state = ERC20::unsafe_new_contract_state();

            ERC20::InternalImpl::_burn(ref erc20_state, caller_address, shares);

            let id = self._current_withdraw_id.read();

            let withdrawal_shares = self._withdraw_amount.read(id, caller_address);
            if (withdrawal_shares == 0_u256) {
                // TODO: append to withdraw array
            }

            let new_withdrawal_shares = withdrawal_shares + shares;
            self._withdraw_amount.write((id, caller_address), new_withdrawal_shares);

            let previous_total_withdraw = self._total_withdraw.read(id);
            let new_total_withdraw = previous_total_withdraw + shares;
            self._total_withdraw.write(id, new_total_withdraw);
            new_total_withdraw

        }



        fn _distribute_share(ref self: ContractState, id: u32, total_deposit: u256, shares: u256) {
            let depositors_len: usize = self._depositors.len();
            let mut i: usize = 0;
            loop {
                if i >= depositors_len {
                    break;
                }
                let depositor: ContractAddress = self._depositors.at(i);
                let deposited_amount = self._deposit_amount.read(id, depositor);
                let amount_to_mint: u256 = (deposited_amount * shares) / total_deposit;

                if amount_to_mint > 0 {
                    let mut erc20_state = ERC20::unsafe_new_contract_state();
                    ERC20::InternalImpl::_mint(ref erc20_state, depositor, amount_to_mint);

                }

            }
        }


        fn _distribute_asset(ref self: ContractState, id: u32, total_withdraw: u256, amount: u256) {
            let withdrawers_len: usize = self._withdrawers.len();
            let mut i: usize = 0;
            loop {
                if i >= withdrawers_len {
                    break;
                }
                let withdrawer: ContractAddress = self._withdrawers.at(i);
                let withdrawn_shares = self._withdraw_amount.read(id, withdrawer);
                let amount_to_withdraw: u256 = (withdrawn_shares * amount) / total_withdraw;
                let underlying_asset = self._underlying_asset.read();

                if amount_to_withdraw > 0 {
                    let tokenDispatcher = IERC20Dispatcher { contract_address: underlying_asset };
                    tokenDispatcher.transfer(withdrawer, amount_to_withdraw);

                }

            }
        }


        fn _assets_to_shares(ref self: ContractState, amount: u256) -> u256 {
            let assets_per_share: u256 = self._assets_per_share.read();
            if assets_per_share == 0_u256 {
                assets_per_share
            }
            let amount_mul_PRECISION = amount * PRECISION;
            let shares = amount_mul_PRECISION / assets_per_share;
            shares
        }

    
        fn _shares_to_assets(ref self: ContractState, shares: u256) -> u256 {
            let assets_per_share: u256 = self._assets_per_share.read();
            
            let amount = (shares * assets_per_share) / PRECISION;
            amount
        }

   }
}

    




