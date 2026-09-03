@echo off
chcp 65001 >nul
setlocal

REM =============================================================================
REM GDXS20260520002 地磅 weighbridge 内网联调 — 拷贝到内网机器后双击运行
REM Graph: pipelines/graphs/govsync/gdxs20260520002-weighbridge
REM
REM 拷贝清单（同文件夹）:
REM   1. Run-GdxsWeighbridge.cmd
REM   2. Run-GdxsWeighbridge.ps1
REM   3. 16cfa8c48c427f193da61f7a6903f9d6.png  （或 test_pic.png）
REM
REM 场景: 接入码 GDXS20260520002 / 车牌 浙A12345 / 1475kg
REM 端点: POST http://191.12.15.58:8899/sapi/v1/inoutRecord/lantu/saveRecord
REM 警告: 会向政府平台写入一条称重记录
REM 结果: 输出到同目录 output\<时间戳>\
REM =============================================================================

cd /d "%~dp0"

if not exist "Run-GdxsWeighbridge.ps1" (
    echo [ERROR] Missing Run-GdxsWeighbridge.ps1 in: %~dp0
    pause
    exit /b 1
)

if not exist "16cfa8c48c427f193da61f7a6903f9d6.png" if not exist "test_pic.png" if not exist "test_pic.jpg" (
    echo [ERROR] Missing snap image in: %~dp0
    echo Expected: 16cfa8c48c427f193da61f7a6903f9d6.png
    pause
    exit /b 1
)

echo.
echo === GDXS20260520002 weighbridge internal probe ===
echo Folder: %~dp0
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Run-GdxsWeighbridge.ps1"
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
