# SunStake Contracts

This repository contains the source code for all smart contracts that make up the SunStake ecosystem.

## Contract Addesses

Whenever a new contract is deployed to Tron mainnet, this section will be updated with the corresponding contract addresses.

Contracts deployed to mainnet to date:

| Contract Name      | Address                                                                                                  |
| ------------------ | -------------------------------------------------------------------------------------------------------- |
| SskToken           | [TW1sqqq7UphAqGNHDXSLXsEainYHJuQeyC](https://tronscan.org/#/contract/TW1sqqq7UphAqGNHDXSLXsEainYHJuQeyC) |
| AirdropHubV1       | [TDgmBwBf7iFkj53dyK35U6U2Y4dsGXzj4T](https://tronscan.org/#/contract/TDgmBwBf7iFkj53dyK35U6U2Y4dsGXzj4T) |
| Airdrop (Oct 2020) | [TByD11U6FbzvTjxVRW5kjVZSuhKtPBfEor](https://tronscan.org/#/contract/TByD11U6FbzvTjxVRW5kjVZSuhKtPBfEor) |

## Building

To build the contracts, first install the dependencies needed for compilation:

    $ yarn install

Then run:

    $ yarn build

Built artifacts will be available in the `./build` directory.

Note that you must have [Docker](https://www.docker.com/) installed for the build command to work.

### Building for Tron

The command above compiles the contracts for the Ethereum blockchain. Since [Waffle](https://getwaffle.io/) was built around Ethereum, building the contracts for Tron requires some local hacks.

If this is the first time you compile this repository for Tron, run the following commands first:

    $ docker pull sunstake/solc-tron:0.5.12
    $ docker tag sunstake/solc-tron:0.5.12 ethereum/solc:0.5.12-tron

This essentially tricks waffle into thinking the Tron Solidity compiler is a legit Ethereum compiler.

Now you can run this:

    $ yarn build-tron
