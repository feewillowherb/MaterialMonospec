@echo off
chcp 65001 >nul
setlocal

REM =============================================================================
REM XiaoShanServe /Api/Post 内网联调 — 拷贝到内网机器后双击运行
REM Graph: pipelines/graphs/govsync/xiaoshan-serve-apipost
REM
REM 拷贝清单（三个文件放同一文件夹）:
REM   1. Run-XiaoshanServeApiPost.cmd   （本文件）
REM   2. Run-XiaoshanServeApiPost.ps1   （同目录 ps1）
REM   3. test_pic.jpg                   （来自 ..\..\fixtures\test_pic.jpg）
REM
REM 端点: POST http://191.12.234.212:8899/Api/Post
REM 报文: mGovRequestWeight（legacy-weigh）
REM 警告: 经 Serve 转发可能写入 UM UrbanWeighingRecord / 拒收暂存
REM 结果: 输出到同目录 output\<时间戳>\
REM =============================================================================

cd /d "%~dp0"

if not exist "Run-XiaoshanServeApiPost.ps1" (
    echo [ERROR] Missing Run-XiaoshanServeApiPost.ps1 in: %~dp0
    pause
    exit /b 1
)

if not exist "test_pic.jpg" (
    echo [ERROR] Missing test_pic.jpg in: %~dp0
    echo Copy from: pipelines\graphs\govsync\xiaoshan-serve-apipost\fixtures\test_pic.jpg
    pause
    exit /b 1
)

echo.
echo === XiaoShanServe /Api/Post internal probe ===
echo Folder: %~dp0
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Run-XiaoshanServeApiPost.ps1"
set "RC=%ERRORLEVEL%"

echo.
if "%RC%"=="0" (
    echo [DONE] Business code 200 — check output folder.
) else if "%RC%"=="2" (
    echo [FAIL] No HTTP response — check network / VPN / host / IIS logs.
) else (
    echo [FAIL] HTTP or business code not OK — see output folder + Serve logs/.
)
echo.
pause
exit /b %RC%
