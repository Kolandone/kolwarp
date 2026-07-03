@echo off
setlocal enabledelayedexpansion

:: koland.bat - Windows batch script for WARP client
:: Telegram: @kolandjs1 | GitHub: github.com/kolandone

title kolwarp - WARP MASQUE/WireGuard Client

:: Colors (Windows 10+ with ANSI support)
set "GREEN=[92m"
set "RED=[91m"
set "YELLOW=[93m"
set "BLUE=[94m"
set "CYAN=[96m"
set "MAGENTA=[95m"
set "WHITE=[97m"
set "DIM=[2m"
set "BOLD=[1m"
set "NC=[0m"

:: Configuration
set "SCRIPT_DIR=%~dp0"
set "KOLWARP_BIN=%SCRIPT_DIR%kolwarp.exe"
set "CONFIG_FILE=%SCRIPT_DIR%config.json"
set "RESULTS_DIR=%SCRIPT_DIR%scan_results"

:: Check dependencies
where curl >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo %RED%Error: curl not found. Please install curl.%NC%
    pause
    exit /b 1
)

:: Check kolwarp binary
if not exist "%KOLWARP_BIN%" (
    echo %YELLOW%kolwarp binary not found at %KOLWARP_BIN%%NC%
    echo.
    echo Would you like to download it? (Y/N)
    set /p response=
    if /i "!response!"=="Y" (
        call :download_kolwarp
    ) else (
        echo %RED%Cannot continue without kolwarp binary%NC%
        pause
        exit /b 1
    )
)

:main_menu
cls
echo.
echo %CYAN%╔═════════════════════════════════════════════════════════════════════════╗
echo ║                                                                         ║
echo ║                    %WHITE%K O L A N D%NC%%CYAN%                                     ║
echo ║                                                                         ║
echo ║          %DIM%WARP MASQUE/WireGuard Client with Smart Scanner%NC%%CYAN%            ║
echo ║                                                                         ║
echo ╚═════════════════════════════════════════════════════════════════════════╝%NC%
echo.
echo   %DIM%Telegram: %MAGENTA%@kolandjs1%NC%  ^|  %DIM%GitHub: %BLUE%github.com/kolandone%NC%
echo.
echo %BOLD%%WHITE%  Main Menu%NC%
echo.
echo   %GREEN%1.%NC% %BOLD%Register%NC%              %DIM%- Create new WARP account%NC%
echo   %GREEN%2.%NC% %BOLD%Scan ^& Connect%NC%        %DIM%- Find best endpoint ^& connect%NC%
echo   %GREEN%3.%NC% %BOLD%Quick Connect%NC%         %DIM%- Connect with current config%NC%
echo   %GREEN%4.%NC% %BOLD%Account Info%NC%          %DIM%- View account details%NC%
echo   %GREEN%5.%NC% %BOLD%About%NC%                 %DIM%- Credits ^& social links%NC%
echo   %RED%0.%NC% %BOLD%Exit%NC%
echo.
echo %DIM%────────────────────────────────────────%NC%
echo   %DIM%Select an option [0-5]:%NC% 
set /p choice=

if "%choice%"=="1" goto :do_register
if "%choice%"=="2" goto :do_scan_connect
if "%choice%"=="3" goto :do_quick_connect
if "%choice%"=="4" goto :do_account_info
if "%choice%"=="5" goto :do_about
if "%choice%"=="0" goto :do_exit

echo %RED%Invalid choice%NC%
timeout /t 1 >nul
goto :main_menu

:do_register
if not exist "%KOLWARP_BIN%" (
    echo %RED%kolwarp binary not found at %KOLWARP_BIN%%NC%
    echo.
    echo   %DIM%Press any key to continue...%NC%
    pause >nul
    goto :main_menu
)
cls
echo.
echo %BLUE%╔═══ Register New WARP Account ═══╗%NC%
echo.

if exist "%CONFIG_FILE%" (
    echo   %YELLOW%Warning: Existing config found at %CONFIG_FILE%%NC%
    echo   Do you want to overwrite? (Y/N)
    set /p response=
    if /i not "!response!"=="Y" goto :main_menu
)

echo   %DIM%Enter device name (optional, press Enter to skip):%NC% 
set /p device_name=

