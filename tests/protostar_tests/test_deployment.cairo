%lang starknet


from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.starknet.common.syscalls import get_caller_address, deploy, get_contract_address
from starkware.cairo.common.uint256 import Uint256
from tests.protostar_tests.interfaces import IDefiPooling, ITokenBridge, IERC20

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

