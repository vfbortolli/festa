$ErrorActionPreference = 'Stop'

$fotosDirectory = Join-Path $PSScriptRoot 'fotos'
if (-not (Test-Path -LiteralPath $fotosDirectory -PathType Container)) {
    throw "Pasta de fotos não encontrada: $fotosDirectory"
}

$extensoesSuportadas = @('.jpg', '.jpeg', '.png', '.webp', '.gif')
$nomesDasFotos = @(
    Get-ChildItem -LiteralPath $fotosDirectory -File |
        Where-Object { $extensoesSuportadas -contains $_.Extension.ToLowerInvariant() } |
        Sort-Object Name |
        ForEach-Object Name
)

if ($nomesDasFotos.Count -eq 0) {
    throw "Nenhuma foto JPG, JPEG, PNG, WEBP ou GIF foi encontrada em: $fotosDirectory"
}

$json = ConvertTo-Json -InputObject $nomesDasFotos -Depth 3
$manifestPath = Join-Path $fotosDirectory 'galeria.json'
[System.IO.File]::WriteAllText(
    $manifestPath,
    $json,
    [System.Text.UTF8Encoding]::new($false)
)

Write-Host "Lista da galeria atualizada com $($nomesDasFotos.Count) fotos: $manifestPath"
