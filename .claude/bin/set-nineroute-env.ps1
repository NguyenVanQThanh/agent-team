<#
.SYNOPSIS
  Prompts for NINEROUTER_KEY / NINEROUTER_BASE_URL and sets them as
  persistent Windows user environment variables, read by
  .claude/bin/_runner.sh's runner_render_settings() for the Codex/DeepSeek
  dev lanes.

.EXAMPLE
  .\set-nineroute-env.ps1

.NOTES
  setx writes to HKCU (user scope) - no admin needed. Open a NEW terminal
  afterwards; the current shell does not see the change until then.
#>

$ErrorActionPreference = "Stop"

# Read-Host -AsSecureString and Get-Clipboard both failed to capture paste
# reliably in this console host. Plain Read-Host is PowerShell's standard
# paste path (no secure-string buffer, no clipboard API) - the key IS shown
# on screen while typing/pasting, but paste works correctly.
$key = Read-Host -Prompt "9router key (visible while typing)"
if ([string]::IsNullOrWhiteSpace($key)) { throw "empty key - aborted, nothing was set" }

$baseUrl = Read-Host -Prompt "9router base URL [https://9router.acegalaxy.co/v1]"
if ([string]::IsNullOrWhiteSpace($baseUrl)) { $baseUrl = "https://9router.acegalaxy.co/v1" }

setx NINEROUTER_KEY $key | Out-Null
setx NINEROUTER_BASE_URL $baseUrl | Out-Null
Remove-Variable key

Write-Host "Set NINEROUTER_KEY and NINEROUTER_BASE_URL as user env vars." -ForegroundColor Green
Write-Host "  NINEROUTER_BASE_URL = $baseUrl"
Write-Host ""
Write-Host "Open a NEW terminal (Git Bash / PowerShell) for these to take effect." -ForegroundColor Yellow
