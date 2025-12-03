# ====================================================================
#  SCRIPT DE AUTO INSTALAÇÃO - SEM CONFIGURAÇÃO DE REDE
#  DEVE SER EXECUTADO COMO ADMINISTRADOR!
# --------------------------------------------------------------------

Clear-Host
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "      ASSISTENTE DE CONFIGURAÇÃO - INÍCIO     " -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# -------------------------------------------------------------
# CONFIGURAÇÕES FIXAS
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

# Caminho origem
$NetworkSource = Join-Path -Path $MappedDrive -ChildPath $NetworkSourcePath

# -------------------------------------------------------------
# 1. NOME DO USUÁRIO / NOME DA MÁQUINA
# -------------------------------------------------------------
$UserInput = Read-Host "Digite o NOME DE USUÁRIO (ex: joao.silva)"

if ([string]::IsNullOrWhiteSpace($UserInput)) {
    Write-Host "ERRO: Nome não pode ser vazio." -ForegroundColor Red
    Exit 1
}

$NewComputerName = "PC-$($UserInput.ToUpper().Replace('.', '-'))"
Write-Host "Nome da máquina definido como: $NewComputerName" -ForegroundColor Green

# -------------------------------------------------------------
# 2. CREDENCIAIS DO AD
# -------------------------------------------------------------
Write-Host "`nDigite credenciais com permissão para ingressar no domínio $Domain_Name:"
$ADUser     = Read-Host "Usuário (ex: admin_ad)"
$ADPassword = Read-Host -AsSecureString "Senha"

$ADCredential = New-Object System.Management.Automation.PSCredential ($ADUser, $ADPassword)

# -------------------------------------------------------------
# 3. MAPEAR DRIVE F:
# -------------------------------------------------------------
Write-Host "`n--- 3. MAPEANDO DRIVE F: ---" -ForegroundColor Yellow

try {
    $WshNetwork = New-Object -ComObject WScript.Network
    $WshNetwork.RemoveNetworkDrive($MappedDrive, $true, $true) 2>$null
    $WshNetwork.MapNetworkDrive($MappedDrive, $UNC)

    Write-Host "Drive F: mapeado com sucesso → $UNC" -ForegroundColor Green
}
catch {
    Write-Host "ERRO: Não foi possível mapear F:. Tentando acesso direto ao UNC." -ForegroundColor Red
}

# -------------------------------------------------------------
# 4. COPIAR ARQUIVOS
# -------------------------------------------------------------
Write-Host "`n--- 4. COPIANDO ARQUIVOS ---" -ForegroundColor Yellow

# Criar pastas
New-Item -Path $DestERP, $DestRetaguarda, $DestApps -ItemType Directory -Force | Out-Null

# Testar origem
if (-Not (Test-Path $NetworkSource)) {
    Write-Host "ERRO FATAL: Caminho não encontrado → $NetworkSource" -ForegroundColor Red
    Exit 1
}

try {
    Write-Host "Copiando pasta ERP..." -ForegroundColor Cyan
    Copy-Item -Path (Join-Path $NetworkSource "erp") -Destination $DestERP -Recurse -Force

    Write-Host "Copiando pasta RETAGUARDA..." -ForegroundColor Cyan
    Copy-Item -Path (Join-Path $NetworkSource "retaguarda") -Destination $DestRetaguarda -Recurse -Force

    Write-Host "Copiando demais apps para Desktop Público..." -ForegroundColor Cyan
    Get-ChildItem -Path $NetworkSource -Exclude "erp", "retaguarda" |
        ForEach-Object {
            Copy-Item -Path $_.FullName -Destination $DestApps -Recurse -Force
        }

    Write-Host "Cópias concluídas com sucesso!" -ForegroundColor Green
}
catch {
    Write-Host "ERRO FATAL AO COPIAR ARQUIVOS: $($_.Exception.Message)" -ForegroundColor Red
    Exit 1
}

# -------------------------------------------------------------
# 5. INGRESSAR NO AD E REINICIAR
# -------------------------------------------------------------
Write-Host "`n--- 5. INGRESSANDO NO DOMÍNIO ---" -ForegroundColor Yellow

try {
    Add-Computer -DomainName $Domain_Name -NewName $NewComputerName -Credential $ADCredential -Restart -Force
}
catch {
    Write-Host "ERRO: Falha ao ingressar no domínio." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Exit 1
}
