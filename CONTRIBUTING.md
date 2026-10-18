# Contributing to STORNADO

## Quality rules (from the project brief)
1. Distinguish **spec / assumption / simulation / measurement / goal**.
2. Real references + exact spec versions (PCIe Base, NVMe 2.0c).
3. **Do not claim compatibility without a test.**
4. Never invent prices, power, or throughput.
5. Authorized DMA engine != arbitrary RAM access.
6. PCIe interface != complete NVMe controller.
7. Reproducible tests, modularity (portable logic vs IP wrappers).
8. State the tools/commands/files.
9. One alternative per major decision.
10. Do not ignore the M.2 constraints (power/space).
11. Plan for board recovery and flash errors.
12. Exact vocabulary - **no** stealth/undetectability claims.

## Workflow
- Feature branch, PR with a clear description.
- `make test-host` and `make sim` must pass (CI runs them).
- Every new RTL module: a testbench + a `TODO-IP`/`TODO-SPEC` marker if it depends
  on hardware.
- Explicitly mark what is proven in sim vs what depends on real hardware.
