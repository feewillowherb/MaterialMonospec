## ADDED Requirements

### Requirement: 材料独立维护
材料 SHALL 有 Guid Id、ProId、必填名称、可空编码和默认用途、必填默认单位 kg 及启用状态；当前 SHALL 用于查找自动填入，不承载数量单价。

#### Scenario: 选择材料
- **WHEN** 用户在合同明细选择启用材料
- **THEN** 带出名称、单位和默认用途并允许编辑，数量单价保存在合同明细

### Requirement: 公司独立维护
公司 SHALL 有 Guid Id、ProId、必填名称和地址、可空联系人及字符串联系电话、启用状态；SHALL NOT 固定为单一交易角色。

#### Scenario: 地址缺失
- **WHEN** 用户保存空白地址的公司
- **THEN** 保存失败并提示地址必填

### Requirement: 单据快照独立
业务单据 SHALL 保存可空材料/公司逻辑引用和实际字段快照，允许手工填写；公司地址与收货地址 SHALL 独立。

#### Scenario: 目录修改不追溯
- **WHEN** 已保存合同引用的公司或材料被修改、停用或软删除
- **THEN** 合同名称、用途和地址快照保持不变，手工填入的单据仍可使用
