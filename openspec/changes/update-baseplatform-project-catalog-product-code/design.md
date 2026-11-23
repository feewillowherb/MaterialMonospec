## Context

目录现有授权查询固定为 5001，且项目限定萧山。在线激活已支持 5020。

## Goals / Non-Goals

支持独立查询两个产品，保留旧查询默认值与响应体。实际配置和 138 发布属于环境接入。

## Decisions

5001 沿用萧山 330109 筛选。5020 通过 PublicApiServiceAuth 下的 RecycleCatalogApiKey 和 RecycleCatalogProjectIds 限定访问。白名单以真实项目 GUID 配置，空白名单无可见项目。按所选产品先筛授权，再按项目选最新授权，因此两个产品的同名项目互不覆盖。保持有效项目、未删除授权与接入码校验。

## Risks / Trade-offs

5020 专用凭证只用于该目录查询。部署前须确认批准的真实项目和密钥配置。两个调用路径分别验证分页与授权行为。
