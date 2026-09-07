@echo off
rem ============================================================================
rem  (c) 2026 Gabriel Navarro Bruno - Todos os direitos reservados.
rem  Publicado apenas para fins de portfolio/avaliacao tecnica. Uso pessoal e
rem  leitura sao permitidos; copia, redistribuicao ou reuso (total ou parcial)
rem  em outro projeto exigem autorizacao expressa do autor. Veja LICENSE na
rem  raiz do repositorio.
rem ============================================================================
setlocal EnableExtensions
title KIT TECNICO v1
color 0B
set "TMPPS=%TEMP%\kit_tecnico_%RANDOM%.ps1"

echo Preparando o Kit Tecnico...
powershell -NoProfile -ExecutionPolicy RemoteSigned -Command "try { Get-Content -LiteralPath '%~f0' -Encoding UTF8 -ErrorAction Stop | Select-Object -Skip 38 | Set-Content -LiteralPath '%TMPPS%' -Encoding utf8 -ErrorAction Stop; Write-Host 'Preparado com sucesso.' -ForegroundColor Green } catch { Write-Host ('ERRO ao preparar: ' + $_.Exception.Message) -ForegroundColor Red }"

if not exist "%TMPPS%" (
    echo.
    echo ERRO: nao consegui preparar o arquivo do Kit.
    echo Copie a mensagem de erro acima e me avise.
    echo.
    pause
    exit /b 1
)

echo.
powershell -NoProfile -ExecutionPolicy RemoteSigned -File "%TMPPS%" -PastaKit "%~dp0"

del "%TMPPS%" >nul 2>&1

echo.
echo ============================================
echo  Kit Tecnico finalizado.
echo ============================================
pause
exit /b

rem PSSTART_MARKER
param([string]$PastaKit = "")

$ErrorActionPreference = 'SilentlyContinue'

# ===================== CONFIGURACAO =====================
if (-not $PastaKit -or -not (Test-Path $PastaKit)) { $PastaKit = "$env:USERPROFILE\Desktop" }
$pastaRelatorios = Join-Path $PastaKit "Relatorios"
if (-not (Test-Path $pastaRelatorios)) {
    try { New-Item -Path $pastaRelatorios -ItemType Directory -Force | Out-Null } catch { $pastaRelatorios = "$env:USERPROFILE\Desktop" }
}
$pastaFerramentas = Join-Path $PastaKit "Ferramentas"

$nomeMaquina = $env:COMPUTERNAME
$carimbo = Get-Date -Format "yyyy-MM-dd_HHmm"
$logfile = Join-Path $pastaRelatorios "$nomeMaquina`_$carimbo.txt"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

$script:achados = 0
$script:achadosBaixos = 0

# ===================== FUNCOES BASE =====================
function W {
    param($texto, $cor = "White", $alerta = $false, $prioridade = "Alta")
    if ($alerta -and $prioridade -eq "Baixa") {
        Write-Host $texto -ForegroundColor DarkYellow
        Add-Content -Path $logfile -Value "[ATENCAO] $texto"
        $script:achadosBaixos++
    } elseif ($alerta) {
        Write-Host $texto -ForegroundColor Red
        Add-Content -Path $logfile -Value "[PROBLEMA] $texto"
        $script:achados++
    } else {
        Write-Host $texto -ForegroundColor $cor
        Add-Content -Path $logfile -Value $texto
    }
}

function Secao($texto) {
    Write-Host ""
    Write-Host "====================================================================" -ForegroundColor Cyan
    Write-Host "  $texto" -ForegroundColor Cyan
    Write-Host "====================================================================" -ForegroundColor Cyan
    Add-Content -Path $logfile -Value ""
    Add-Content -Path $logfile -Value "==================== $texto ===================="
}

function Pausa {
    Write-Host ""
    Write-Host "Pressione ENTER para voltar ao menu..." -ForegroundColor DarkGray
    [void](Read-Host)
}

function ExigirAdmin {
    if (-not $isAdmin) {
        Write-Host ""
        Write-Host "  ESTA OPCAO PRECISA DE ADMINISTRADOR  " -ForegroundColor White -BackgroundColor Red
        Write-Host "Feche este programa e abra novamente com botao direito >" -ForegroundColor DarkYellow
        Write-Host "'Executar como administrador'." -ForegroundColor DarkYellow
        Pausa
        return $false
    }
    return $true
}

function CriarPontoRestauracao($descricao) {
    Write-Host ""
    Write-Host "Criando ponto de restauracao antes de mexer no sistema..." -ForegroundColor Cyan
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description $descricao -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Host "[OK] Ponto de restauracao criado." -ForegroundColor Green
        return $true
    } catch {
        Write-Host "[AVISO] Nao foi possivel criar ponto de restauracao." -ForegroundColor DarkYellow
        Write-Host "(O Windows limita a 1 a cada 24h, ou a Protecao do Sistema pode estar desligada.)" -ForegroundColor DarkGray
        $resp = Read-Host "Continuar mesmo assim? (S/N)"
        return ($resp -match '^[Ss]')
    }
}

