#!/usr/bin/env pwsh
#
# File Name:       App.ps1
# Author:          Darian Benam <darian@darianbenam.com>
# Date Created:    Saturday, September 30, 2023
# Date Updated:    Saturday, September 30, 2023

#Requires -Version 7.0

class WebService
{
	[string] $Endpoint
	[int] $ExpectedHttpResponseCode
	[int] $ReceivedHttpResponseCode
	[string] $ExceptionMessage

	WebService([string] $Endpoint, [int] $ExpectedHttpResponseCode, [int] $ReceivedHttpResponseCode)
	{
		$this.Endpoint = $Endpoint
		$this.ExpectedHttpResponseCode = $ExpectedHttpResponseCode
		$this.ReceivedHttpResponseCode = $ReceivedHttpResponseCode
	}

	WebService([string] $Endpoint, [int] $ExpectedHttpResponseCode, [int] $ReceivedHttpResponseCode, [string] $ExceptionMessage)
	{
		$this.Endpoint = $Endpoint
		$this.ExpectedHttpResponseCode = $ExpectedHttpResponseCode
		$this.ReceivedHttpResponseCode = $ReceivedHttpResponseCode
		$this.ExceptionMessage = $ExceptionMessage
	}
}

function Get-WebServiceProNotificationEmailBody($AppConfig, $WebServiceProblemList)
{
	$NotificationEmailBody = Get-Content -Path $AppConfig.NotificationEmailTemplatePath -Raw

	$WebServiceListHtml = '<ul>'

	foreach ($WebService in $WebServiceProblemList)
	{
		$WebServiceListHtml += "<li><a href=`"$($WebService.Endpoint)`" target=`"_blank`" rel=`"noopener`">$($WebService.Endpoint)</a> returned HTTP status code <strong>$($WebService.ReceivedHttpResponseCode)</strong> but <strong>$($WebService.ExpectedHttpResponseCode)</strong> was expected.</li>"
	}

	$WebServiceListHtml += '</ul>'

	$NotificationEmailBody = $NotificationEmailBody -Replace '{{ WEB_SERVICE_LIST }}', $WebServiceListHtml

	return $NotificationEmailBody
}

function Send-WebServiceProNotification($AppConfig, $SmtpConfig, $WebServiceProblemList)
{
	try
	{
		$NotificationEmailBody = Get-WebServiceProNotificationEmailBody -AppConfig $AppConfig -WebServiceProblemList $WebServiceProblemList

		$SmtpPassword = ConvertTo-SecureString $SmtpConfig.Password -AsPlainText -Force
		$SmtpCredential = New-Object System.Management.Automation.PSCredential ($SmtpConfig.Username, $SmtpPassword)

		Send-MailMessage -ErrorAction Stop -WarningAction SilentlyContinue -SmtpServer $SmtpConfig.Server -Port $SmtpConfig.Port -Credential $SmtpCredential -UseSsl -From $SmtpConfig.NoReplyEmailAddress -To $SmtpConfig.AlertReceiverEmailAddress -Subject '[WebMonitor Pro] Problem(s) Detected' -Body $NotificationEmailBody -BodyAsHtml

		return $null
	}
	catch
	{
		return $_
	}
}

Push-Location $PSScriptRoot

Write-Output "================"
Write-Output " WebMonitor Pro "
Write-Output "================`n"

Write-Output "Current Date: $(Get-Date)`n"

$AppConfigFilePath = './AppConfig.json'
$SmtpConfigFilePath = './SmtpConfig.json'

if (-not (Test-Path -Path $AppConfigFilePath))
{
	Write-Output "ERROR: `"$AppConfigFilePath`" is missing! Aborting...`n"
	exit 1
}

if (-not (Test-Path -Path $SmtpConfigFilePath))
{
	Write-Output "ERROR: `"$SmtpConfigFilePath`" is missing! Aborting...`n"
	exit 1
}

$AppConfig = Get-Content -Path './AppConfig.json' -Raw | ConvertFrom-Json
$SmtpConfig = Get-Content -Path './SmtpConfig.json' -Raw | ConvertFrom-Json
$WebServiceAuditList = New-Object System.Collections.Generic.List[WebService]

foreach ($Service in $AppConfig.Services)
{
	$Endpoint = $Service.Endpoint
	$ExpectedHttpResponseCode = $Service.ExpectedHttpResponseCode

	try
	{
		Write-Output "Checking: $Endpoint"

		$WebRequestResponse = Invoke-WebRequest -SkipHttpErrorCheck -Uri $Endpoint -Method Head -Headers `
		@{
			'User-Agent' = "WebMonitor Pro/v$($AppConfig.WebMonitorProVersion) (+https://github.com/BeardedFish/WebMonitor-Pro)"
		}

		$WebRequestResponseStatusCode = $WebRequestResponse.StatusCode

		$WebServiceAuditList.Add([WebService]::new($Endpoint, $ExpectedHttpResponseCode, $WebRequestResponseStatusCode)) | Out-Null
	}
	catch
	{
		$WebServiceAuditList.Add([WebService]::new($Endpoint, $ExpectedHttpResponseCode, $_.Exception.Response.StatusCode.Value__, $_.Exception.Message)) | Out-Null
	}
}

$WebServiceAuditList | Format-Table -Property Endpoint, ExpectedHttpResponseCode, ReceivedHttpResponseCode, ExceptionMessage

$WebServiceProblemList = $WebServiceAuditList | Where-Object `
{
	$_.ExpectedHttpResponseCode -ne $_.ReceivedHttpResponseCode
}

if ($WebServiceProblemList.Count -gt 0)
{
	Write-Output "WARNING: $($WebServiceProblemList.Count) issue(s) detected"

	$ExceptionMessage = Send-WebServiceProNotification -AppConfig $AppConfig -SmtpConfig $SmtpConfig -WebServiceProblemList $WebServiceProblemList

	if ($null -eq $ExceptionMessage)
	{
		Write-Output "Notification has been sent to administrator successfully!`n"
	}
	else
	{
		Write-Output "Failed to send notification to administrator! Reason: $ExceptionMessage`n"
	}
}
else
{
	Write-Output "All Systems Operational`n"
}

Pop-Location
