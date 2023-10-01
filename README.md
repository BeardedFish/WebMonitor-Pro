# WebMonitor Pro

A PowerShell app that runs under a [Cron](https://en.wikipedia.org/wiki/Cron) job to check the uptime health of a custom range of website/web app services.

## Requirements

A minimum of [PowerShell 7.0](https://github.com/PowerShell/PowerShell/releases) must be installed in order to run this app.

## How to Run

Before you can run the app, you must ensure that the `SmtpConfig.json` file exists in the same directory as the `App.ps1` file. The structure of this file must look like this (example values may vary):

```json
{
	"$schema": "./SmtpConfig.schema.json",
	"Server": "smtp.example.com",
	"Port": 587,
	"Username": "noreply@example.com",
	"Password": "",
	"NoReplyEmailAddress": "noreply@example.com",
	"AlertReceiverEmailAddress": "admin@example.com"
}
```

### Host Machine

```console
pwsh ./App.ps1
```

### Docker

```
docker build -t darian-benam/webmonitor-pro .
docker run -d darian-benam/webmonitor-pro
```

**NOTE:** By default, `WebMonitor Pro` is scheduled to run every 12 hours according to it's `Cron` job configuration.
