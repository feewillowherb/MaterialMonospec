# 故障排除指南

## 常见问题和解决方案

### 1. OpenSpec CLI 报错 "Missing required option --change"

**原因**：未指定变更名称。

**解决**：
```bash
openspec status --change <change-name> --json
openspec list  # 查看可用变更
```

### 2. monospecs.yaml 解析错误

**原因**：YAML 语法错误（如缩进不一致、特殊字符未转义）。

**解决**：
- 确保使用空格缩进（不是 Tab）
- 检查 `version` 值为字符串 `"1.0"`（带引号）
- 验证路径使用正斜杠 `/`
- 使用 YAML 在线验证工具检查语法

### 3. 子仓库目录联接失效

**原因**：目标目录移动或删除。

**解决**：
```powershell
# 删除失效的联接
Remove-Item repos\<RepoName>

# 重新创建
New-Item -ItemType Junction -Path "repos\<RepoName>" -Target "<新路径>"
```

### 4. specs 数量不匹配

**原因**：迁移过程中文件丢失或 spec.md 缺失。

**解决**：
```bash
# 检查源和目标数量
ls source/openspec/specs/ | wc -l
ls openspec/specs/ | wc -l

# 检查缺失的 spec.md
for dir in openspec/specs/*/; do
  [ -f "${dir}spec.md" ] || echo "MISSING: ${dir}spec.md"
done
```

### 5. 归档变更文件名冲突

**原因**：不同子仓库有相同名称的归档变更。

**解决**：
- 为冲突的变更添加仓库名前缀
- 例如：`2026-01-15-materialclient-doc-org`

### 6. commit_when_archive 不工作

**原因**：配置值设置为 false。

**解决**：
- 检查 `monospecs.yaml` 中 `commit_when_archive: true`
- 确认主仓库有 Git 初始化
- 检查 Git 用户配置

### 7. Git 追踪了 repos/ 目录

**原因**：`.gitignore` 未正确配置。

**解决**：
```bash
# 确保 .gitignore 包含
echo "repos/" >> .gitignore

# 移除已追踪的文件
git rm -r --cached repos/
git commit -m "fix: exclude repos/ from git tracking"
```

### 8. OpenSpec 找不到 specs

**原因**：specs 目录路径不正确或文件结构不符合规范。

**解决**：
- 确认 specs 在 `openspec/specs/<name>/spec.md`
- 每个能力目录必须包含 `spec.md` 文件
- 检查文件名大小写

## 紧急回滚

如果迁移出现严重问题：

1. 从备份恢复子仓库的 openspec/ 目录
2. 恢复主仓库到迁移前的 Git 提交
3. 检查所有 specs 完整性

---

## 相关调研文档

| 主题 | 路径 |
|------|------|
| 称重列表重复数据（ILocalEventBus 线程） | [2026-07-13-weighing-list-duplicate-localevent/](./2026-07-13-weighing-list-duplicate-localevent/00-调研总览.md) |
| 海康 LPR 车牌解析异常 | [HikLpr/](./HikLpr/00-调研总览.md) |
