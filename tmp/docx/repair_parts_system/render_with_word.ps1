param(
	[Parameter(Mandatory = $true)]
	[string]$InputDocx,
	[Parameter(Mandatory = $true)]
	[string]$OutputPdf
)

$docPath = [IO.Path]::GetFullPath($InputDocx)
$pdfPath = [IO.Path]::GetFullPath($OutputPdf)
$pdfDir = Split-Path -Parent $pdfPath
New-Item -ItemType Directory -Force -Path $pdfDir | Out-Null

$word = $null
$doc = $null
try {
	Write-Output "WORD_START"
	$word = New-Object -ComObject Word.Application
	$word.Visible = $false
	$word.DisplayAlerts = 0
	$word.AutomationSecurity = 3
	$word.Options.SaveNormalPrompt = $false
	$word.Options.ConfirmConversions = $false
	Write-Output "WORD_OPEN"
	$doc = $word.Documents.Open($docPath, $false, $true)
	Write-Output "WORD_EXPORT"
	$doc.ExportAsFixedFormat($pdfPath, 17)
	Write-Output "WORD_EXPORTED"
	$doc.Close($false)
	$doc = $null
	$word.Quit()
	$word = $null
	Write-Output "WORD_DONE"
}
finally {
	if ($null -ne $doc) {
		try { $doc.Close($false) } catch {}
	}
	if ($null -ne $word) {
		try { $word.Quit() } catch {}
	}
	[GC]::Collect()
	[GC]::WaitForPendingFinalizers()
}

Get-Item -LiteralPath $pdfPath | Select-Object FullName, Length, LastWriteTime
