@echo off

:: Set environment variables for x64
if not "%VSCMD_ARG_TGT_ARCH%" == "x64" (
	if not "%VSCMD_ARG_HOST_ARCH%" == "x64" (
		call vcvars64.bat
	)
)

:: Configure
call mk_config.bat %1

:: Run Ninja
echo Making %1 build...
ninja -v -C build_%1
