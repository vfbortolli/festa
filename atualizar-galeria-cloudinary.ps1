$ErrorActionPreference = 'Stop'

$cloudName = (Read-Host 'Cloudinary cloud name').Trim()
$assetFolder = (Read-Host 'Nome da pasta no Cloudinary').Trim()
$apiKey = (Read-Host 'Cloudinary API key').Trim()
$secureApiSecret = Read-Host 'Cloudinary API secret' -AsSecureString

if ([string]::IsNullOrWhiteSpace($cloudName) -or
    [string]::IsNullOrWhiteSpace($assetFolder) -or
    [string]::IsNullOrWhiteSpace($apiKey)) {
    throw 'Cloud name, pasta e API key são obrigatórios.'
}

$secretPointer = [IntPtr]::Zero
try {
    $secretPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureApiSecret)
    $apiSecret = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($secretPointer)
    if ([string]::IsNullOrWhiteSpace($apiSecret)) {
        throw 'Cloudinary API secret é obrigatório.'
    }

    $authorizationValue = [Convert]::ToBase64String(
        [Text.Encoding]::UTF8.GetBytes("${apiKey}:$apiSecret")
    )
}
finally {
    if ($secretPointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($secretPointer)
    }
}
$apiSecret = $null
$secureApiSecret = $null

$fotos = [System.Collections.Generic.List[string]]::new()
$nextCursor = $null
$encodedFolder = [Uri]::EscapeDataString($assetFolder)

do {
    $uri = "https://api.cloudinary.com/v1_1/$cloudName/resources/by_asset_folder?asset_folder=$encodedFolder&max_results=500&fields=secure_url%2Cresource_type"
    if ($nextCursor) {
        $uri += "&next_cursor=$([Uri]::EscapeDataString($nextCursor))"
    }

    $resposta = Invoke-RestMethod -Method Get -Uri $uri -Headers @{
        Authorization = "Basic $authorizationValue"
    }

    foreach ($recurso in $resposta.resources) {
        if ($recurso.resource_type -eq 'image' -and
            -not [string]::IsNullOrWhiteSpace($recurso.secure_url)) {
            $fotos.Add($recurso.secure_url)
        }
    }

    $nextCursor = $resposta.next_cursor
} while ($nextCursor)

$authorizationValue = $null

if ($fotos.Count -eq 0) {
    throw "Nenhuma imagem encontrada diretamente na pasta '$assetFolder'."
}

$fotosDirectory = Join-Path $PSScriptRoot 'fotos'
if (-not (Test-Path -LiteralPath $fotosDirectory -PathType Container)) {
    throw "Pasta do site não encontrada: $fotosDirectory"
}

$manifestPath = Join-Path $fotosDirectory 'galeria.json'
if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
    $confirmacao = Read-Host "Isso vai substituir '$manifestPath'. Continuar? (s/N)"
    if ($confirmacao -notin @('s', 'S', 'sim', 'SIM')) {
        throw 'Operação cancelada; o manifesto existente foi mantido.'
    }
}

$json = ConvertTo-Json -InputObject $fotos.ToArray() -Depth 3
[System.IO.File]::WriteAllText(
    $manifestPath,
    $json,
    [System.Text.UTF8Encoding]::new($false)
)

Write-Host "Galeria atualizada com $($fotos.Count) imagens: $manifestPath"
