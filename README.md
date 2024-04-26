## OpenRFP

Smart contracts to provide an extension on top of OpenR&D, to allow for RFP creation.  
An RFP is simply a budget that projects can apply to get a part of. If approved, an OpenR&D task will be created for this project with the respective amount of approved funding as budget. The project representative will be preapproved to take the project. In case the task is canceled, the budget will be returned to the RFP.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
forge build
```

### Test

```shell
forge test
```

### Deploy

```shell
make deploy
```

## Local chain

```shell
anvil
make local-fund ADDRESS="YOURADDRESSHERE"
```

### Analyze

```shell
make slither
make mythril TARGET=Counter.sol
```

### Help

```shell
forge --help
anvil --help
cast --help
```