# ===================== MODULO 1 - DIAGNOSTICO COMPLETO =====================
function Modulo-Diagnostico {
    Clear-Host
    $script:achados = 0
    $script:achadosBaixos = 0

    Secao "IDENTIFICACAO DA MAQUINA"
    try {
        $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        $bios = Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
        W "Nome do computador: $($cs.Name)" "White"
        W "Fabricante / Modelo: $($cs.Manufacturer) $($cs.Model)" "White"
        if ($bios) { W "Numero de serie: $($bios.SerialNumber)" "White" }
        if ($cpu) { W "Processador: $($cpu.Name.Trim()) ($($cpu.NumberOfCores) nucleos)" "White" }
        W "Memoria RAM total: $([math]::Round($cs.TotalPhysicalMemory/1GB,1)) GB" "White"
        if ($os) {
            W "Sistema: $($os.Caption) (build $($os.BuildNumber))" "White"
            $bootTime = $os.LastBootUpTime
            if ($bootTime) {
                $diasLigado = [math]::Round(((Get-Date) - $bootTime).TotalDays, 1)
                W "Ligado sem reiniciar ha: $diasLigado dia(s)" "White"
                if ($diasLigado -gt 7) {
                    W "A maquina esta ha mais de 7 dias sem reiniciar. Isso acumula lentidao (memoria nao liberada). Reiniciar costuma resolver bastante coisa." "DarkYellow" $true "Baixa"
                }
            }
        }
    } catch { W "Nao foi possivel ler os dados da maquina." "DarkGray" }

    Secao "MEMORIA RAM (SLOTS E EXPANSAO)"
    try {
        $pentes = @(Get-CimInstance Win32_PhysicalMemory -ErrorAction Stop)
        $slotsArray = Get-CimInstance Win32_PhysicalMemoryArray -ErrorAction SilentlyContinue | Select-Object -First 1
        $totalSlots = if ($slotsArray) { $slotsArray.MemoryDevices } else { "?" }
        W "Pentes instalados: $($pentes.Count) de $totalSlots slot(s)" "White"
        foreach ($p in $pentes) {
            $tipoMem = switch ($p.SMBIOSMemoryType) { 24 {"DDR3"} 26 {"DDR4"} 34 {"DDR5"} default {"Tipo $($p.SMBIOSMemoryType)"} }
            W "  Slot '$($p.DeviceLocator)': $([math]::Round($p.Capacity/1GB,0)) GB $tipoMem $($p.Speed)MHz - $($p.Manufacturer)" "White"
        }
        if ($totalSlots -ne "?" -and $pentes.Count -lt $totalSlots) {
            W "Ha $($totalSlots - $pentes.Count) slot(s) de memoria LIVRE(S). Da para expandir a RAM sem trocar o pente atual." "Green"
        }
        $ramGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB,0)
        if ($ramGB -le 4) {
            W "Apenas $ramGB GB de RAM. Isso e muito pouco para o Windows 11 - travamentos sao esperados. Upgrade de memoria e a melhor solucao." "Red" $true
        } elseif ($ramGB -le 8) {
            W "$ramGB GB de RAM. Suficiente para uso basico, mas trava com muitas abas/programas abertos ao mesmo tempo." "DarkYellow" $true "Baixa"
        }
    } catch { W "Nao foi possivel ler os pentes de memoria." "DarkGray" }

    Secao "SAUDE DO DISCO (SMART)"
    try {
        $discos = @(Get-PhysicalDisk -ErrorAction Stop)
        foreach ($d in $discos) {
            $tipo = if ($d.MediaType) { $d.MediaType } else { "Desconhecido" }
            $tam = [math]::Round($d.Size/1GB,0)
            $saude = $d.HealthStatus
            $linha = "Disco: $($d.FriendlyName) | $tipo | $tam GB | Saude: $saude"
            if ($saude -eq "Healthy") {
                W $linha "Green"
            } else {
                W "$linha  <<< O PROPRIO DISCO ESTA REPORTANDO FALHA. FACA BACKUP DOS DADOS AGORA e planeje a troca." "Red" $true
            }
            try {
                $rel = $d | Get-StorageReliabilityCounter -ErrorAction Stop
                if ($rel) {
                    if ($rel.PowerOnHours) {
                        $anos = [math]::Round($rel.PowerOnHours/8760,1)
                        W "  Horas ligado: $($rel.PowerOnHours)h (cerca de $anos ano(s) de uso real)" "White"
                    }
                    if ($rel.Wear -ne $null -and $rel.Wear -gt 0) {
                        W "  Desgaste do SSD: $($rel.Wear)%" $(if ($rel.Wear -gt 80) {"Red"} else {"White"})
                        if ($rel.Wear -gt 80) { W "  SSD com desgaste alto ($($rel.Wear)%). Comece a planejar a troca." "Red" $true }
                    }
                    if ($rel.ReadErrorsTotal -gt 0 -or $rel.WriteErrorsTotal -gt 0) {
                        W "  Erros de leitura: $($rel.ReadErrorsTotal) | Erros de escrita: $($rel.WriteErrorsTotal)" "Red" $true
                    }
                }
            } catch {}
        }
    } catch { W "Nao foi possivel ler a saude dos discos (precisa de administrador)." "DarkGray" }

    Secao "ESPACO EM DISCO"
    Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue | ForEach-Object {
        $livreGB = [math]::Round($_.FreeSpace/1GB,1)
        $totalGB = [math]::Round($_.Size/1GB,1)
        if ($totalGB -gt 0) {
            $pct = [math]::Round(($_.FreeSpace/$_.Size)*100,0)
            $txt = "Unidade $($_.DeviceID) - $livreGB GB livres de $totalGB GB ($pct% livre)"
            if ($pct -lt 10) {
                W "$txt  <<< Disco quase cheio. Abaixo de 10% livre o Windows fica MUITO lento e pode ate travar." "Red" $true
            } elseif ($pct -lt 20) {
                W "$txt  (pouco espaco livre - ja comeca a impactar o desempenho)" "DarkYellow" $true "Baixa"
            } else {
                W $txt "Green"
            }
        }
    }

    Secao "HISTORICO DE TELAS AZUIS E DESLIGAMENTOS INESPERADOS"
    $achouCrash = $false
    try {
        $minidumps = @(Get-ChildItem "$env:SystemRoot\Minidump\*.dmp" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 10)
        if ($minidumps.Count -gt 0) {
            $achouCrash = $true
            W "Encontrados $($minidumps.Count) arquivo(s) de tela azul (minidump). Os mais recentes:" "Red" $true
            foreach ($m in $minidumps | Select-Object -First 5) {
                W "  $($m.Name) - $($m.LastWriteTime.ToString('dd/MM/yyyy HH:mm'))" "White"
            }
            W "  (Os arquivos ficam em $env:SystemRoot\Minidump - abra com BlueScreenView para ver qual driver causou.)" "DarkGray"
        } else {
            W "Nenhum registro de tela azul encontrado em $env:SystemRoot\Minidump." "Green"
        }
    } catch {}

    if ($isAdmin) {
        try {
            $limite = (Get-Date).AddDays(-30)
            $kernelPower = @(Get-WinEvent -FilterHashtable @{LogName='System'; Id=41; StartTime=$limite} -ErrorAction SilentlyContinue)
            if ($kernelPower.Count -gt 0) {
                $achouCrash = $true
                W "$($kernelPower.Count) desligamento(s) inesperado(s) nos ultimos 30 dias (evento Kernel-Power 41)." "Red" $true
                W "  Isso significa que a maquina desligou/reiniciou sem avisar o Windows. Causas comuns: fonte fraca, superaquecimento, RAM com defeito ou driver ruim." "DarkYellow"
                foreach ($e in $kernelPower | Select-Object -First 3) {
                    W "  Ultimo: $($e.TimeCreated.ToString('dd/MM/yyyy HH:mm'))" "White"
                }
            }
            $whea = @(Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-WHEA-Logger'; StartTime=$limite} -ErrorAction SilentlyContinue)
            if ($whea.Count -gt 0) {
                $achouCrash = $true
                W "$($whea.Count) erro(s) de HARDWARE registrados (WHEA) nos ultimos 30 dias." "Red" $true
                W "  WHEA = o proprio processador/chipset reportou erro fisico. Suspeitar de RAM, CPU, superaquecimento ou fonte. Isso raramente e problema de software." "DarkYellow"
            }
            $errosCriticos = @(Get-WinEvent -FilterHashtable @{LogName='System'; Level=1; StartTime=$limite} -ErrorAction SilentlyContinue)
            if ($errosCriticos.Count -gt 0) {
                W "$($errosCriticos.Count) evento(s) CRITICO(S) no log do sistema nos ultimos 30 dias." "DarkYellow" $true "Baixa"
            }
        } catch {}
    } else {
        W "(Rode como administrador para ver o historico de eventos criticos do sistema.)" "DarkGray"
    }
    if (-not $achouCrash) { W "Nenhum sinal de travamento grave recente." "Green" }

    Secao "DRIVERS COM PROBLEMA"
    try {
        $comErro = @(Get-PnpDevice -ErrorAction Stop | Where-Object { $_.Status -eq 'Error' -or $_.Status -eq 'Degraded' })
        if ($comErro.Count -gt 0) {
            foreach ($dev in $comErro) {
                W "Dispositivo com problema: $($dev.FriendlyName) [$($dev.Class)] - Status: $($dev.Status)" "Red" $true
            }
            W "  (Abra o Gerenciador de Dispositivos e reinstale o driver desses itens.)" "DarkGray"
        } else {
            W "Nenhum dispositivo com erro no Gerenciador de Dispositivos." "Green"
        }
    } catch { W "Nao foi possivel verificar os drivers." "DarkGray" }

    Secao "TEMPERATURA"
    try {
        $temp = Get-CimInstance -Namespace "root/wmi" -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction Stop
        if ($temp) {
            foreach ($t in $temp) {
                $celsius = [math]::Round(($t.CurrentTemperature / 10) - 273.15, 1)
                if ($celsius -gt 0 -and $celsius -lt 130) {
                    if ($celsius -gt 85) {
                        W "Temperatura: $celsius C  <<< MUITO QUENTE. Provavel poeira no cooler ou pasta termica ressecada. Superaquecimento causa travamento e desligamento sozinho." "Red" $true
                    } elseif ($celsius -gt 70) {
                        W "Temperatura: $celsius C (esta alta - vale limpar o cooler)" "DarkYellow" $true "Baixa"
                    } else {
                        W "Temperatura: $celsius C (normal)" "Green"
                    }
                }
            }
        } else {
            W "Esta maquina nao expoe a temperatura via Windows. Use HWMonitor ou Core Temp para medir." "DarkGray"
        }
    } catch {
        W "Esta maquina nao expoe a temperatura via Windows. Use HWMonitor ou Core Temp para medir." "DarkGray"
    }

    Secao "BATERIA (NOTEBOOK)"
    try {
        $bat = Get-CimInstance Win32_Battery -ErrorAction Stop | Select-Object -First 1
        if ($bat) {
            W "Bateria detectada: $($bat.Name)" "White"
            W "Carga atual: $($bat.EstimatedChargeRemaining)%" "White"
            $estados = @{1="Descarregando"; 2="Na tomada"; 3="Carregada"; 4="Baixa"; 5="Critica"; 6="Carregando"; 7="Carregando (baixa)"; 8="Carregando (alta)"}
            if ($estados.ContainsKey([int]$bat.BatteryStatus)) { W "Estado: $($estados[[int]$bat.BatteryStatus])" "White" }
            try {
                $desenho = (Get-CimInstance -Namespace "root/wmi" -ClassName BatteryStaticData -ErrorAction Stop | Select-Object -First 1).DesignedCapacity
                $cheia = (Get-CimInstance -Namespace "root/wmi" -ClassName BatteryFullChargedCapacity -ErrorAction Stop | Select-Object -First 1).FullChargedCapacity
                if ($desenho -gt 0 -and $cheia -gt 0) {
                    $saudeBat = [math]::Round(($cheia / $desenho) * 100, 0)
                    if ($saudeBat -lt 60) {
                        W "Saude da bateria: $saudeBat% da capacidade original  <<< Bateria bem gasta, considere trocar." "Red" $true
                    } elseif ($saudeBat -lt 80) {
                        W "Saude da bateria: $saudeBat% da capacidade original (desgaste ja perceptivel)" "DarkYellow" $true "Baixa"
                    } else {
                        W "Saude da bateria: $saudeBat% da capacidade original (boa)" "Green"
                    }
                }
            } catch {}
            W "(Para o relatorio detalhado da bateria use a opcao de relatorio completo no menu.)" "DarkGray"
        } else {
            W "Nenhuma bateria detectada (provavelmente e um desktop)." "DarkGray"
        }
    } catch { W "Nenhuma bateria detectada (provavelmente e um desktop)." "DarkGray" }

    Secao "PROTECAO E ATUALIZACOES"
    try {
        $mp = Get-MpComputerStatus -ErrorAction Stop
        if ($mp.RealTimeProtectionEnabled) {
            W "Windows Defender - protecao em tempo real: LIGADA" "Green"
        } else {
            W "Windows Defender - protecao em tempo real: DESLIGADA. A maquina esta desprotegida." "Red" $true
        }
        W "Assinaturas de virus atualizadas em: $($mp.AntivirusSignatureLastUpdated)" "White"
    } catch { W "Nao foi possivel ler o status do Windows Defender." "DarkGray" }

    try {
        $updateSession = New-Object -ComObject Microsoft.Update.Session
        $searcher = $updateSession.CreateUpdateSearcher()
        $res = $searcher.Search("IsInstalled=0 and IsHidden=0")
        if ($res.Updates.Count -gt 0) {
            W "$($res.Updates.Count) atualizacao(oes) do Windows pendente(s)." "DarkYellow" $true "Baixa"
        } else {
            W "Windows esta em dia (nenhuma atualizacao pendente)." "Green"
        }
    } catch { W "Nao foi possivel verificar as atualizacoes do Windows." "DarkGray" }

    Secao "TOP 5 PROGRAMAS CONSUMINDO MEMORIA AGORA"
    Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 5 | ForEach-Object {
        W ("{0,-30} {1,8} MB" -f $_.ProcessName, [math]::Round($_.WorkingSet64/1MB,0)) "White"
    }

    # RESUMO
    Write-Host ""
    Write-Host "====================================================================" -ForegroundColor Cyan
    Write-Host "  RESUMO DO DIAGNOSTICO" -ForegroundColor Cyan
    Write-Host "====================================================================" -ForegroundColor Cyan
    Add-Content -Path $logfile -Value ""
    Add-Content -Path $logfile -Value "==================== RESUMO ===================="
    if ($script:achados -gt 0) {
        Write-Host ""
        Write-Host "  $($script:achados) PROBLEMA(S) QUE PRECISAM DE ATENCAO  " -ForegroundColor White -BackgroundColor Red
        Add-Content -Path $logfile -Value "$($script:achados) problema(s) que precisam de atencao."
    }
    if ($script:achadosBaixos -gt 0) {
        Write-Host ""
        Write-Host "  $($script:achadosBaixos) PONTO(S) DE MELHORIA - baixo risco  " -ForegroundColor Black -BackgroundColor DarkYellow
        Add-Content -Path $logfile -Value "$($script:achadosBaixos) ponto(s) de melhoria."
    }
    if ($script:achados -eq 0 -and $script:achadosBaixos -eq 0) {
        Write-Host ""
        Write-Host "  NENHUM PROBLEMA ENCONTRADO - MAQUINA SAUDAVEL  " -ForegroundColor White -BackgroundColor DarkGreen
        Add-Content -Path $logfile -Value "Nenhum problema encontrado."
    }
    Write-Host ""
    Write-Host "Relatorio salvo em:" -ForegroundColor Gray
    Write-Host $logfile -ForegroundColor Gray
    Pausa
}

