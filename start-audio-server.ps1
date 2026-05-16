Set-Location -LiteralPath "$PSScriptRoot"

try {
    $response = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:3001/intro.mp3" -Method Head -TimeoutSec 2
    if ($response.StatusCode -eq 200) {
        Write-Host "Audio/NPC server ja esta rodando em http://127.0.0.1:3001"
        return
    }
} catch {
    # Server is not responding; start it below.
}

node .\audio-server.js
