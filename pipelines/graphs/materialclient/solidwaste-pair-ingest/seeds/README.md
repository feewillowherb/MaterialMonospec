# seeds — local package for solidwaste-pair-ingest

## Layout

```
seeds/
  MaterialClient.db          # gitignore；勿提交
  content.md
  image-manifest.json        # GUID 文件名清单
  PhotoJianKong/2026/09/01/
    车牌_1_{guid32}.jpg
    车牌2_1_{guid32}.jpg
    车顶_1_{guid32}.jpg
```

命名对齐现网 `AttachmentFiles`：`{相机名}_1_{Guid.N}.jpg`，相对路径 `PhotoJianKong\2026\09\01\...`。

## 来源

从 `_temp/固废/91/` 拷入 DB；短名 jpg 已按上式重命名落入 `PhotoJianKong\2026\09\01\`。

写入成功后，将 **DB + PhotoJianKong** 一并拷回现场客户端存储根目录。
