%lang starknet


from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.starknet.common.syscalls import get_caller_address, deploy, get_contract_address
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

    func balanceOf(account: felt) -> (balance: Uint256):
    end

end

@contract_interface
namespace IDefiPooling:

    func owner() -> (owner: felt):
    end

    func asset() -> (asset: felt):
    end

    func l1_contract_address() -> (l1_contract_address: felt):
    end

    func token_bridge() -> (token_bridge: felt):
    end
end

@external
func test_deployment{syscall_ptr: felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    alloc_locals

    local deployer_signer = 1
    local deployer_address
    local token_0_address
    local token_bridge_address
    local contract_address

    %{
        context.deployer_signer = ids.deployer_signer
        context.deployer_address = deploy_contract("./contracts/test/Account.cairo", [context.deployer_signer]).contract_address
        context.token_0_address = deploy_contract("lib/cairo_contracts/src/openzeppelin/token/erc20/presets/ERC20Mintable.cairo", [11, 1, 18, 0, 0, context.deployer_address, context.deployer_address]).contract_address
        context.token_bridge_address = deploy_contract("./contracts/token_bridge.cairo", [context.deployer_address]).contract_address
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

    let (token_name) = IERC20.name(contract_address=contract_address)
    assert token_name = 1111

    let (token_symbol) = IERC20.symbol(contract_address=contract_address)
    assert token_symbol = 1010

    let (decimals) = IERC20.decimals(contract_address=contract_address)
    assert decimals = 18

    let (owner) = IDefiPooling.owner(contract_address=contract_address)
    assert owner = deployer_address

    let (token_0) = IDefiPooling.asset(contract_address=contract_address)
    assert token_0 = token_0_address
    
    let (token_bridge) = IDefiPooling.token_bridge(contract_address=contract_address)
    assert token_bridge = token_bridge_address
    
    return ()
end

