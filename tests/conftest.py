import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from utils.Signer import Signer


token_name_string = "Jedi Interest bearing USDC"
token_symbol_string = "jUSDC"

def uint(a):
    return(a, 0)

def str_to_felt(text):
    b_text = bytes(text, 'UTF-8')
    return int.from_bytes(b_text, "big")



@pytest.fixture
def event_loop():
    return asyncio.new_event_loop()

@pytest.fixture
async def starknet():
    starknet = await Starknet.empty()
    return starknet

@pytest.fixture
async def deployer(starknet):
    deployer_signer = Signer(123456789987654321)
    deployer_account = await starknet.deploy(
        "contracts/test/Account.cairo",
        constructor_calldata=[deployer_signer.public_key]
    )

    return deployer_signer, deployer_account

@pytest.fixture
async def random_acc(starknet):
    random_signer = Signer(987654320023456789)
    random_account = await starknet.deploy(
        "contracts/test/Account.cairo",
        constructor_calldata=[random_signer.public_key]
    )

    return random_signer, random_account

@pytest.fixture
async def user_1(starknet):
    user_1_signer = Signer(987654321123456789)
    user_1_account = await starknet.deploy(
        "contracts/test/Account.cairo",
        constructor_calldata=[user_1_signer.public_key]
    )

    return user_1_signer, user_1_account

@pytest.fixture
async def user_2(starknet):
    user_2_signer = Signer(987654331133456789)
    user_2_account = await starknet.deploy(
        "contracts/test/Account.cairo",
        constructor_calldata=[user_2_signer.public_key]
    )

    return user_2_signer, user_2_account

@pytest.fixture
async def user_3(starknet):
    user_3_signer = Signer(987654331133456521)
    user_3_account = await starknet.deploy(
        "contracts/test/Account.cairo",
        constructor_calldata=[user_3_signer.public_key]
    )

    return user_3_signer, user_3_account

@pytest.fixture
async def token_bridge(starknet, deployer):
    deployer_signer, deployer_account = deployer
    token_bridge = await starknet.deploy("contracts/token_bridge.cairo", constructor_calldata=[
            deployer_account.contract_address
        ])
        
    

    return token_bridge


@pytest.fixture
async def token_0(starknet, random_acc,token_bridge, deployer,l1_bridge_contract):
    random_signer, random_account = random_acc
    deployer_signer, deployer_account = deployer

    token_0 = await starknet.deploy(
        "contracts/test/token/ERC20.cairo",
        constructor_calldata=[
            str_to_felt("Token 0"),  # name
            str_to_felt("TOKEN0"),  # symbol
            18,                     # decimals
            random_account.contract_address,
            token_bridge.contract_address
        ]
    )
    
    await deployer_signer.send_transaction(deployer_account, token_bridge.contract_address, 'set_l2_token', [token_0.contract_address])
    await deployer_signer.send_transaction(deployer_account, token_bridge.contract_address, 'set_l1_bridge', [l1_bridge_contract])

    return token_0

@pytest.fixture
async def token_1(starknet, random_acc,token_bridge):
    random_signer, random_account = random_acc
    token_1 = await starknet.deploy(
        "contracts/test/token/ERC20.cairo",
        constructor_calldata=[
            str_to_felt("Token 1"),  # name
            str_to_felt("TOKEN1"),  # symbol
            6,                     # decimals
            random_account.contract_address,
            token_bridge.contract_address
        ]
    )
    return token_1


@pytest.fixture
async def token_name():
    return str_to_felt(token_name_string)

@pytest.fixture
async def token_symbol():
    return str_to_felt(token_name_string)

# @pytest.fixture
# async def l1_contract():
#     return str_to_felt('0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48')

# @pytest.fixture
# async def l1_bridge_contract():
#     return str_to_felt('0xdAC17F958D2ee523a2206206994597C13D831ec7')

@pytest.fixture
async def l1_contract():
    return str_to_felt('123456789')

@pytest.fixture
async def l1_bridge_contract():
    return str_to_felt('987654321')

# @pytest.fixture
# async def registry(starknet, deployer):
#     deployer_signer, deployer_account = deployer
#     registry = await starknet.deploy("contracts/Registry.cairo", constructor_calldata=[
#             deployer_account.contract_address
#         ])
#     return registry


@pytest.fixture
async def defiPooling(starknet,token_0,token_name,token_symbol,l1_contract,deployer,token_bridge):
    deployer_signer, deployer_account = deployer
    defiPooling = await starknet.deploy(
        "contracts/DefiPooling.cairo",
        constructor_calldata=[
            token_name,
            token_symbol,
            l1_contract,
            token_0.contract_address,
            token_bridge.contract_address,
            deployer_account.contract_address
        ]
    )
    return defiPooling

