FROM mcr.microsoft.com/windows/servercore:ltsc2016

COPY ./startup-script-win.ps1 ./

ENTRYPOINT ["powershell", "./startup-script-win.ps1"]
