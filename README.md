# Yarc

Yet Another RiscV Core, implements RV32I with support for additional extensions planned.

## Yarc Platform Architecture

![My Image](misc/platform_arch.png)

## Core Microarchitecture

The core follows the standard 5-stage pipelined model but the M(memory) stage was split into two stages M1 and M2. This accomodates the common case where the memory subsystem takes a single clock cycle to read or write.

## Memory Subsystem

### Instruction Cache

### Data Cache

## Video Core

## Supported Extensions and Features

- [X] Zicsr
- [ ] M(multiplication/division)
- [ ] Debug Module

## FPGA Synthesis

TODO
