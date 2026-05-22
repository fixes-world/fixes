# AGENTS.md — Fixes World (Flow Cadence)

Instructions for AI coding agents working in this repository.

## Project

Cadence smart contracts for **Fixes World** — an autonomous programmable token universe on Flow (FRC-20 inscriptions, marketplace, staking, lottery, EVM bridge utilities).

- Package: `@fixes/contracts` (`package.json`)
- Docs / links: [README.md](README.md), <https://linktr.ee/fixes.world>

## Repository layout

| Path | Purpose |
|------|---------|
| `cadence/contracts/` | Core contracts (deployed via `flow.json`) |
| `cadence/contracts/deployable/` | Per-token deployable templates (e.g. `FRC20FungibleToken`) |
| `cadence/transactions/` | Mainnet/testnet/emulator transactions |
| `cadence/transactions-for-evm/` | EVM-related transactions |
| `cadence/scripts/` | Read-only scripts |
| `cadence/archived/` | Deprecated code — do not extend unless explicitly asked |
| `flow.json` | Contract sources, network aliases, accounts, deployments |
| `imports/` | Flow dependency cache (gitignored) — do not edit |

**Deployed account aliases** (from `flow.json`): mainnet `d2abb5dbf5e08666`, testnet `b7248baa24a95c3f`.

## Commands

Requires [Flow CLI](https://developers.flow.com/tools/flow-cli) and `pnpm`.

```bash
# Local emulator: deploy + fund default account
pnpm dev

# Deploy all contracts in flow.json
pnpm deploy:emulator
pnpm deploy:testnet
pnpm deploy:mainnet

# Heartbeat / FT upgrade (examples; see package.json for signers)
pnpm hb:emulator
pnpm upgrade-ft:testnet
```

Ad-hoc transaction:

```bash
flow transactions send ./cadence/transactions/<path>.cdc --signer=<account> --network=<network>
```

Line counts (optional):

```bash
pnpm lines:contracts
```

## Cadence conventions

- **Cadence 1.x** syntax (`access(all)`, `access(self)`, etc.) as used in existing files.
- **Resources**: Every `@` resource must be moved, deposited, or destroyed on all paths. Do not leave a vault unused after `withdraw` — even zero-balance vaults must be consumed (e.g. no-op `deposit` to treasury), or future type-checking will fail.
- **Scope**: Minimal diffs; match naming, access control, and patterns in the touched contract. Do not refactor unrelated code.
- **Comments**: English only in `.cdc` files.
- **Deployable vs shared**: Shared logic lives in contracts like `FRC20Indexer`, `FRC20FTShared`, `Fixes`; token-specific logic in `deployable/`.

## Safety — do not

- Commit or read `*.pkey`, `emulator.key`, or KMS key material into chat/logs.
- Modify `imports/` or run destructive git commands unless the user explicitly requests it.
- Run `deploy:mainnet` / mainnet transactions without explicit user approval.
- Assume test coverage exists — `cadence/tests/` may be empty; verify behavior via scripts/transactions or ask the user.

## Git

- Default branch: `main`
- Use focused branch names (e.g. `fix/...`, `feat/...`).
- Commit only when the user asks; follow existing message style (`fix:`, `feat:`).
- Do not push or open PRs unless asked.

## Key contracts (orientation)

| Contract | Role |
|----------|------|
| `Fixes` | Core platform / admin helpers |
| `FRC20Indexer` | Token registry, treasuries |
| `FRC20FTShared` | Shared config / sale-cut types |
| `FRC20Storefront` | Listings, purchases, sale cuts |
| `FRC20Marketplace` / `FRC20MarketManager` | Market operations |
| `FRC20Staking*` | Staking pools and vesting |
| `FGameLottery*` | Lottery games |
| `FixesTVL` | TVL calculation |

When changing payment splits or vault flows, trace full resource paths in `_payToSaleCuts` and similar helpers.