# ===================== MODULO 2 - SCANNER DE VIRUS =====================
function Modulo-Scanner {
    Clear-Host
    Secao "SCANNER ANTI-MALWARE"
    $caminhoScanner = Join-Path $pastaFerramentas "SCANNER ANTI-MINERADOR v4.bat"
    if (Test-Path $caminhoScanner) {
        Write-Host "Abrindo o Scanner Anti-Minerador v4 (34 etapas)..." -ForegroundColor Cyan
        Write-Host "Ele abre em uma janela propria. Volte aqui quando terminar." -ForegroundColor DarkGray
        Start-Process -FilePath $caminhoScanner -Verb RunAs
    } else {
        Write-Host "Scanner nao encontrado." -ForegroundColor Red
        Write-Host ""
        Write-Host "Coloque o arquivo 'SCANNER ANTI-MINERADOR v4.bat' dentro da pasta:" -ForegroundColor DarkYellow
        Write-Host "  $pastaFerramentas" -ForegroundColor White
        Write-Host ""
        Write-Host "(Se a pasta nao existir, crie ela junto do KIT TECNICO.bat)" -ForegroundColor DarkGray
    }
    Pausa
}

# ===================== MODULO 3 - REPARO DO WINDOWS =====================
function Modulo-Reparo {
    Clear-Host
    Secao "REPARO DO WINDOWS"
    if (-not (ExigirAdmin)) { return }

    Write-Host "Este reparo executa, NESTA ORDEM (que e a ordem correta):" -ForegroundColor White
    Write-Host ""
    Write-Host "  1. DISM  - conserta a IMAGEM base do Windows (baixa arquivos da Microsoft)" -ForegroundColor Gray
    Write-Host "  2. SFC   - conserta os ARQUIVOS do sistema usando a imagem ja corrigida" -ForegroundColor Gray
    Write-Host "  3. CHKDSK- verifica erros no sistema de arquivos do disco" -ForegroundColor Gray
    Write-Host ""
    Write-Host "A ordem importa: rodar SFC antes do DISM e o erro mais comum, porque o" -ForegroundColor DarkYellow
    Write-Host "SFC repara usando uma imagem que pode estar corrompida tambem." -ForegroundColor DarkYellow
    Write-Host ""
    Write-Host "Tempo estimado: 15 a 40 minutos. Precisa de internet para o DISM." -ForegroundColor DarkYellow
    Write-Host ""
    $ok = Read-Host "Deseja continuar? (S/N)"
    if ($ok -notmatch '^[Ss]') { return }

    if (-not (CriarPontoRestauracao "Kit Tecnico - antes do reparo do Windows")) { return }

    Secao "ETAPA 1 de 3 - DISM (reparando a imagem do Windows)"
    Write-Host "Isso pode demorar bastante e parecer travado em 20%. E normal, aguarde." -ForegroundColor DarkYellow
    try {
        $saidaDism = & DISM.exe /Online /Cleanup-Image /RestoreHealth 2>&1 | Out-String
        Add-Content -Path $logfile -Value $saidaDism
        if ($saidaDism -match "operação foi concluída com êxito|operation completed successfully") {
            W "[OK] DISM concluido com sucesso - a imagem do Windows esta integra." "Green"
        } elseif ($saidaDism -match "0x800f081f") {
            W "DISM nao encontrou os arquivos de origem (erro 0x800f081f). Verifique a conexao com a internet." "Red" $true
        } else {
            W "DISM terminou, mas com avisos. Detalhes completos no relatorio." "DarkYellow" $true "Baixa"
        }
    } catch { W "Falha ao executar o DISM: $($_.Exception.Message)" "Red" $true }

    Secao "ETAPA 2 de 3 - SFC (reparando arquivos do sistema)"
    try {
        $saidaSfc = & sfc.exe /scannow 2>&1 | Out-String
        Add-Content -Path $logfile -Value $saidaSfc
        if ($saidaSfc -match "não encontrou nenhuma violação|did not find any integrity violations") {
            W "[OK] SFC: nenhum arquivo de sistema corrompido." "Green"
        } elseif ($saidaSfc -match "reparou com êxito|successfully repaired") {
            W "[OK] SFC encontrou arquivos corrompidos e REPAROU com sucesso." "Green"
        } elseif ($saidaSfc -match "não foi possível corrigir|was unable to fix") {
            W "SFC encontrou corrupcao que NAO conseguiu reparar. Guarde o relatorio - pode ser necessario reinstalar o Windows." "Red" $true
        } else {
            W "SFC finalizado. Veja os detalhes no relatorio." "White"
        }
    } catch { W "Falha ao executar o SFC: $($_.Exception.Message)" "Red" $true }

    Secao "ETAPA 3 de 3 - CHKDSK (verificando o disco)"
    Write-Host "Rodando em modo somente leitura (nao mexe em nada, so verifica)." -ForegroundColor DarkGray
    try {
        $saidaChk = & chkdsk.exe $env:SystemDrive /scan 2>&1 | Out-String
        Add-Content -Path $logfile -Value $saidaChk
        if ($saidaChk -match "não encontrou problemas|found no problems") {
            W "[OK] CHKDSK: nenhum problema no sistema de arquivos." "Green"
        } else {
            W "CHKDSK encontrou algo. Se aparecerem erros, rode 'chkdsk C: /f /r' e reinicie (demora horas)." "DarkYellow" $true "Baixa"
        }
    } catch { W "Falha ao executar o CHKDSK." "DarkGray" }

    Write-Host ""
    Write-Host "  REPARO CONCLUIDO - REINICIE A MAQUINA  " -ForegroundColor White -BackgroundColor DarkGreen
    Write-Host ""
    Write-Host "Relatorio salvo em: $logfile" -ForegroundColor Gray
    Pausa
}