echo.
echo   %DIM%Select registration type:%NC%
echo   %GREEN%1.%NC% Personal WARP (MASQUE)
echo   %GREEN%2.%NC% Personal WARP (WireGuard)
echo   %GREEN%3.%NC% ZeroTrust (requires JWT token)
echo   %DIM%Select [1-3]:%NC% 
set /p reg_type=

set "cmd=%KOLWARP_BIN% register -c "%CONFIG_FILE%" --accept-tos"

if defined device_name (
    set "cmd=!cmd! -n "!device_name!""
)

if "%reg_type%"=="2" (
    set "cmd=!cmd! --wireguard"
) else if "%reg_type%"=="3" (
    echo   %DIM%Enter ZeroTrust JWT token:%NC% 
    set /p jwt_token=
    set "cmd=!cmd! --jwt "!jwt_token!""
)

echo.
echo   %CYAN%Running registration...%NC%
echo.

!cmd!

if %ERRORLEVEL% equ 0 (
    echo.
    echo   %GREEN%✓ Registration successful!%NC%
) else (
    echo.
    echo   %RED%✗ Registration failed%NC%
)

echo.
echo   %DIM%Press any key to continue...%NC%
pause >nul
goto :main_menu

:do_scan_connect
cls
echo.
echo %BLUE%╔═══ Smart Endpoint Scanner ^& Connect ═══╗%NC%
echo.
echo   %BOLD%This will scan WARP endpoints and let you choose the best one%NC%
echo.
echo   %DIM%How many endpoints to scan?%NC%
echo   %GREEN%1.%NC% %BOLD%Quick%NC%               %DIM%- 30 endpoints (fast)%NC%
echo   %GREEN%2.%NC% %BOLD%Normal%NC%              %DIM%- 100 endpoints%NC%
echo   %GREEN%3.%NC% %BOLD%Deep%NC%                %DIM%- 300 endpoints (thorough)%NC%
echo   %RED%0.%NC% %BOLD%Back%NC%
echo.
echo %DIM%────────────────────────────────────────%NC%
echo   %DIM%Select [0-3]:%NC% 
set /p scan_mode=

set "endpoint_count=30"

if "%scan_mode%"=="1" set "endpoint_count=30"
if "%scan_mode%"=="2" set "endpoint_count=100"
if "%scan_mode%"=="3" set "endpoint_count=300"
if "%scan_mode%"=="0" goto :main_menu

echo.
echo %BLUE%╔═══ Scanning %endpoint_count% WARP Endpoints ═══╗%NC%
echo.
echo   %CYAN%Testing endpoints for connectivity...%NC%
echo.

if not exist "%RESULTS_DIR%" mkdir "%RESULTS_DIR%"

set /a scanned=0
set /a working=0
set "results_file=%RESULTS_DIR%\results.txt"

echo Endpoint,Status > "!results_file!"

:scan_loop
if !scanned! geq %endpoint_count% goto :scan_done

set /a scanned+=1

:: Generate random IP from WARP ranges
set /a "prefix_idx=!random! %% 14"
set /a "last_octet=!random! %% 256"
set /a "port_idx=!random! %% 54"

call :get_prefix !prefix_idx!
call :get_port !port_idx!

set "endpoint=!prefix!.!last_octet!:!port!"

:: Test endpoint
echo   %DIM%[%scanned%/%endpoint_count%]%NC% Testing %CYAN%!endpoint!%NC% 

curl -s -o nul -w "%%{time_total}" --connect-timeout 2 --max-time 2 "https://!endpoint!/" >nul 2>&1
if !ERRORLEVEL! equ 0 (
    echo %GREEN%✓%NC%
    set /a working+=1
    echo !endpoint!,success >> "!results_file!"
) else (
    echo %RED%✗%NC%
)

goto :scan_loop

:scan_done
echo.
echo %DIM%────────────────────────────────────────%NC%
echo   %CYAN%Scan completed!%NC%
echo   %GREEN%Found !working! working endpoints%NC%
echo.

if !working! equ 0 (
    echo   %RED%No working endpoints found%NC%
    echo.
    echo   %DIM%Press any key to continue...%NC%
    pause >nul
    goto :main_menu
)

:: Show results
echo   %BOLD%%CYAN% #   Endpoint                    Status%NC%
echo   %DIM%─────────────────────────────────────────────%NC%

