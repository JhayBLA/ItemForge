# # ItemForge

**ItemForge** is a Stacks smart contract for registering and managing on-chain in-game items. Game masters mint unique items with rarity traits, players compete to claim them, and creators earn royalties automatically.

## Features

- Mint unique items with trait data, class, and rarity hash
- Competitive claiming — highest bidder becomes lead claimant
- Game master can lock or retire items at any time
- Configurable royalty rate (up to 10%)
- Full read-only queries for item and claim state

## Contract Functions

### Public

| Function | Description |
|---|---|
| `mint-item` | Register a new in-game item |
| `claim-item` | Bid to claim an item |
| `lock-item` | Game master closes claiming early |
| `retire-item` | Remove an unclaimed item |
| `update-royalty-rate` | Authority-only fee update |

### Read-Only

| Function | Description |
|---|---|
| `get-item` | Fetch item details |
| `get-player-claim` | Fetch a player's claim record |
| `is-claiming-open` | Check if item is claimable |
| `is-item-retired` | Check if equip window has passed |
| `calculate-royalty` | Preview royalty on a value |

## Error Reference

| Code | Meaning |
|---|---|
| u600 | Not authorized |
| u601 | Item already exists |
| u602 | Item not found |
| u603 | Item is locked |
| u604 | Item is not locked |
| u605 | Invalid trait data |
| u606 | Not an auditor |
| u607 | Not the game master |
| u608 | Already claimed |
| u609 | Invalid equip window |
| u610 | Invalid rarity hash |
| u611 | Authority access only |
| u612 | Claiming is closed |
| u613 | Empty item ID |
| u614 | Empty trait data |
| u615 | Empty item class |

## Deployment

Deploy using Clarinet:
```bash
clarinet contract publish item-forge
```

## License

MIT
```

## PR Description — ItemForge
```
## ItemForge: On-Chain Game Item Registry

This PR introduces the `item-forge` Clarity contract, a full lifecycle manager for in-game items on the Stacks blockchain.

### What's included
- `mint-item`: Game masters register items with trait metadata, rarity hash, and an equip window
- `claim-item`: Players compete for items via a stake-based bidding mechanism
- `lock-item`: Game master can close claiming early and finalize the equip window
- `retire-item`: Removes an unclaimed item cleanly from the registry
- `update-royalty-rate`: Governance function for authority to adjust creator royalties

### Design notes
- Item claiming uses a highest-bid model; first claimer must meet the rarity hash threshold, subsequent claimants must outbid
- All string inputs are validated to prevent empty field submissions
- Royalty basis points are capped at 1000 (10%) to protect players
- All state-mutating operations include block-height checks against the equip window

### Testing
- All functions covered with Clarinet unit tests
- Edge cases: empty inputs, expired windows, duplicate claims, unauthorized governance calls


chore: add README with function reference and error code table

docs: add PR description and deployment instructions
