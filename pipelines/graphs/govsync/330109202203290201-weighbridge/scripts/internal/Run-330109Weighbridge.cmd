@echo off
chcp 65001 >nul
setlocal

REM =============================================================================
REM 330109202203290201 地磅 weighbridge 内网联调 — 拷贝到内网机器后双击运行
REM Graph: pipelines/graphs/govsync/330109202203290201-weighbridge
REM
REM 拷贝清单（同文件夹）:
REM   1. Run-330109Weighbridge.cmd
REM   2. Run-330109Weighbridge.ps1
REM   3. test_pic_v2.jpg  （或 test_pic.jpg）
REM
REM 场景: 接入码 330109202203290201 / 车牌 浙A12345 / 1060kg / 2026-10-26 10:02:08
REM 端点: POST http://191.12.15.58:8899/sapi/v1/inoutRecord/lantu/saveRecord
REM 警告: 会向政府平台写入一条称重记录
REM 结果: 输出到同目录 output\<时间戳>\
REM =============================================================================

cd /d "%~dp0"

if not exist "Run-330109Weighbridge.ps1" (
    echo [ERROR] Missing Run-330109Weighbridge.ps1 in: %~dp0
    pause
    exit /b 1
)

if not exist "test_pic_v2.jpg" if not exist "test_pic.jpg" if not exist "test_pic.png" (
    echo [ERROR] Missing snap image in: %~dp0
    echo Expected: test_pic_v2.jpg
    pause
    exit /b 1
)

echo.
echo === 330109202203290201 weighbridge internal probe ===
echo Folder: %~dp0
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Run-330109Weighbridge.ps1"
set "RC=%ERRORLEVEL%"

echo.
if "%RC%"=="0" (
    echo [DONE] Business code 200 — check output folder.
) else if "%RC%"=="2" (
    echo [FAIL] No HTTP response — check network / VPN / host.
) else (
    echo [FAIL] HTTP or business code not OK — see output folder.
)
echo.
pause
exit /b %RC%
