## Context

`UrbanManagement.XiaoShanResource` 已落地车辆/合同 mock 列表与 SSO 5041 登录（change `add-xiaoshan-resource-web`）。参考图 `_tmp/萧山资源化利用/1116` 给出「生产管理」「运输清单」两页字段与操作。对齐 Topic 已确认：车辆管理是皮重信息池；工控上传毛重后由平台算净重；业务明细在 Web 补全。本单只扩 Web mock 画面，不接工控与市平台。

## Goals / Non-Goals

**Goals:**

- 侧栏与页签支持四页：车辆、合同、生产管理、运输清单。
- 生产管理 mock：日产量式列表（标识编号、批次、产品、生产日期、生产量、上报状态/时间），筛选 + 批量上报 + 刷新上报 + 合计。
- 运输清单 mock：车次列表（车牌、合同编号、产品、产品净重、起卸点摘要、出货/收货时间与凭证入口、上报相关筛选），筛选 + 批量上报 + 净重合计。
- API 与存储模式对齐现有 `ResourceMockStore`：进程内存、重启回种子、需登录 Cookie。

**Non-Goals:**

- 独立建表、EF migration、工控 receive、净重真实计算链路。
- 调用杭州市接口 V1.0 / HMAC；真实 PDF/图片上传到 Attachment。
- Resource → Recycle 工程 rename。
- 消纳场地、系统管理、仪表盘。

## Decisions

1. **能力归属**  
   修改既有 `xiaoshan-resource-web`，不新建 capability。两页是同一站点画面扩展。

2. **路由**  
   `/productions`（生产管理）、`/transports`（运输清单）。页签标题用中文菜单名。

3. **Mock 形状（按图，不发明业务规则）**  
   - 生产管理行：`markNo`（标识编号）、`batchNo`、`productName`、`produceDate`、`volumeTons`、`reportStatus`、`reportTime`。  
   - 运输清单行：`plateNo`、`contractNo`、`productName`、`netWeightTons`、`originSummary`、`unloadSummary`、`shipTime`、`shipVoucherLabel`、`receiveTime`、`receiveVoucherLabel`、运输/上报状态字段（筛选用；表列以图上可见为准）。  
   - 凭证列本单只展示可点的「查看」式按钮并弹出 mock 文件名/占位，不存二进制。

4. **批量上报**  
   与合同页相同策略：将勾选行 mock 状态置为「已上报」/「已发送」类标签，并写发送时间；不发起外呼。

5. **与闭环 Topic 的关系**  
   - 生产管理画面字段对齐市接口 **§2.5** 日产量语义（批次/产品/生产量）。  
   - 运输清单字段对齐 **§2.2** 车次语义（车牌、合同、净重、出货/收货凭证）。  
   - 工控毛重落点在后续 change 归入运输清单侧实体；本单 mock 可预置净重列，不在本单接 receive。

## Risks / Trade-offs

- [Risk] 先前 Topic 曾把工控落点写在「生产管理」→ 与 1116 截图字段不符。  
  → Mitigation：本 design 与 Topic `05` 纠正为运输清单承载车次；生产管理为日产量页。
- [Risk] 运输清单列多、参考图截断。  
  → Mitigation：可见列按图实现；截断文案保留可见部分，不臆造完整地址。
- [Risk] mock 继续膨胀。  
  → Mitigation：种子条数适量（十数行级），分页/筛选在内存完成，与车辆合同一致。

## Migration Plan

- 仅 UrbanManagement 分支改动；无 DB。部署仍用现有 `um-xiaoshanresource` 镜像重建即可。
- 回滚：回退该分支前端与 Mock API。

## Open Questions

- 运输清单「运输状态」枚举取值（图上仅「全部状态」）——实现时用少量 mock 枚举即可。
- 凭证按钮点击是弹文件名还是空提示——默认弹 mock 文案，与合同「附件查看」一致。
