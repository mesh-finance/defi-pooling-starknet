# Defi Pooling Starknet

## Testing and Development

We use [Protostar](https://docs.swmansion.com/protostar/) for our testing and development purposes. 
Protostar is a StarkNet smart contract development toolchain, which helps you with dependencies management, compiling and testing cairo contracts.
### Install Protostar


1. Copy and run in a terminal the following command to install protostar 0.3.1:
```
curl -L https://raw.githubusercontent.com/software-mansion/protostar/master/install.sh | bash -s -- -v 0.3.1
```
2. Restart the terminal.
3. Run `protostar -v` to check Protostar and cairo-lang version.

#### Note 
Protostar requires version 2.28 or greater of Git.


### Install Protostar Dependencies

```
protostar install
```

### Compile Contracts
```
protostar build
```

### Run Tests
```
protostar test
```

#### Note 
It is not possible to call @l1_handler using Cairo from protostar. To run tests locally, must change @l1_handler to @external in DefiPooling.cairo

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
