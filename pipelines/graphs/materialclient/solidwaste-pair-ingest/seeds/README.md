# seeds — local package for solidwaste-pair-ingest

Copy from `_temp/固废/91/` into this folder:

| File | Required |
|------|----------|
| `MaterialClient.db` | yes（gitignore；勿提交） |
| `车牌.jpg` | yes |
| `车牌2.jpg` | yes |
| `车顶.jpg` | yes |
| `content.md` | optional note |

After a successful `-Write` run, photos are also written under:

`PhotoJianKong/YYYY/MM/DD/`

Ship **DB + PhotoJianKong** together when restoring to the client machine.
