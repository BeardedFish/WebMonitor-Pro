# File Name:       Dockerfile
# Author:          Darian Benam <darian@darianbenam.com>
# Date Created:    Saturday, September 30, 2023
# Date Updated:    Saturday, September 30, 2023

FROM mcr.microsoft.com/powershell:latest

WORKDIR /apps/webmonitor-pro

RUN apt-get update && apt-get install -y cron && apt-get install -y nano

COPY templates/ ./templates/
COPY App.ps1 .
COPY AppConfig.json .
COPY SmtpConfig.json .

RUN chmod +x App.ps1

ADD /etc/crontab /etc/cron.d/webmonitor-pro

RUN chmod 644 /etc/cron.d/webmonitor-pro

RUN crontab /etc/cron.d/webmonitor-pro

CMD [ "cron", "-f" ]
