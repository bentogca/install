# ====================================================================
#  SCRIPT DE AUTO INSTALACAO - COMPATIVEL COM IWR | IEX
#  DEVE SER EXECUTADO COMO ADMINISTRADOR
# ====================================================================

Clear-Host
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "      ASSISTENTE DE CONFIGURACAO - INICIO     " -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# -------------------------------------------------------------
# CONFIGURACOES FIXAS
# -------------------------------------------------------------
$NetworkSourceServer = "172.16.2.73"
$NetworkShareName    = "Conexo"
$NetworkSourcePath   = "func\TI\TI-Carlos\apps"
$MappedDrive         = "F:"
$Domain_Name         = "atacado.local"

# Caminhos de destino
$DestERP        = "C:\erp"
$DestRetaguarda = "C:\retaguarda"
$DestApps       = "C:\Users\Public\Desktop\apps"

# Caminho UNC
$UNC = "\\$NetworkSourceServer\$NetworkShareName"

# -------------------------------------------------------------
# 1. NOME DO USUARIO / NOME DA MAQUINA
# -------------------------------------------------------------
$UserInput = Read-Host "Digite o NOME DE USUARIO (ex: joao.silva)"

if ([string]::IsNullOrWhiteSpace($UserInput)) {
    Write-Host "ERRO: Nome nao pode ser vazio." -ForegroundColor Red
    Exit 1
}

$NewComputerName = "PC-$($UserInput.ToUpper().Replace('.', '-'))"
Write-Host "Nome da maquina definido como $NewComputerName" -ForegroundColor Green

# -------------------------------------------------------------
# 2. CREDENCIAIS DO AD
# -------------------------------------------------------------
Write-Host "`nDigite credenciais com permissao para ingressar no dominio $Domain_Name"
$ADUser     = Read-Host "Usuario (ex: admin_ad)"
$ADPassword = Read-Host -AsSecureString "Senha"

$ADCredential = New-Object System.Management.Automation.PSCredential ($ADUser, $ADPassword)

# Converte senha para texto claro para mapear o drive (WScript.Network nao aceita SecureString)
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ADPassword)
$PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($BSTR)

# -------------------------------------------------------------
# 3. MAPEAR DRIVE F (COM CREDENCIAIS) OU USAR UNC
# -------------------------------------------------------------
Write-Host "`n--- 3. MAPEANDO DRIVE F ---" -ForegroundColor Yellow

$UsarUNC = $false
$NetworkSource = $null

try {
    $WshNetwork = New-Object -ComObject WScript.Network
    $WshNetwork.RemoveNetworkDrive($MappedDrive, $true, $true) 2>$null

    Write-Host "Tentando mapear $MappedDrive para $UNC com usuario $ADUser ..." -ForegroundColor Cyan
    $WshNetwork.MapNetworkDrive($MappedDrive, $UNC, $false, $ADUser, $PlainPassword)

    Write-Host "Drive F mapeado com sucesso -> $UNC" -ForegroundColor Green

    # Se mapeou, origem vira F:\func\...
    $NetworkSource = Join-Path -Path $MappedDrive -ChildPath $NetworkSourcePath
}
catch {
    Write-Host "ERRO ao mapear F: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Tentando usar caminho UNC diretamente..." -ForegroundColor Yellow
    $UsarUNC = $true
}

# Limpa senha em texto claro da memoria
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR) | Out-Null
$PlainPassword = $null

if ($UsarUNC) {
    $NetworkSource = Join-Path -Path $UNC -ChildPath $NetworkSourcePath
}

Write-Host "Origem de arquivos definida como: $NetworkSource" -ForegroundColor Cyan

# -------------------------------------------------------------
# 4. COPIAR ARQUIVOS
# -------------------------------------------------------------
Write-Host "`n--- 4. COPIANDO ARQUIVOS ---" -ForegroundColor Yellow

New-Item -Path $DestERP, $DestRetaguarda, $DestApps -ItemType Directory -Force | Out-Null

if (-Not (Test-Path $NetworkSource)) {
    Write-Host "ERRO FATAL: Caminho nao encontrado -> $NetworkSource" -ForegroundColor Red
    Exit 1
}

try {
    Write-Host "Copiando pasta ERP..." -ForegroundColor Cyan
    Copy-Item -Path (Join-Path $NetworkSource "erp") -Destination $DestERP -Recurse -Force

    Write-Host "Copiando pasta RETAGUARDA..." -ForegroundColor Cyan
    Copy-Item -Path (Join-Path $NetworkSource "retaguarda") -Destination $DestRetaguarda -Recurse -Force

    Write-Host "Copiando demais apps para Desktop Publico..." -ForegroundColor Cyan
    Get-ChildItem -Path $NetworkSource -Exclude "erp","retaguarda" |
        ForEach-Object {
            Copy-Item -Path $_.FullName -Destination $DestApps -Recurse -Force
        }

    Write-Host "Copias concluidas com sucesso!" -ForegroundColor Green
}
catch {
    Write-Host "ERRO AO COPIAR ARQUIVOS: $($_.Exception.Message)" -ForegroundColor Red
    Exit 1
}

# -------------------------------------------------------------
# 5. INGRESSAR NO DOMINIO (SEM REINICIAR AUTOMATICO)
# -------------------------------------------------------------
Write-Host "`n--- 5. INGRESSANDO NO DOMINIO ---" -ForegroundColor Yellow

try {
    Add-Computer -DomainName $Domain_Name -NewName $NewComputerName -Credential $ADCredential -ErrorAction Stop
    Write-Host "Computador ingressado no dominio com sucesso." -ForegroundColor Green
    Write-Host "Reinicie o equipamento manualmente para aplicar as alteracoes." -ForegroundColor Yellow
}
catch {
    Write-Host "ERRO: Nao foi possivel ingressar no dominio." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Exit 1
}

Write-Host "`nScript concluido." -ForegroundColor Cyan
Read-Host "Pressione ENTER para sair"
