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
- [Example User Flow](#example-user-flow)


# Usage
Clone the repository and run the following to get the contracts compiled and running in your machine

## Build & Test
```shell
$ yarn build
```

```shell
$ yarn test
```

# Terminology
## Anticipated deposits
A user can deposit _`N`_ ETH on L2, the L2 sync pool will send a fast message to the L1 sync pool anticipating the actual _`N`_ ETH deposit (as it takes ~7 days to finalize the deposit), and finalize the deposit when the _`N`_ ETH is actually received from the L2. The internal function `_anticipatedDeposit` mints the dummy tokens and deposits them to the L1 deposit pool.

## Actual deposits
Deposits are finalized after the challenge period (usually ~7 days) has ended. The internal function `_finalizeDeposit` swaps the dummy token for the actual ETH.

## Batched syncs
Any interactions with mainnet occur in batches, this is a core feature as it allows for _low-cost_ L2 minting where no high L1 gas fee needs to be incurred on every mint. Both the fast sync and the actual ETH bridged are batched to save gas.

## Lock box
A Lockbox is a mechanism used to manage and secure the ETH deposited by the users for staking. The L1 sync pool is responsible for managing the lock box making sure it is backed by the correct amount of tokens. 

## Fast Messages
Fast messages are used to anticipate the deposit, and slow messages are used to finalize the deposit. A user can deposit _`N`_ ETH on L2, the L2 sync pool will send a fast message to the L1 sync pool anticipating the actual _`N`_ ETH deposit (as it takes ~7 days to finalize the deposit), and finalize the deposit when the _`N`_ ETH is actually received from the L2.

## Fast L1 Updating / Syncing
The L1 update occurs through the LayerZero bridge allowing for the L1 deposit pool to quickly realize that there is more outstanding supply. Typically this would be on a (say) daily sync schedule.

# Contracts Structure

## `L2SyncPool`
This contract is deployed on each supported L2 for each token type. This contract acts as the entrypoint for the user. Users deposit ETH into this contract for it to mint the LST on the L2 (using `mint` on the actual LST token). It will periodically forward all ETH over the native bridge, alongside with sending a message to the `L1SyncPool` using LayerZero, notifying it of the supply adjustment in a much more rapid manner.

## `L1SyncPool`
This contract takes care of the actual syncing process, it receives different messages from L2s and handles the **anticipated** and the **actual** deposits.

The `L2SyncPool` periodically calls `L1SyncPool` to forward all ETH over the native bridge along with a message notifying adjustment of supply in a rapid manner. The supply is instantly adjusted and approximately 7 days later the dummy deposit in the deposit pool is replaced with the actual ETH received.

## `L1Receiver`
Developed and deployed for every native bridge type (Arbitrum, Optimism...). Its only responsibility is to receive messages from the native L2 bridge, decode it and forward it to the `L1SyncPool`, along with the sync metadata.

## `L2ExchangeRateProvider`
The `L2SyncPool` needs to know the current exchange rate between ETH and the LST to operate. It configures an external oracle contract (the `L2ExchangeRateProvider`) to provide this data. Typically this would be a call a simple LayerZero OApp that periodically receives the exchange rate from this contract.


# Example User Flow

// todo: add steps and contract interactions a user would go thru + functions snippets
