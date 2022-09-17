# Defi Pooling Starknet

## Setup Testing
0. Clone repo
1. Download protostar 0.3.1
2. Check your .git/modules folder in the repo's source directory. If there are any modules there from your previous tries remove them using rm -rf. 
3. Remove any existing .gitmodules file as well. rm .gitmodules
4. Run protostar install https://github.com/OpenZeppelin/cairo-contracts --name cairo_contracts. Ensure you download OpenZeppelin 0.3.0
5. Check your lib directory and ensure you have got a new cairo_contracts folder there.

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