# ===================== MODULO 4 - LIMPEZA E OTIMIZACAO =====================
function Modulo-Limpeza {
    Clear-Host
    Secao "LIMPEZA E OTIMIZACAO"

    Write-Host "Esta limpeza remove APENAS arquivos temporarios e caches." -ForegroundColor White
    Write-Host "Nenhum documento, foto ou programa seu e tocado." -ForegroundColor Green
    Write-Host ""
    $ok = Read-Host "Deseja continuar? (S/N)"
    if ($ok -notmatch '^[Ss]') { return }

    $totalLiberado = 0

    function LimparPasta($caminho, $rotulo) {
        if (-not (Test-Path $caminho)) { return 0 }
        $antes = 0
        try { $antes = (Get-ChildItem $caminho -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum } catch {}
        try {
            Get-ChildItem $caminho -Force -ErrorAction SilentlyContinue | ForEach-Object {
                Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
            }
        } catch {}
        $depois = 0
        try { $depois = (Get-ChildItem $caminho -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum } catch {}
        $liberado = [math]::Round(($antes - $depois)/1MB, 1)
        if ($liberado -lt 0) { $liberado = 0 }
        W "$rotulo - liberado: $liberado MB" "White"
        return $liberado
    }

    Secao "ARQUIVOS TEMPORARIOS"
    $totalLiberado += LimparPasta $env:TEMP "Temporarios do usuario"
    $totalLiberado += LimparPasta "$env:SystemRoot\Temp" "Temporarios do Windows"
    $totalLiberado += LimparPasta "$env:LOCALAPPDATA\Microsoft\Windows\INetCache" "Cache da internet"

    Secao "CACHE DO WINDOWS UPDATE"
    if ($isAdmin) {
        try {
            Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
            Stop-Service -Name bits -Force -ErrorAction SilentlyContinue
            $totalLiberado += LimparPasta "$env:SystemRoot\SoftwareDistribution\Download" "Cache do Windows Update"
            Start-Service -Name wuauserv -ErrorAction SilentlyContinue
            Start-Service -Name bits -ErrorAction SilentlyContinue
            W "Servicos do Windows Update reiniciados." "Green"
        } catch { W "Nao foi possivel limpar o cache do Windows Update." "DarkGray" }
    } else {
        W "(Rode como administrador para limpar o cache do Windows Update.)" "DarkGray"
    }

    Secao "LIXEIRA"
    try {
        $tamLixeira = 0
        try {
            $shell = New-Object -ComObject Shell.Application
            $lixeira = $shell.Namespace(0xA)
            $tamLixeira = [math]::Round((($lixeira.Items() | ForEach-Object { $_.Size }) | Measure-Object -Sum).Sum / 1MB, 1)
        } catch {}
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
        W "Lixeira esvaziada - liberado: $tamLixeira MB" "White"
        $totalLiberado += $tamLixeira
    } catch { W "Nao foi possivel esvaziar a lixeira." "DarkGray" }

    Secao "CACHE DE DNS"
    try {
        & ipconfig /flushdns | Out-Null
        W "[OK] Cache de DNS limpo. Isso corrige sites que nao abrem ou abrem errado." "Green"
    } catch { W "Nao foi possivel limpar o cache de DNS." "DarkGray" }

    Secao "PROGRAMAS QUE ABREM COM O WINDOWS"
    $totalStartup = 0
    $chavesRun = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"
    )
    foreach ($chave in $chavesRun) {
        if (Test-Path $chave) {
            $props = Get-ItemProperty -Path $chave -ErrorAction SilentlyContinue
            if ($props) {
                $props.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | ForEach-Object {
                    $totalStartup++
                    W "  $($_.Name)" "White"
                }
            }
        }
    }
    $pastaStartup = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
    if (Test-Path $pastaStartup) {
        Get-ChildItem $pastaStartup -File -ErrorAction SilentlyContinue | ForEach-Object {
            $totalStartup++
            W "  $($_.Name)" "White"
        }
    }
    W "Total de programas abrindo junto com o Windows: $totalStartup" "White"
    if ($totalStartup -gt 8) {
        W "Sao muitos itens. Cada um consome memoria desde o momento em que o PC liga." "DarkYellow" $true "Baixa"
        W "Desative os desnecessarios em: Configuracoes > Aplicativos > Inicializacao" "DarkYellow"
    }
    W "(Nao desativamos nada automaticamente - alguns podem ser importantes, como antivirus.)" "DarkGray"

    Write-Host ""
    Write-Host "  LIMPEZA CONCLUIDA - $([math]::Round($totalLiberado,0)) MB LIBERADOS  " -ForegroundColor White -BackgroundColor DarkGreen
    Pausa
}

# ===================== MODULO 5 - PREPARAR FORMATACAO =====================
function Modulo-Formatar {
    Clear-Host
    Secao "PREPARACAO PARA FORMATAR"

    Write-Host "  LEIA ANTES DE CONTINUAR  " -ForegroundColor White -BackgroundColor DarkRed
    Write-Host ""
    Write-Host "Este modulo NAO formata a maquina. E proposital, por dois motivos:" -ForegroundColor White
    Write-Host ""
    Write-Host " 1. Tecnicamente impossivel: o Windows nao consegue formatar o disco" -ForegroundColor Gray
    Write-Host "    em que ele mesmo esta rodando. Formatar exige dar boot pelo" -ForegroundColor Gray
    Write-Host "    pendrive de instalacao do Windows." -ForegroundColor Gray
    Write-Host ""
    Write-Host " 2. Seguranca: um botao 'formatar agora' em um kit de tecnico e a" -ForegroundColor Gray
    Write-Host "    forma mais facil de apagar a maquina do cliente errado por engano." -ForegroundColor Gray
    Write-Host ""
    Write-Host "O que ele faz e o trabalho que REALMENTE importa antes de formatar -" -ForegroundColor Green
    Write-Host "e que a maioria dos tecnicos esquece:" -ForegroundColor Green
    Write-Host ""
    Write-Host "   [1] Salvar a chave de ativacao do Windows" -ForegroundColor White
    Write-Host "   [2] Fazer BACKUP DOS DRIVERS da maquina (salva horas depois)" -ForegroundColor White
    Write-Host "   [3] Exportar a lista de programas instalados" -ForegroundColor White
    Write-Host "   [4] Mapear os dados do usuario e o tamanho de cada pasta" -ForegroundColor White
    Write-Host "   [5] Salvar as redes Wi-Fi e senhas configuradas" -ForegroundColor White
    Write-Host ""
    $ok = Read-Host "Deseja preparar a formatacao agora? (S/N)"
    if ($ok -notmatch '^[Ss]') { return }

    $pastaBackup = Join-Path $pastaRelatorios "$nomeMaquina`_PreFormatacao_$carimbo"
    try { New-Item -Path $pastaBackup -ItemType Directory -Force | Out-Null } catch {
        Write-Host "Nao foi possivel criar a pasta de backup em $pastaBackup" -ForegroundColor Red
        Pausa
        return
    }

    Secao "1 de 5 - CHAVE DE ATIVACAO DO WINDOWS"
    try {
        $chaveOem = (Get-CimInstance -ClassName SoftwareLicensingService -ErrorAction Stop).OA3xOriginalProductKey
        if ($chaveOem) {
            W "Chave OEM (gravada na BIOS): $chaveOem" "Green"
            Set-Content -Path (Join-Path $pastaBackup "chave_windows.txt") -Value "Chave OEM do Windows: $chaveOem`r`nMaquina: $nomeMaquina`r`nData: $(Get-Date)" -Encoding UTF8
        } else {
            W "Sem chave OEM na BIOS. Provavelmente a licenca e digital, vinculada a conta Microsoft." "DarkYellow"
            W "Nesse caso, apos formatar basta entrar com a mesma conta Microsoft que o Windows reativa sozinho." "White"
        }
    } catch { W "Nao foi possivel ler a chave do Windows." "DarkGray" }

    Secao "2 de 5 - BACKUP DOS DRIVERS"
    if ($isAdmin) {
        $pastaDrivers = Join-Path $pastaBackup "Drivers"
        try {
            New-Item -Path $pastaDrivers -ItemType Directory -Force | Out-Null
            Write-Host "Exportando drivers... (pode demorar alguns minutos)" -ForegroundColor DarkYellow
            $saida = & DISM.exe /Online /Export-Driver /Destination:"$pastaDrivers" 2>&1 | Out-String
            $qtd = @(Get-ChildItem $pastaDrivers -Directory -ErrorAction SilentlyContinue).Count
            if ($qtd -gt 0) {
                W "[OK] $qtd driver(s) salvos em: $pastaDrivers" "Green"
                W "Depois de formatar: Gerenciador de Dispositivos > botao direito no item sem driver >" "White"
                W "Atualizar driver > Procurar no meu computador > aponte para essa pasta." "White"
            } else {
                W "Nenhum driver exportado." "DarkYellow"
            }
        } catch { W "Falha ao exportar drivers: $($_.Exception.Message)" "Red" }
    } else {
        W "Precisa de administrador para exportar os drivers." "Red" $true
    }

    Secao "3 de 5 - PROGRAMAS INSTALADOS"
    try {
        $chavesUninstall = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
        )
        $programas = Get-ItemProperty -Path $chavesUninstall -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName } |
            Select-Object DisplayName, DisplayVersion, Publisher -Unique |
            Sort-Object DisplayName
        $arqProg = Join-Path $pastaBackup "programas_instalados.txt"
        $programas | Format-Table -AutoSize | Out-String -Width 200 | Set-Content -Path $arqProg -Encoding UTF8
        W "[OK] $($programas.Count) programa(s) listados em: programas_instalados.txt" "Green"
    } catch { W "Nao foi possivel listar os programas." "DarkGray" }

    Secao "4 de 5 - DADOS DO USUARIO (O QUE PRECISA SER SALVO)"
    $pastasUsuario = @("Desktop","Documents","Downloads","Pictures","Videos","Music")
    $totalDados = 0
    $listaDados = @()
    foreach ($pu in $pastasUsuario) {
        $caminho = Join-Path $env:USERPROFILE $pu
        if (Test-Path $caminho) {
            try {
                $tam = (Get-ChildItem $caminho -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                $tamGB = [math]::Round($tam/1GB, 2)
                $totalDados += $tamGB
                $qtdArq = @(Get-ChildItem $caminho -Recurse -Force -File -ErrorAction SilentlyContinue).Count
                W "$pu : $tamGB GB ($qtdArq arquivos)" "White"
                $listaDados += "$caminho -> $tamGB GB ($qtdArq arquivos)"
            } catch {}
        }
    }
    W "" "White"
    W "TOTAL DE DADOS DO USUARIO: $([math]::Round($totalDados,2)) GB" "Cyan"
    Set-Content -Path (Join-Path $pastaBackup "dados_para_backup.txt") -Value ($listaDados -join "`r`n") -Encoding UTF8

    if ($totalDados -gt 0) {
        Write-Host ""
        Write-Host "  ATENCAO: ESSES DADOS SERAO PERDIDOS NA FORMATACAO  " -ForegroundColor White -BackgroundColor DarkRed
        Write-Host ""
        Write-Host "Copie essas pastas para um HD externo ou nuvem ANTES de formatar." -ForegroundColor DarkYellow
        Write-Host "Nao copie para o pendrive do Windows - ele sera formatado tambem." -ForegroundColor DarkYellow
    }

    Secao "5 de 5 - REDES WI-FI SALVAS"
    try {
        $perfis = (& netsh wlan show profiles) | Select-String "Todos os Usuários|All User" | ForEach-Object {
            ($_ -split ":")[1].Trim()
        }
        $listaWifi = @()
        foreach ($perfil in $perfis) {
            if ($perfil) {
                $detalhe = (& netsh wlan show profile name="$perfil" key=clear)
                $senha = ($detalhe | Select-String "Conteúdo da Chave|Key Content" | ForEach-Object { ($_ -split ":")[1].Trim() })
                if ($senha) {
                    W "Rede: $perfil" "White"
                    $listaWifi += "Rede: $perfil | Senha: $senha"
                } else {
                    $listaWifi += "Rede: $perfil | (sem senha salva ou rede aberta)"
                }
            }
        }
        if ($listaWifi.Count -gt 0) {
            Set-Content -Path (Join-Path $pastaBackup "redes_wifi.txt") -Value ($listaWifi -join "`r`n") -Encoding UTF8
            W "[OK] $($listaWifi.Count) rede(s) Wi-Fi salvas em: redes_wifi.txt" "Green"
            W "(Esse arquivo contem SENHAS. Apague depois de reconfigurar a maquina.)" "DarkYellow"
        } else {
            W "Nenhuma rede Wi-Fi salva encontrada." "DarkGray"
        }
    } catch { W "Nao foi possivel exportar as redes Wi-Fi." "DarkGray" }

    Write-Host ""
    Write-Host "====================================================================" -ForegroundColor Green
    Write-Host "  PREPARACAO CONCLUIDA" -ForegroundColor Green
    Write-Host "====================================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Tudo salvo em:" -ForegroundColor White
    Write-Host "  $pastaBackup" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "PROXIMOS PASSOS PARA FORMATAR:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host " 1. Copie os dados do usuario para um HD externo (lista acima)" -ForegroundColor White
    Write-Host " 2. Confira que a pasta de backup acima esta em local SEGURO" -ForegroundColor White
    Write-Host "    (nao no disco que sera formatado!)" -ForegroundColor DarkYellow
    Write-Host " 3. Crie o pendrive de instalacao do Windows pelo site oficial da" -ForegroundColor White
    Write-Host "    Microsoft (Media Creation Tool)" -ForegroundColor White
    Write-Host " 4. Reinicie a maquina e aperte F2/F12/DEL para dar boot pelo pendrive" -ForegroundColor White
    Write-Host " 5. Depois de instalar, use a pasta Drivers do backup para reinstalar" -ForegroundColor White
    Write-Host "    tudo que o Windows nao reconhecer sozinho" -ForegroundColor White
    Write-Host ""
    Pausa
}

