# xiaoshan-platform-upload-epic

**状态**：脚手架（S）— 已挂 INT 追溯；**尚无**完整 PRD / Architecture / OpenSpec slices 正文。  
**theme**：`xiaoshan-upload`  
**park**：`park/xiaoshan-serve`（`parked_until: 2026-09`）  
**repos**：MaterialClient（Urban）、UrbanManagement  
**集成分支**：`epic/xiaoshan-platform-upload`（四阶段共用；阶段完工合入此分支，**不**合 `main`；整包完成后再合 `main`）

## 本目录

| 文件 | 说明 |
|------|------|
| [epic-traceability.md](./epic-traceability.md) | INT → 规划 slice → 建议 change-id |
| `prd.md` | 未建（可选后续 `bmad-prd` / Fast path） |
| `architecture.md` | 未建 |
| `slices/` | 未建（propose 时再拆） |

## 输入种子

- INT-001 … INT-004（`docs/intake/2026-08/`）
- Draft archive：`docs/intake/2026-08/drafts/archive/2026-08-27-urban-xiaoshan-upload-config.md`（D1–D6）
- 设计稿：`docs/2026-08-27-xiaoshan-weighbridge-gate-product-upload-design/01-设计稿.md`

## 明确排除

- Urban V2 四槽多机授权（另 theme / 另 Epic）
- 三通道实际上报接口落地（地磅/卡口/成品）— 不在本批 INT；需另开 INT 或 change

## 下一步（任选）

1. 检出/保持 `epic/xiaoshan-platform-upload`，在其上 `/opsx:propose`（INT-001 起）  
2. 每阶段 apply + archive 后 **merge 回本 Epic 集成分支**（勿合 `main`）  
3. INT → `proposed` / `closed` 回填；整包完成后再 PR 合 `main`
