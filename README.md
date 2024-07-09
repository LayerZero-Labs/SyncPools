# SyncPools

A `Sync Pool` is an OApp that allows users to deposit tokens on multiple Layer 2s, and then sync them all to Layer 1 - all using the LayerZero messaging protocol.

- [SyncPools](#syncpools)
- [Usage](#usage)
  - [Build \& Test](#build--test)
- [Terminology](#terminology)
  - [Anticipated deposits](#anticipated-deposits)
  - [Actual deposits](#actual-deposits)
  - [Batched syncs](#batched-syncs)
  - [Lock box](#lock-box)
  - [Fast Messages](#fast-messages)
  - [Fast L1 Updating / Syncing](#fast-l1-updating--syncing)
- [Contracts Structure](#contracts-structure)
  - [`L2SyncPool`](#l2syncpool)
  - [`L1SyncPool`](#l1syncpool)
  - [`L1Receiver`](#l1receiver)
  - [`L2ExchangeRateProvider`](#l2exchangerateprovider)
- [Setup](#setup)
    - [Deployments on L1 chain](#deployments-on-l1-chain)
    - [Deployments on L2 chains](#deployments-on-l2-chains)
    - [Initialization](#initialization)
- [Example User Flow](#example-user-flow)
    - [Deposit](#deposit)
    - [Sync](#sync)


# Usage

Clone the repository and run the following to get the contracts compiled and running in your machine

## Build & Test
Requires [foundry](https://book.getfoundry.sh/getting-started/installation)
```bash
yarn; yarn build; yarn test
```

# Terminology

## Anticipated deposits

A user can deposit _`N`_ ETH on L2, the L2 sync pool will send a fast message to the L1 sync pool anticipating the actual _`N`_ ETH deposit (as it takes ~7 days to finalize the deposit), and finalize the deposit when the _`N`_ ETH is actually received from the L2. The internal function `_anticipatedDeposit` mints the dummy tokens and deposits them to the L1 deposit pool.

## Actual deposits

Deposits are finalized after the challenge period (usually ~7 days) has ended. The internal function `_finalizeDeposit` swaps the dummy token for the actual ETH.

## Batched syncs

Any interactions with mainnet occur in batches, this is a core feature as it allows for _low-cost_ L2 minting where no high L1 gas fee needs to be incurred on every mint. Both the fast sync and the actual ETH bridged are batched to save gas.

## Lock box

Lockbox is basically just the [OFTAdapter](https://github.com/LayerZero-Labs/LayerZero-v2/blob/main/oapp/contracts/oft/OFTAdapter.sol), the contract that will contain the outstanding OFT supply on the source (or main) chain.

## Fast Messages

Fast messages are used to anticipate the deposit, and slow messages are used to finalize the deposit. A user can deposit _`N`_ ETH on L2, the L2 sync pool will send a fast message to the L1 sync pool anticipating the actual _`N`_ ETH deposit (as it takes ~7 days to finalize the deposit), and finalize the deposit when the _`N`_ ETH is actually received from the L2.

## Fast L1 Updating / Syncing

The L1 update occurs through the LayerZero bridge allowing for the L1 deposit pool to quickly realize that there is more outstanding supply. Typically this would be on a (say) daily sync schedule.

# Contracts Structure

> [!TIP]
> The [`examples/`](/contracts/examples/) directory has an example implementation of all of the contracts for Ethereum L1 and Linea and Mode L2.

## `L2SyncPool`

This contract is deployed on each supported L2 for each token type. This contract acts as the entrypoint for the user. Users deposit ETH into this contract for it to mint the LST on the L2 (using `mint` on the actual LST token). It will periodically forward all ETH over the native bridge, alongside with sending a message to the `L1SyncPool` using LayerZero, notifying it of the supply adjustment in a much more rapid manner.

## `L1SyncPool`

This contract takes care of the actual syncing process, it receives different messages from L2s and handles the **anticipated** and the **actual** deposits.

The `L2SyncPool` periodically calls `L1SyncPool` to forward all ETH over the native bridge along with a message notifying adjustment of supply in a rapid manner. The supply is instantly adjusted and approximately 7 days later the dummy deposit in the deposit pool is replaced with the actual ETH received.

## `L1Receiver`

Developed and deployed for every native bridge type (Arbitrum, Optimism...). Its only responsibility is to receive messages from the native L2 bridge, decode it and forward it to the `L1SyncPool`, along with the sync metadata.

## `L2ExchangeRateProvider`

The `L2SyncPool` needs to know the current exchange rate between ETH and the LST to operate. It configures an external oracle contract (the `L2ExchangeRateProvider`) to provide this data. Typically this would be a call a simple LayerZero OApp that periodically receives the exchange rate from this contract.

# Setup

Say the setup of chains is such that we have 1 L1 chain (*`A`*) and two L2 chains (*`<X>`* and *`<Y>`*).
> [!TIP]
> The [`examples/`](/contracts/examples/) directory has an example implementation of all of the contracts for Ethereum L1 and **Linea** and **Mode** L2. The [L1Deploy.sol](/script/L1/L1Deploy.sol) and [LineaDeploy.sol](/script/L2/LineaDeploy.sol) and [ModeDeploy.sol](/script/L2/ModeDeploy.sol) script goes through the entire deployment flow for L1 and L2.


### Deployments on L1 chain
- `L1SyncPool`
- Receiver contracts for both X and Y - `L1<X>ReceiverETH` & `L1<Y>ReceiverETH`
- Dummy token contracts for both X and Y - `DummyToken` (is a dependency for the Receiver contracts)

### Deployments on L2 chains
- `L2ExchangeRateProvider` (requires admin)
- `L2SyncPool` (requires admin, see example initialization parameters [here](https://github.com/LayerZero-Labs/SyncPools/blob/5ef225b435f3df56f2255b034fe251c27e765d7f/test/Playground.t.sol#L183-L191))

### Initialization
> [!NOTE]
> Code snippets in the following pointers are from [`Playground.t.sol`](/test/Playground.t.sol) test file
- `L1SyncPool` must have minter role for DummyToken
- Setup the Vault (or Lockbox) - example implementation for a Vault can be found in [`examples/mock/L1VaultEth.sol`](/contracts/examples/mock/L1VaultETH.sol)
- Set dummy token in `L1SyncPool` contract as the address of the deployed DummyToken - has to be set for each `EID` (EID is the [EndpointId](https://docs.layerzero.network/v2/developers/evm/technical-reference/endpoints))
    ```solidity
    L1SyncPoolETH(ethereum.syncPool).setDummyToken(MODE.originEid, ethereum.dummyETHs[CHAINS.MODE]);

    L1SyncPoolETH(ethereum.syncPool).setDummyToken(LINEA.originEid, ethereum.dummyETHs[CHAINS.LINEA]);
    ```
- Set receiver for both `X` and `Y` L2s
    ```solidity
    L1SyncPoolETH(ethereum.syncPool).setReceiver(MODE.originEid, ethereum.receivers[CHAINS.MODE]);

    L1SyncPoolETH(ethereum.syncPool).setReceiver(LINEA.originEid, ethereum.receivers[CHAINS.LINEA]);
    ```
- Set `L2SyncPool` on both L2s as `peers` on `L1SyncPool`
    ```solidity
    L1SyncPoolETH(ethereum.syncPool).setPeer(MODE.originEid, bytes32(uint256(uint160(mode.syncPool))));

    L1SyncPoolETH(ethereum.syncPool).setPeer(LINEA.originEid, bytes32(uint256(uint160(linea.syncPool))));
    ```
    Read more about setting peers [here](https://docs.layerzero.network/v2/developers/evm/oft/quickstart#setting-trusted-peers)
- Configure OApp parameters to complete OApp setup of L2SyncPool
  - call `setEnforcedOptions` on `L2SyncPool`. Read more about setting enforced options [here](https://docs.layerzero.network/v2/developers/evm/oapp/overview#optional-enforced-options)
  - call `setConfig` on L2's LayerZero Endpoint. Read more about setting config [here](https://docs.layerzero.network/v2/developers/evm/configuration/configure-dvns#call-setconfig-on-the-send-and-receive-lib)
  - Example setup can be found [here](https://github.com/LayerZero-Labs/SyncPools/blob/5ef225b435f3df56f2255b034fe251c27e765d7f/test/Playground.t.sol#L651-L683)


# Example User Flow

### Deposit

- Say user _**`A`**_ is interacting with L2 chain _**`X`**_ and holds the native ETH for _**`X`**_
- The expected amount is queried from `L2ExchangeRateProvider` for some specific amount of ETH
- The [`.deposit()`](https://github.com/LayerZero-Labs/SyncPools/blob/5ef225b435f3df56f2255b034fe251c27e765d7f/contracts/L2/L2BaseSyncPoolUpgradeable.sol#L194-L238) function is called on `L2<X>SyncPoolETH.sol`
  - The `.deposit()` function mints the `tokenOut` to _**`A`**_ (LST) <!-- ques: Is it correct to say the `tokenOut` is LST?? -->

### Sync
- `.sync()` - a public payable function called to sync tokens to Layer 1. Sends a LayerZero Message to L1SyncPool contract.
>[!IMPORTANT]
> It is very important to listen for the `Sync` event to know when and how much tokens were synced especially if an action is required on another chain (for example, executing the message). If an action was required but was not executed, the tokens won't be sent to the L1.
> ```solidity
> emit Sync(dstEid, tokenIn, unsyncedAmountIn, unsyncedAmountOut);
> ```
- `.lzReceive` on L1SyncPool is called
  - increments the vault's (or lockbox) assets by the deposited amount
  - **Anticipates a deposit**: executes [`_anticipatedDeposit`](https://github.com/LayerZero-Labs/SyncPools/blob/5ef225b435f3df56f2255b034fe251c27e765d7f/contracts/examples/L1/L1SyncPoolETH.sol#L108) - Will mint the dummy tokens and deposit them to the L1 deposit pool
  - calls [`_handleAnticipatedDeposit`](https://github.com/LayerZero-Labs/SyncPools/blob/5ef225b435f3df56f2255b034fe251c27e765d7f/contracts/L1/L1BaseSyncPoolUpgradeable.sol#L266) - Internal function to handle an anticipated deposit.
    - Will emit an InsufficientDeposit event if the actual amount out is less than the expected amount out.
    - Will emit a Fee event if the actual amount out is equal or greater than the expected amount out.
    - The fee kept in this contract will be used to back any future insufficient deposits.
    - When the fee is used, the total unbacked tokens will be lower than the actual missing amount
>[!IMPORTANT]
> Any time the `InsufficientDeposit` event is emitted, necessary actions should be taken to back the lock box (such as using POL, increasing the deposit fee on the faulty L2, etc.)