# ===================== MODULO 6 - RELATORIO COMPLETO =====================
function Modulo-RelatorioCompleto {
    Clear-Host
    Secao "RELATORIO COMPLETO PARA O CLIENTE"

    Write-Host "Gera os relatorios detalhados nativos do Windows:" -ForegroundColor White
    Write-Host "  - Bateria (desgaste, ciclos, historico de uso)" -ForegroundColor Gray
    Write-Host "  - Energia e desempenho" -ForegroundColor Gray
    Write-Host "  - Rede Wi-Fi (historico de conexoes e falhas)" -ForegroundColor Gray
    Write-Host "  - Lista completa de drivers com data" -ForegroundColor Gray
    Write-Host ""
    $ok = Read-Host "Gerar agora? (S/N)"
    if ($ok -notmatch '^[Ss]') { return }

    $pastaRel = Join-Path $pastaRelatorios "$nomeMaquina`_RelatorioCompleto_$carimbo"
    try { New-Item -Path $pastaRel -ItemType Directory -Force | Out-Null } catch {}

    Write-Host ""
    Write-Host "Gerando relatorio de bateria..." -ForegroundColor Cyan
    try {
        & powercfg /batteryreport /output "$pastaRel\bateria.html" 2>&1 | Out-Null
        if (Test-Path "$pastaRel\bateria.html") { W "[OK] bateria.html" "Green" } else { W "Sem bateria nesta maquina (desktop)." "DarkGray" }
    } catch { W "Nao foi possivel gerar o relatorio de bateria." "DarkGray" }

    Write-Host "Gerando relatorio de energia... (aguarde 60 segundos)" -ForegroundColor Cyan
    if ($isAdmin) {
        try {
            & powercfg /energy /output "$pastaRel\energia.html" /duration 60 2>&1 | Out-Null
            if (Test-Path "$pastaRel\energia.html") { W "[OK] energia.html" "Green" }
        } catch { W "Nao foi possivel gerar o relatorio de energia." "DarkGray" }
    } else {
        W "(Precisa de administrador para o relatorio de energia.)" "DarkGray"
    }

    Write-Host "Gerando relatorio de Wi-Fi..." -ForegroundColor Cyan
    try {
        & netsh wlan show wlanreport 2>&1 | Out-Null
        $origemWlan = "$env:SystemRoot\ProgramData\Microsoft\Windows\WlanReport\wlan-report-latest.html"
        if (-not (Test-Path $origemWlan)) { $origemWlan = "$env:ProgramData\Microsoft\Windows\WlanReport\wlan-report-latest.html" }
        if (Test-Path $origemWlan) {
            Copy-Item $origemWlan "$pastaRel\wifi.html" -Force
            W "[OK] wifi.html" "Green"
        }
    } catch { W "Nao foi possivel gerar o relatorio de Wi-Fi." "DarkGray" }

    Write-Host "Listando drivers..." -ForegroundColor Cyan
    try {
        & driverquery /v /fo table > "$pastaRel\drivers.txt" 2>&1
        W "[OK] drivers.txt" "Green"
    } catch { W "Nao foi possivel listar os drivers." "DarkGray" }

    Write-Host "Coletando informacoes do sistema..." -ForegroundColor Cyan
    try {
        & systeminfo > "$pastaRel\sistema.txt" 2>&1
        W "[OK] sistema.txt" "Green"
    } catch {}

    Write-Host ""
    Write-Host "  RELATORIOS GERADOS  " -ForegroundColor White -BackgroundColor DarkGreen
    Write-Host ""
    Write-Host "Pasta: $pastaRel" -ForegroundColor Cyan
    Write-Host "(Os arquivos .html abrem no navegador e sao otimos para mostrar ao cliente.)" -ForegroundColor DarkGray
    Pausa
}

