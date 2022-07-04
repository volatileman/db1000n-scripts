$source = 'https://github.com/Arriven/db1000n/releases/latest/download/db1000n_windows_amd64.zip'
# Destination to save the file
$destination = '\db1000n.zip'
$folder = '\db1000n'
#Download the file
Invoke-WebRequest -Uri $source -OutFile $destination

Remove-Item $folder -Recurse -Force
Expand-Archive $destination -DestinationPath $folder

\db1000n\db1000n.exe
