# Workflow n8n - import, binding de credenciais e teste

> Fluxo diario: busca vagas (SerpAPI/Google Jobs) -> normaliza + dedup (contra as abas *Vagas* e
> *Reprovadas*) -> pre-filtro de relevancia + cap por rodada (TPM-safe) -> pontua no **Groq**
> (match 0-100 + trava de ingles + carta ancorada no CV + faixa salarial) -> filtra `match >= limiar`
> **E** `ingles in (nenhum, basico)` -> registra na planilha + notifica no Telegram. Erro no fluxo
> dispara alerta no Telegram.

O arquivo importavel e o **`workflow.json`** na raiz do repo (export sanitizado da instancia viva;
IDs pessoais e credenciais vem como placeholders).

## Identificadores (preencha com os SEUS - nao sao os valores reais do autor)
- Spreadsheet ID: `YOUR_SPREADSHEET_ID` (id da sua planilha do Google)
- Telegram chat_id: `YOUR_TELEGRAM_CHAT_ID` (seu chat/grupo de destino)
- LLM de scoring: **Groq** (`openai/gpt-oss-120b`) - free tier com limite de 8000 TPM/min.
  (Gemini free = ~20 req/dia, inviavel p/ scoring por vaga.)
- Service account do Google Sheets: `SEU_SERVICE_ACCOUNT@seu-projeto.iam.gserviceaccount.com`
  (compartilhe a planilha como **Editor** com esse e-mail).

## 1. Importar o workflow
1. Abra o seu n8n e logue (conta owner).
2. Topo direito **...** > **Import from File** > selecione `workflow.json`.
3. O workflow "Monitor Inteligente de Vagas Tech" abre com **17 nos**. As credenciais aparecem
   como **"nao selecionada"** (vermelho) - e esperado; crie e vincule agora.

## 2. Criar e vincular as 4 credenciais (no painel do n8n)

> Os SEGREDOS (keys/token/JSON) sao colados aqui no n8n - nunca no repo nem no chat.

### 2.1 SerpAPI  (no "SerpAPI (Google Jobs)")
- Tipo: **Query Auth** (`httpQueryAuth`). Nome sugerido: `SerpAPI (query key)`.
- **Name:** `api_key`  |  **Value:** sua Private API Key do serpapi.com
- No no, confirme: Authentication = *Generic Credential Type* / Generic Auth Type = *Query Auth*.

### 2.2 Groq  (no "Groq Chat Model")
- Tipo: **Groq API** (`groqApi`). Nome: `Groq API`. Crie a key em https://console.groq.com > API Keys.
- **Model:** `openai/gpt-oss-120b` (modo Fixed; se o dropdown vier incompleto, digite o id).
- Retry do no "Scoring (Model IA)": Max Tries 5 / Wait 5000ms (rede de seguranca p/ 429 esporadico).

### 2.3 Telegram  (nos "Notificar Telegram" e "Alerta de falha (Telegram)")
- Tipo: **Telegram API** (`telegramApi`). Nome: `Telegram Bot`.
- **Access Token:** token do @BotFather.
- Vincule a MESMA credencial nos DOIS nos Telegram.

### 2.4 Google Sheets - Service Account  (nos "Ler Vagas Existentes", "Ler Reprovadas",
"Registrar na planilha", "Registrar Reprovada")
- Tipo: **Google API** (`googleApi`), autenticacao **Service Account**. Nome: `Google Service Account`.
- **Service Account Email:** o e-mail do seu service account.
- **Private Key:** cole o campo `private_key` do JSON baixado (o bloco
  `-----BEGIN PRIVATE KEY----- ... -----END PRIVATE KEY-----` inteiro).
- **"Impersonate a User"? NAO** (o acesso vem do compartilhamento da planilha).
- Vincule a MESMA credencial nos QUATRO nos de planilha.

## 3. Reconfirmar os seletores de planilha
Em cada no Google Sheets, confirme o **documento** (pelo ID) e a **aba (sheet)**:
- "Ler Vagas Existentes" e "Registrar na planilha" -> aba **Vagas**
- "Ler Reprovadas" e "Registrar Reprovada" -> aba **Reprovadas**

A planilha precisa das abas **Vagas** e **Reprovadas** com os cabecalhos das colunas (ver README).
Se o dropdown da aba estiver vazio, clique para recarregar (lista as abas via a credencial).

## 4. Config do workflow (no "Config")
Parametros editaveis sem tocar em codigo:
- `keywords`: lista de cargos-alvo separada por virgula (termos de IA em **portugues** funcionam
  melhor no Google Jobs BR; termos só em ingles costumam voltar vazios).
- `location`: `Brazil` (cobre o pais).
- `match_minimo`: limiar de aprovacao (ex: `70`).
- `ingles_permitido`: `nenhum,basico` (trava de idioma).

> **Throughput x TPM:** o no "Filtrar Novas" corta em N vagas por rodada (`.slice(0, N)`) para nao
> estourar o teto de 8000 TPM/min da Groq (cada vaga ~2100 tokens -> ~3 por rajada). Para mais
> volume/dia, prefira **mais rodadas** no Agendador a uma rajada maior (cada run roda no seu minuto).

## 5. Teste controlado (Gate 3 ao vivo)
1. **Feliz:** **Execute Workflow**. Uma vaga aderente SEM ingles alto cai no ramo **true** do
   "Aprovada?", **grava na aba Vagas** e **chega no Telegram**. Confira a carta: so skills do CV (zero invencao).
2. **Invalido (trava de idioma / gap):** vaga com ingles avancado ou fora do perfil vai para a aba
   **Reprovadas** (ramo false), nunca para o Telegram.
3. **Dedup:** rode de novo - nenhuma vaga ja registrada (Vagas) nem ja reprovada (Reprovadas) e reprocessada.

## 6. Ligar o agendamento + alerta de erro
1. **Settings do workflow** > **Error Workflow** > selecione **este mesmo workflow** (o no "Erro no
   fluxo" recebe as falhas e dispara o alerta no Telegram).
2. **Active** = ON. O "Agendador" roda nos horarios do cron (timezone do container, `America/Sao_Paulo`).

## Observacoes tecnicas
- **job_id** = hash (djb2) de `titulo|empresa|localidade` (minusculo). Dedup no lote e contra a aba *Vagas*.
  As reprovadas sao deduplicadas por `titulo+empresa` (a aba *Reprovadas* nao guarda o job_id).
- **Parse defensivo:** se o LLM fugir do JSON, o no marca `match=0`/`parse_ok=false` e a vaga cai no
  filtro - o fluxo nunca quebra por isso.
- **Budget SerpAPI:** free tier ~250 buscas/mes. Ajuste `keywords` e a frequencia do Agendador ao seu teto.
