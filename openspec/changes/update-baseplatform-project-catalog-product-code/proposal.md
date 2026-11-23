## Why

项目目录只返回 5001，138 的 Worker 无法通过此接口取得 5020 项目，即使项目已在线激活。

## What Changes

- 为现有项目目录增加可选 `productCode`，接受 5001 和 5020。
- 兼容省略参数的调用。5020 使用独立 API Key 和已批准的项目白名单。

## Capabilities

### New Capabilities

### Modified Capabilities

- `baseplatform-project-catalog-api` 增加按产品查询与授权。

## Impact

实现位于 FdSoft.BasePlatform.PublicApi。138 的 Worker 接入由 fix-recycle-5020-project-readiness 后续处理。
