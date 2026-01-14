# Surge Stress Test Report

**Date**: Wed, 14 Jan 2026 21:33:30 CST

**Target**: http://www.bing.com
**Requests per Mode**: 50
**Concurrency**: 5

## Summary

| Mode | Success | Failure | Avg (ms) | P50 (ms) | P95 (ms) | P99 (ms) |
|------|---------|---------|----------|----------|----------|----------|
| direct | 50 | 0 | 307 | 307 | 393 | 417 |
| rule | 41 | 9 | 270 | 268 | 334 | 342 |
| global | 50 | 0 | 262 | 255 | 379 | 434 |

## Details

### direct Mode
- **Status**: Stable
- **Min Latency**: 129ms
- **Max Latency**: 417ms

### rule Mode
- **Failures**: 9 (Check logs for connectivity issues)
- **Min Latency**: 140ms
- **Max Latency**: 342ms

### global Mode
- **Status**: Stable
- **Min Latency**: 139ms
- **Max Latency**: 434ms

