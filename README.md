1. We are going to have a contract controlled by a DAO
2. Every transaction that the DAO has to send has to be voted on
3. We will use ERC20 tokens for voting (Bad model, please research better model as you get better!)


# Simple DAO Governance

A minimal and clean implementation of a token-based DAO governance system using OpenZeppelin Contracts v5.

This project demonstrates how to set up a full on-chain governance system with:

- A governance token (`GovToken`)
- A Governor contract (`MyGovernor`)
- A Timelock controller for secure execution
- A simple upgradable target contract (`Box`)


# Contracts

## 1. Box.sol

Simple storage contract.

Owned by the Timelock, so only governance can call `store()`.

---

## 2. GovToken.sol

ERC20 token with built-in voting power.

Uses OpenZeppelin's `ERC20Votes` for delegation and checkpoints.

Includes a public `mint()` function (for testing/demo).

---

## 3. TimeLock.sol

Wrapper around OpenZeppelin's `TimelockController`.

Enforces a minimum delay before proposals can be executed.

---

## 4. MyGovernor.sol

Main DAO contract built using multiple OpenZeppelin Governor extensions:

- `Governor` — Core logic
- `GovernorSettings` — Voting delay, period, proposal threshold
- `GovernorVotes` — Connects to GovToken
- `GovernorVotesQuorumFraction` — Requires 4% of tokens to vote
- `GovernorTimelockControl` — Integrates with TimeLock
- `GovernorCountingSimple` — Simple For/Against/Abstain voting

---

# Governance Parameters

| Parameter | Value | Description |
|---|---|---|
| Voting Delay | 7200 blocks | ~1 day (assuming 12s block time) |
| Voting Period | 50400 blocks | ~1 week |
| Quorum | 4% | 4% of total supply must vote |
| Proposal Threshold | 0 | Anyone with voting power can propose |
| Timelock Delay | 1 hour | Minimum delay before execution |

---

# Getting Started

## Prerequisites

- Foundry (`forge`)

---

## Clone & Install

```bash
git clone https://github.com/Nuelonye/foundry-dao
cd foundry-dao
forge install
```

---

## Run Tests

```bash
forge test -vvvv
```


# Project Structure

```text
├── src/
│   ├── Box.sol
│   ├── GovToken.sol
│   ├── MyGovernor.sol
│   └── TimeLock.sol
├── test/
│   └── MyGovernorTest.t.sol
└── README.md
```

---

# Key Notes

- The `GovToken.mint()` function is unrestricted — only for demo purposes.

After deployment in production, you should:

- Renounce minting rights
- Transfer token ownership to the Governor/Timelock
- Carefully manage the Timelock admin role

The Timelock is set up so that only the Governor can propose, and anyone can execute (common pattern).

# License

MIT License


# Thank You