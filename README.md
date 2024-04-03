## L2SyncMint

The `L2SyncMint` framework allows for easily adding native minting on L2 chains.

It's particularly useful because:

- Batched syncs: Any interactions with mainnet occur in batches, this is a core feature as it allows for _low-cost_ L2 minting where no high L1 gas fee needs to be incurred on every mint. Both the fast sync and the actual ETH bridged are batched to save gas.
- Fast L1 updating: The L1 update occurs through the LayerZero bridge allowing for the L1 deposit pool to quickly realize that there is more outstanding supply. Typically this would be on eg. a daily sync schedule.
- Cost-efficient native ETH bridging: The actual ETH is however transferred over the native L2 bridge, significantly reducing cost (only gas cost) and of course increasing security compared to third party asset bridge solutions.

### Structure

`L2SyncPool`: Extended with the specific L2 bridge details for every L2 type. The entrypoint for the user: Users can deposit ETH into this contract for it to mint the LST on the L2 (using `mint` on the actual LST token). It will periodically forward all ETH over the native bridge, alongside with sending a message to the `L1SyncPool` using LayerZero, notifying it of the supply adjustment in a much more rapid manner.

`L1SyncPool`: The system is divided in an `L1SyncPool` which primary responsibility is first notifying the LST deposit pool of incoming mints and subsequently (normally 7 days later), exchanging the dummy deposit in the deposit pool with the actual ETH received.

`L1Receiver`: Developed and deployed for every native bridge type (Arbitrum, Optimism...). Its only responsibility is receiving ETH from the L2 bridge and forwarding it to the SyncPool, alongside with the sync metadata.

`L2ExchangeRateProvider`: The `L2SyncPool` needs to know the current exchange rate between ETH and the LST to operate. It configures an external oracle contract (the `L2ExchangeRateProvider`) to provide this data. Typically this would be or call a simple LayerZero OAPP that periodically receives the exchange rate from L1.

### Build

```shell
$ yarn build
```

### Test

```shell
$ yarn test
```
