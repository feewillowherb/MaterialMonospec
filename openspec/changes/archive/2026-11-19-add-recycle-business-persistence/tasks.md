## 1. 实施前核对（UrbanManagement）

- [x] 1.1 读取子仓 AGENTS 与相关 traits；核实 ProId 授权映射、Recycle 心跳来源和宿主注册；不得混用 GovProject.Id / SourceProId。
- [x] 1.2 按 Mode B 从 dev-recycle-resource-alignment 创建 add-recycle-business-persistence 同名实施分支；仅在实际改动仓建分支。
- [x] 1.3 固定各字段长度、decimal 精度、接口单位和索引；确认原始值超限时拒绝而非舍入，记录迁移检查结果。

## 2. 独立持久化基础（UrbanManagement）

- [x] 2.1 创建 RecycleDbContext、独立迁移归属和 Migrator 接入；Guid 主键、ProId、ABP 完整审计与软删除，无 FK/导航、无 PlantId。
- [x] 2.2 实现可信项目上下文及服务级项目过滤、写入校验、同项目关联和幂等唯一索引。
- [x] 2.3 实现实体自身变更方法、DTO FromEntity/ToEntity、命名 record；无新 Mapper 或纯换算 DI，服务写方法使用 UnitOfWork。

## 3. 首个持久化切片（UrbanManagement）

- [x] 3.1 实现材料、公司维护与快捷填入，校验公司地址必填，保留单据快照和可空引用。
- [x] 3.2 实现车辆池，车主与运输人独立，重量统一 kg。
- [x] 3.3 实现一次称重一单的持久化接收服务、来源幂等冲突检查、皮重快照与待补全状态；不得以假皮重生成净重。
- [x] 3.4 接入独立附件元数据和项目下载授权，复用物理存储基础设施。
- [ ] 3.5 将对应 Web 操作改接真实 AppService，验证重启后数据保留。资源化站点当前不是 ABP 宿主，改接放到下一 change `add-recycle-web-abp-module`。

## 4. 完整业务台账（UrbanManagement）

- [x] 4.1 实现合同、独立产品明细及多运输方记录；数量/单价/金额归明细，公司地址与收货地址独立。
- [ ] 4.2 日产量与运输清单后补服务已在 Core；Web 查询筛选随 `add-recycle-web-abp-module` 接通。
- [x] 4.3 建立最新同步状态和独立尝试历史，为后续真实发送器提供持久化接口，不伪造发送成功。
- [x] 4.4 实现并验证外发 DTO 的 kg/目标单位精确换算；本 change 不实现第二跳发送 Worker。

## 5. Admin 独立在线状态（UrbanManagement）

- [x] 5.1 接通可信 Recycle 心跳归属与独立状态存储；缺少心跳来源时明确阻断，不用授权状态伪造在线。
- [x] 5.2 实现独立 Recycle 查询 AppService、权限、页面及入口，使用独立超时配置，避免 Urban PageList 混入。

## 6. 验证与证据（MaterialMonospec / UrbanManagement）

- [ ] 6.1 LocalDB 已验证空库与已有 Urban 库均可应用 `20261118081216_AddRecycleBusinessTables`，外键 0，GovProjects 保留。进程重启后的数据保留与软删除历史尚未在运行站点验证。
- [ ] 6.2 验证跨 ProId 读写/关联/附件拒绝、资料快照不追溯、幂等重试及冲突、缺皮重行为。
- [ ] 6.3 验证小数 kg 保存及吨转换无损、越界拒绝、数量单价单位一致；验证真实失败不标成功。
- [ ] 6.4 验证 Recycle/Urban 列表双向隔离、未知/在线/超时离线和越权拒绝。
- [ ] 6.5 运行构建、相关自动化检查和 openspec strict validate，记录 ICD L3 目标环境验收证据；未有证据不得声明交付。
- [ ] 6.6 更新任务状态和实施证据；合入、提交、推送及归档另按用户授权与 squash 工作流执行。