set /a idx=0
for /f "tokens=1,2 delims=," %%a in (!results_file!) do (
    if not "%%a"=="Endpoint" (
        set /a idx+=1
        echo   %GREEN%!idx!%NC%   %WHITE%%%a%NC%   %GREEN%✓ Working%NC%
    )
)

echo.
echo %DIM%────────────────────────────────────────%NC%
echo.
echo   %BOLD%%WHITE%Choose an endpoint:%NC%
echo   %DIM%Enter number [1-%idx%] or 0 to go back:%NC% 
set /p choice=

if "%choice%"=="0" goto :main_menu

:: Get selected endpoint
set /a sel_num=0
for /f "tokens=1,2 delims=," %%a in (!results_file!) do (
    if not "%%a"=="Endpoint" (
        set /a sel_num+=1
        if !sel_num! equ %choice% (
            set "selected=%%a"
        )
    )
)

if not defined selected (
    echo   %RED%Invalid selection%NC%
    goto :scan_done
)

echo.
echo   %GREEN%✓ Selected: !selected!%NC%

:: Extract host from endpoint
for /f "tokens=1 delims=:" %%a in ("!selected!") do set "host=%%a"

:: Apply to config
call :apply_config "!host!"

echo.
echo   %BOLD%%WHITE%What would you like to do?%NC%
echo   %GREEN%1.%NC% %BOLD%Connect now%NC%            %DIM%- Start tunnel with this endpoint%NC%
echo   %GREEN%2.%NC% %BOLD%Save only%NC%              %DIM%- Just save to config%NC%
echo   %RED%0.%NC% %BOLD%Cancel%NC%
echo.
echo   %DIM%Select [0-2]:%NC% 
set /p action=

if "%action%"=="1" goto :connect_with_endpoint
if "%action%"=="2" (
    echo   %GREEN%✓ Endpoint saved to config%NC%
)
if "%action%"=="0" (
    echo   %YELLOW%Endpoint not saved%NC%
)

echo.
echo   %DIM%Press any key to continue...%NC%
pause >nul
goto :main_menu

:connect_with_endpoint
cls
echo.
echo %BLUE%╔═══ Select Protocol ═══╗%NC%
echo.
echo   %GREEN%1.%NC% %BOLD%MASQUE%NC%               %DIM%- HTTP/3 QUIC (recommended)%NC%
echo   %GREEN%2.%NC% %BOLD%WireGuard%NC%            %DIM%- UDP tunnel (userspace)%NC%
echo   %GREEN%3.%NC% %BOLD%MASQUE + HTTP/2%NC%      %DIM%- TCP fallback%NC%
echo   %RED%0.%NC% %BOLD%Back%NC%
echo.
echo %DIM%────────────────────────────────────────%NC%
echo   %DIM%Select protocol [0-3]:%NC% 
set /p protocol_choice=

set "protocol_args="
set "protocol_name=MASQUE"

if "%protocol_choice%"=="1" set "protocol_args="
if "%protocol_choice%"=="2" set "protocol_args=--wireguard" & set "protocol_name=WireGuard"
if "%protocol_choice%"=="3" set "protocol_args=--http2" & set "protocol_name=MASQUE+H2"
if "%protocol_choice%"=="0" goto :main_menu

cls
echo.
echo %BLUE%╔═══ Select Mode ═══╗%NC%
echo.
echo   %GREEN%1.%NC% %BOLD%SOCKS5 Proxy%NC%         %DIM%- Full proxy with UDP support%NC%
echo   %GREEN%2.%NC% %BOLD%HTTP Proxy%NC%           %DIM%- HTTP CONNECT proxy%NC%
echo   %GREEN%3.%NC% %BOLD%L4 SOCKS%NC%             %DIM%- Fast TCP-only SOCKS%NC%
echo   %GREEN%4.%NC% %BOLD%L4 HTTP%NC%              %DIM%- Fast TCP-only HTTP%NC%
echo   %GREEN%5.%NC% %BOLD%Native TUN%NC%           %DIM%- Full tunnel interface%NC%
echo   %RED%0.%NC% %BOLD%Back%NC%
echo.
echo %DIM%────────────────────────────────────────%NC%
echo   %DIM%Select mode [0-5]:%NC% 
set /p mode_choice=

set "mode_cmd="
set "mode_name="

