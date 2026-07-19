# Oracle Review Evidence

## Adversarial QA

- **Placeholder evidence**: Fresh `init` target fails `verify --must-pass` with all 5 gates failing (RED case).
- **Populated evidence**: After adding non-placeholder sections, `verify --must-pass` reports `Overall: READY` (GREEN case).
- **Foreign hooks preserved**: Uninstall removes only LazyKimi hook entries, leaves `/some/other/hook.sh` entry.
- **Plugin root vs installed target**: Doctor/verify pass in both layouts.
- **No source leakage**: `package_boundary` regression confirms `dist/`, `node_modules/`, `tests/` are not copied by `init`.
