# pipelines/graphs/govsync — domain index

政府平台出站 / 对接探测与采证（`family` 多为 `probe` / `transform`）。

约定权威：[`pipelines/AGENTS.md`](../../AGENTS.md)。本文件仅索引本 domain。

## 现行 weighbridge 探针（`{buildLicenseNo}-weighbridge`）

| slug | buildLicenseNo | goal |
|------|----------------|------|
| `xiaoshan-weighbridge` | （见 config） | `gov-xiaoshan-weighbridge-save` |
| `xnxs20240725003-weighbridge` | `XNXS20240725003` | `gov-xnxs20240725003-weighbridge-save` |
| `gdxs20260520002-weighbridge` | `GDXS20260520002` | `gov-gdxs20260520002-weighbridge-save` |
| `330109202203290201-weighbridge` | `330109202203290201` | `gov-330109202203290201-weighbridge-save` |

新站点独立 Graph：**MUST** 用 slug `{buildLicenseNo}-weighbridge`，**MUST NOT** 覆盖姊妹图 goal。

站点嵌套（如 `XNYH20251113001/`）见该目录 `AGENTS.md`。