if "%mode_choice%"=="1" set "mode_cmd=socks" & set "mode_name=SOCKS5 Proxy"
if "%mode_choice%"=="2" set "mode_cmd=http-proxy" & set "mode_name=HTTP Proxy"
if "%mode_choice%"=="3" set "mode_cmd=l4-socks" & set "mode_name=L4 SOCKS"
if "%mode_choice%"=="4" set "mode_cmd=l4-http-proxy" & set "mode_name=L4 HTTP"
if "%mode_choice%"=="5" set "mode_cmd=nativetun" & set "mode_name=Native TUN"
if "%mode_choice%"=="0" goto :main_menu

set "port=1080"
if "%mode_cmd%"=="http-proxy" set "port=8000"
if "%mode_cmd%"=="l4-http-proxy" set "port=8000"

cls
echo.
echo %BLUE%╔═══ Configure %mode_name% ═══╗%NC%
echo.
echo   %DIM%Bind address [0.0.0.0]:%NC% 
set /p bind_addr=
if not defined bind_addr set "bind_addr=0.0.0.0"

echo   %DIM%Port [%port%]:%NC% 
set /p input_port=
if defined input_port set "port=!input_port!"

set "cmd=%KOLWARP_BIN% %mode_cmd% -c "%CONFIG_FILE%" %protocol_args% -b %bind_addr% -p %port%

echo.
echo %CYAN%══════════════════════════════════════════════════════════════%NC%
echo   %BOLD%%WHITE%  kolwarp - Starting %mode_name%%NC%
echo   %CYAN%══════════════════════════════════════════════════════════════%NC%
echo.
echo   %CYAN%Protocol:%NC% %protocol_name%
echo   %CYAN%Mode:%NC% %mode_name%
echo   %CYAN%Listen:%NC% %bind_addr%:%port%
echo.
echo %DIM%────────────────────────────────────────%NC%
echo   %DIM%Press Ctrl+C to stop%NC%
echo.

!cmd!
goto :main_menu

:do_quick_connect
if not exist "%KOLWARP_BIN%" (
    echo %RED%kolwarp binary not found at %KOLWARP_BIN%%NC%
    echo.
    echo   %DIM%Press any key to continue...%NC%
    pause >nul
    goto :main_menu
)
if not exist "%CONFIG_FILE%" (
    echo %RED%No config found. Please register first.%NC%
    echo.
    echo   %DIM%Press any key to continue...%NC%
    pause >nul
    goto :main_menu
)

cls
echo.
echo %BLUE%╔═══ Select Protocol ═══╗%NC%
echo.
echo   %GREEN%1.%NC% %BOLD%MASQUE%NC%               %DIM%- HTTP/3 QUIC (recommended)%NC%
echo   %GREEN%2.%NC% %BOLD%WireGuard%NC%            %DIM%- UDP tunnel (userspace)%NC%
echo   %GREEN%3.%NC% %BOLD%MASQUE + HTTP/2%NC%      %DIM%- TCP fallback%NC%
echo   %RED%0.%NC% %BOLD%Back%NC%
echo.
echo %DIM%────────────────────────────────────────%NC%
echo   %DIM%Select protocol [0-3]:%NC% 
set /p protocol_choice=

set "protocol_args="
set "protocol_name=MASQUE"

if "%protocol_choice%"=="1" set "protocol_args="
if "%protocol_choice%"=="2" set "protocol_args=--wireguard" & set "protocol_name=WireGuard"
if "%protocol_choice%"=="3" set "protocol_args=--http2" & set "protocol_name=MASQUE+H2"
if "%protocol_choice%"=="0" goto :main_menu

cls
echo.
echo %BLUE%╔═══ Select Mode ═══╗%NC%
echo.
echo   %GREEN%1.%NC% %BOLD%SOCKS5 Proxy%NC%         %DIM%- Full proxy with UDP support%NC%
echo   %GREEN%2.%NC% %BOLD%HTTP Proxy%NC%           %DIM%- HTTP CONNECT proxy%NC%
echo   %GREEN%3.%NC% %BOLD%L4 SOCKS%NC%             %DIM%- Fast TCP-only SOCKS%NC%
echo   %GREEN%4.%NC% %BOLD%L4 HTTP%NC%              %DIM%- Fast TCP-only HTTP%NC%
echo   %GREEN%5.%NC% %BOLD%Native TUN%NC%           %DIM%- Full tunnel interface%NC%
echo   %RED%0.%NC% %BOLD%Back%NC%
echo.
echo %DIM%────────────────────────────────────────%NC%
echo   %DIM%Select mode [0-5]:%NC% 
set /p mode_choice=