# ===================== MENU PRINCIPAL =====================
function MostrarMenu {
    Clear-Host
    Write-Host ""
    Write-Host "############################################################" -ForegroundColor Yellow
    Write-Host "#                                                          #" -ForegroundColor Yellow
    Write-Host "#                  K I T   T E C N I C O                   #" -ForegroundColor Yellow
    Write-Host "#              Diagnostico e Reparo de Windows             #" -ForegroundColor Yellow
    Write-Host "#                                                          #" -ForegroundColor Yellow
    Write-Host "############################################################" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Maquina: $nomeMaquina" -ForegroundColor Gray
    if ($isAdmin) {
        Write-Host "  Modo: ADMINISTRADOR (todas as opcoes liberadas)" -ForegroundColor Green
    } else {
        Write-Host "  Modo: LIMITADO - varias opcoes nao vao funcionar!" -ForegroundColor Red
        Write-Host "  Feche e abra com botao direito > Executar como administrador" -ForegroundColor DarkYellow
    }
    Write-Host ""
    Write-Host "  ------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "   [1]  Diagnostico completo da maquina" -ForegroundColor White
    Write-Host "        Disco, RAM, temperatura, telas azuis, drivers, bateria" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "   [2]  Escanear virus e malware" -ForegroundColor White
    Write-Host "        Abre o Scanner Anti-Minerador (34 etapas)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "   [3]  Reparar o Windows" -ForegroundColor White
    Write-Host "        DISM + SFC + CHKDSK na ordem correta" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "   [4]  Limpeza e otimizacao" -ForegroundColor White
    Write-Host "        Temporarios, cache, DNS, lixeira, inicializacao" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "   [5]  Relatorio completo para o cliente" -ForegroundColor White
    Write-Host "        Bateria, energia, Wi-Fi e drivers em HTML" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "   [6]  Preparar formatacao" -ForegroundColor White
    Write-Host "        Salva chave, drivers, programas e mapeia os dados" -ForegroundColor DarkGray
    Write-Host "  ------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "   [0]  Sair" -ForegroundColor DarkYellow
    Write-Host ""
}

# ===================== LOOP PRINCIPAL =====================
Add-Content -Path $logfile -Value "===== KIT TECNICO - $nomeMaquina - $(Get-Date) ====="

do {
    MostrarMenu
    $escolha = Read-Host "  Escolha uma opcao"
    switch ($escolha.Trim()) {
        "1" { Modulo-Diagnostico }
        "2" { Modulo-Scanner }
        "3" { Modulo-Reparo }
        "4" { Modulo-Limpeza }
        "5" { Modulo-RelatorioCompleto }
        "6" { Modulo-Formatar }
        "0" { }
        default {
            Write-Host ""
            Write-Host "  Opcao invalida. Digite um numero de 0 a 6." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
} while ($escolha.Trim() -ne "0")

Write-Host ""
Write-Host "Ate a proxima!" -ForegroundColor Cyan
Write-Host "Relatorios desta sessao: $pastaRelatorios" -ForegroundColor Gray
Write-Host ""
