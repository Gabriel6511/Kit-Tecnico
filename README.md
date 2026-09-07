# Kit Técnico

Kit de suporte técnico para atendimento presencial em computadores Windows, feito para rodar direto de um pendrive na máquina do cliente. Criado a partir da rotina real de atendimento técnico (suporte de TI/A&V), reunindo em um único menu as ferramentas que antes eram usadas separadamente.

## O que faz

Um menu único (`KIT TECNICO.bat`) com:

- **Diagnóstico completo** — somente leitura: modelo/serial da máquina, RAM e slots livres, saúde SMART do disco, espaço livre, histórico de telas azuis (minidumps), desligamentos inesperados, erros de hardware (WHEA), drivers com erro, temperatura, saúde da bateria, status do Defender e atualizações pendentes.
- **Scanner de vírus/mineradores** — abre o Scanner Anti-Minerador (ver abaixo) em janela própria.
- **Reparo do Windows** — cria ponto de restauração e roda `DISM` → `SFC` → `CHKDSK`, nessa ordem (a ordem importa: rodar `SFC` antes do `DISM` é o erro mais comum, porque o `SFC` repara usando uma imagem que pode estar corrompida também).
- **Limpeza e otimização** — remove temporários e caches (Windows Update, DNS, lixeira) sem tocar em documentos, fotos ou programas do usuário.
- **Relatório para o cliente** — gera um `.html` legível com bateria, energia, histórico de Wi-Fi e drivers, para justificar o serviço prestado.
- **Preparação para formatação** — antes de formatar, salva a chave do Windows, faz backup de todos os drivers, exporta a lista de programas instalados, mapeia o tamanho dos dados do usuário e salva as redes Wi-Fi salvas (com senha, recuperada do próprio perfil de rede da máquina) — nada disso é recuperável depois do format.
- **Emergência (WinPE)** — scripts para montar um ambiente Windows PE de emergência num pendrive, para recuperação quando o Windows não inicia mais.

Todos os relatórios são salvos no próprio pendrive, em uma pasta `Relatorios/`, com o nome da máquina e a data — o que dá um histórico de todos os atendimentos feitos, não só o mais recente.

## Como usar

1. Copie os arquivos para a raiz de um pendrive (a pasta `Ferramentas/` precisa ficar ao lado de `KIT TECNICO.bat`).
2. Na máquina do cliente, execute `KIT TECNICO.bat` como administrador.
3. Escolha a opção desejada no menu.

Instruções completas em [`LEIA-ME - Como montar o pendrive.txt`](<LEIA-ME - Como montar o pendrive.txt>).

## Stack

Batch (`.bat`/`.cmd`) e PowerShell — escolhido de propósito para rodar sem instalar nada em qualquer Windows, inclusive no ambiente restrito de um WinPE de emergência.

## Aviso

Feito para uso em atendimentos reais de suporte técnico. As opções que alteram o sistema (reparo, limpeza, preparação para formatação) avisam antes de agir e, quando aplicável, criam ponto de restauração — mas devem ser usadas por quem entende o que cada etapa faz.

## Licença

Repositório público apenas para fins de portfólio/avaliação técnica — veja [`LICENSE`](LICENSE). Leitura e uso pessoal são livres; cópia, redistribuição ou reuso do código em outro projeto exigem autorização do autor.