set "mode_cmd="
set "mode_name="

if "%mode_choice%"=="1" set "mode_cmd=socks" & set "mode_name=SOCKS5 Proxy"
if "%mode_choice%"=="2" set "mode_cmd=http-proxy" & set "mode_name=HTTP Proxy"
if "%mode_choice%"=="3" set "mode_cmd=l4-socks" & set "mode_name=L4 SOCKS"
if "%mode_choice%"=="4" set "mode_cmd=l4-http-proxy" & set "mode_name=L4 HTTP"
if "%mode_choice%"=="5" set "mode_cmd=nativetun" & set "mode_name=Native TUN"
if "%mode_choice%"=="0" goto :main_menu

set "port=1080"
if "%mode_cmd%"=="http-proxy" set "port=8000"
if "%mode_cmd%"=="l4-http-proxy" set "port=8000"

cls
echo.
echo %BLUE%╔═══ Configure %mode_name% ═══╗%NC%
echo.
echo   %DIM%Bind address [0.0.0.0]:%NC% 
set /p bind_addr=
if not defined bind_addr set "bind_addr=0.0.0.0"

echo   %DIM%Port [%port%]:%NC% 
set /p input_port=
if defined input_port set "port=!input_port!"

set "cmd=%KOLWARP_BIN% %mode_cmd% -c "%CONFIG_FILE%" %protocol_args% -b %bind_addr% -p %port%

echo.
echo %CYAN%══════════════════════════════════════════════════════════════%NC%
echo   %BOLD%%WHITE%  kolwarp - Starting %mode_name%%NC%
echo   %CYAN%══════════════════════════════════════════════════════════════%NC%
echo.
echo   %CYAN%Protocol:%NC% %protocol_name%
echo   %CYAN%Mode:%NC% %mode_name%
echo   %CYAN%Listen:%NC% %bind_addr%:%port%
echo.
echo %DIM%────────────────────────────────────────%NC%
echo   %DIM%Press Ctrl+C to stop%NC%
echo.

!cmd!
goto :main_menu

:do_account_info
if not exist "%KOLWARP_BIN%" (
    echo %RED%kolwarp binary not found at %KOLWARP_BIN%%NC%
    echo.
    echo   %DIM%Press any key to continue...%NC%
    pause >nul
    goto :main_menu
)
cls
echo.
echo %BLUE%╔═══ Account Information ═══╗%NC%
echo.

if not exist "%CONFIG_FILE%" (
    echo   %RED%No config found. Please register first.%NC%
) else (
    echo   %CYAN%Config File:%NC% %CONFIG_FILE%
    echo.
    if exist "%KOLWARP_BIN%" (
        "%KOLWARP_BIN%" account info
    ) else (
        echo   %DIM%Use './kolwarp account info' for detailed info%NC%
    )
)

echo.
echo   %DIM%Press any key to continue...%NC%
pause >nul
goto :main_menu

:do_about
cls
echo.
echo %BLUE%╔═══ About kolwarp ═══╗%NC%
echo.
echo   %BOLD%%WHITE%kolwarp%NC% - WARP MASQUE/WireGuard Client
echo   %DIM%Version: 1.0.0%NC%
echo.
echo   %BOLD%Features:%NC%
echo     %GREEN%•%NC% MASQUE protocol (HTTP/3 QUIC)
echo     %GREEN%•%NC% WireGuard protocol (userspace)
echo     %GREEN%•%NC% HTTP/2 fallback
echo     %GREEN%•%NC% Smart endpoint scanning
echo     %GREEN%•%NC% Multiple proxy modes
echo     %GREEN%•%NC% Cross-platform support
echo.
echo   %BOLD%Connect with us:%NC%
echo     %MAGENTA%Telegram:%NC%  @kolandjs1
echo     %BLUE%GitHub:%NC%    github.com/kolandone
echo     %CYAN%Project:%NC%   github.com/Diniboy1123/usque
echo.
echo   %BOLD%Credits:%NC%
echo     %DIM%Built on top of usque (github.com/Diniboy1123/usque)%NC%
echo     %DIM%Endpoint scanning inspired by BPB-Warp-Scanner%NC%
echo.
echo %DIM%────────────────────────────────────────%NC%
echo.
echo   %DIM%Press any key to continue...%NC%
pause >nul
goto :main_menu

