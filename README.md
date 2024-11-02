## Borrow tracker bad debt extension

Smart contract to track borrowers, which allows querying bad debt of specific lending pool as simple as `getBadDebt(address borrowable)` static function call

See [test](test/BorrowTrackerBadDebtExtensionScroll.t.sol) to find usage examples and gas metrics


## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
