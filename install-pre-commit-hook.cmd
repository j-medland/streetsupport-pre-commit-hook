:: mklink ".git/hooks/pre-commit" "../../git-hooks/pre-commit.sh"
:: Symlinks in windows don't seem to work and need admin privileges

:: write a file in .git/hooks which invokes the script in git-hooks

echo off
:: get the git-root without having to pipe to stdout to a tmp file
for /f "tokens=*" %%a in ('cmd /c "git rev-parse --show-toplevel"') do set ROOT=%%a
cd %ROOT%
set HOOKDIR="./.git/hooks"
set TARGET="%HOOKDIR%/pre-commit"

:: write file
echo #!/bin/sh > %TARGET%
echo # AUTOMATICALLY GENERATED FILE - DO NOT EDIT >> %TARGET%
echo # CALL GIT-HOOKS SCRIPT >> %TARGET%
echo ./git-hooks/pre-commit.sh >> %TARGET%

echo Pre-Commit Hook INSTALLED!