:do_exit
echo.
echo   %CYAN%══════════════════════════════════════════════════════════════%NC%
echo   %BOLD%%WHITE%  Thanks for using kolwarp!%NC%
echo   %DIM%  Telegram: @kolandjs1 ^| GitHub: kolandone%NC%
echo   %CYAN%══════════════════════════════════════════════════════════════%NC%
echo.
exit /b 0

:apply_config
:: Apply endpoint to config using PowerShell
powershell -Command "(Get-Content '%CONFIG_FILE%') -replace '\"endpoint_v4\":\s*\"[^\"]*\"', '\"endpoint_v4\": \"%~1\"' | Set-Content '%CONFIG_FILE%'"
echo   %GREEN%✓ Endpoint %~1 applied to config%NC%
goto :eof

:get_prefix
if %1==0 set "prefix=188.114.96"
if %1==1 set "prefix=188.114.97"
if %1==2 set "prefix=188.114.98"
if %1==3 set "prefix=188.114.99"
if %1==4 set "prefix=162.159.192"
if %1==5 set "prefix=162.159.193"
if %1==6 set "prefix=162.159.195"
if %1==7 set "prefix=8.34.146"
if %1==8 set "prefix=8.39.214"
if %1==9 set "prefix=8.39.204"
if %1==10 set "prefix=8.6.112"
if %1==11 set "prefix=8.35.211"
if %1==12 set "prefix=8.39.125"
if %1==13 set "prefix=8.47.69"
goto :eof

:get_port
if %1==0 set "port=500"
if %1==1 set "port=854"
if %1==2 set "port=859"
if %1==3 set "port=864"
if %1==4 set "port=878"
if %1==5 set "port=880"
if %1==6 set "port=890"
if %1==7 set "port=891"
if %1==8 set "port=894"
if %1==9 set "port=903"
if %1==10 set "port=908"
if %1==11 set "port=928"
if %1==12 set "port=934"
if %1==13 set "port=939"
if %1==14 set "port=942"
if %1==15 set "port=943"
if %1==16 set "port=945"
if %1==17 set "port=946"
if %1==18 set "port=955"
if %1==19 set "port=968"
if %1==20 set "port=987"
if %1==21 set "port=988"
if %1==22 set "port=1002"
if %1==23 set "port=1010"
if %1==24 set "port=1014"
if %1==25 set "port=1018"
if %1==26 set "port=1070"
if %1==27 set "port=1074"
if %1==28 set "port=1180"
if %1==29 set "port=1387"
if %1==30 set "port=1701"
if %1==31 set "port=1843"
if %1==32 set "port=2371"
if %1==33 set "port=2408"
if %1==34 set "port=2506"
if %1==35 set "port=3138"
if %1==36 set "port=3476"
if %1==37 set "port=3581"
if %1==38 set "port=3854"
if %1==39 set "port=4177"
if %1==40 set "port=4198"
if %1==41 set "port=4233"
if %1==42 set "port=4500"
if %1==43 set "port=5279"
if %1==44 set "port=5956"
if %1==45 set "port=7103"
if %1==46 set "port=7152"
if %1==47 set "port=7156"
if %1==48 set "port=7281"
if %1==49 set "port=7559"
if %1==50 set "port=8319"
if %1==51 set "port=8742"
if %1==52 set "port=8854"
if %1==53 set "port=8886"
goto :eof

:download_kolwarp
echo   %CYAN%Downloading kolwarp...%NC%
echo.

set "arch=amd64"
if "%PROCESSOR_ARCHITECTURE%"=="ARM64" set "arch=arm64"
if "%PROCESSOR_ARCHITECTURE%"=="x86" set "arch=386"

curl -L -# -o "%SCRIPT_DIR%kolwarp.zip" "https://github.com/Kolandone/kolwarp/releases/latest/download/kolwarp-windows-%arch%.zip"

if %ERRORLEVEL% equ 0 (
    powershell -Command "Expand-Archive -Path '%SCRIPT_DIR%kolwarp.zip' -DestinationPath '%SCRIPT_DIR%' -Force"
    del "%SCRIPT_DIR%kolwarp.zip"
    echo   %GREEN%✓ kolwarp downloaded successfully%NC%
) else (
    echo   %RED%✗ Failed to download kolwarp%NC%
)
goto :eof
