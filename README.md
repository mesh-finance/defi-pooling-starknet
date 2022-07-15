# Defi Pooling Starknet

## How to deploy
1) python3 scripts/deploy.js
2) update defiPooling_address in scripts/config/testnet.py
3) update L1 defiPooling address in scripts/setL1Contract.py
4) python3 scripts/setL1Contract.py


## Bridging assests to L1
1) let user deposit usdc into contract.
2) python3 scripts/depositAssetToL1.py 


## sending withdrawl requesst to L1
1) lets users call withdraw function
3) python3 scripts/sendWithdrawalRequestToL1.py 