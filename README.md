# Yarc

Yet Another RiscV Core, implements RV32I

## Yarc Platform Architecture

![My Image](misc/platform_arch.png)

## Core Microarchitecture

The core follows the standard 5-stage pipelined model.

## Memory Subsystem

### Instruction Cache

### Data Cache

## Video Core

## Supported Extensions and Features

- [X] Zicsr
- [X] M(multiplication/division)
- [X] Atomics
- [ ] Debug Module
- [ ] S mode and MMU

## Milestones on the way to Boot Linux

- [X] rv32ui tests ok
- [X] rv32mi tests ok
- [X] rv32um tests ok
- [X] rv32ua tests ok
- [X] Implement M extension
- [X] Implement A extension
- [ ] Attempt to boot OpenSBI

## FPGA Synthesis

TODO
