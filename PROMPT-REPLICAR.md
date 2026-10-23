# 🧩 Prompt replicável - monte este monitor para o SEU perfil

Este projeto foi construído para um perfil específico, mas a estrutura é 100% reaproveitável. Abaixo
tem um **prompt pronto** para você colar num agente de código (Claude Code, Cursor, etc.) e reproduzir
a mesma automação adaptada ao **seu** CV, às **suas** keywords e aos **seus** canais.

## Antes de começar, tenha em mãos

1. **Um n8n rodando** (self-hosted via Docker ou n8n Cloud). Se não tiver, peça ao agente para subir
   com o [`docker-compose.yml`](docker-compose.yml) + [`docs/DEPLOY.md`](docs/DEPLOY.md) deste repo.
2. **Contas/keys** (todas têm free tier): [SerpAPI](https://serpapi.com),
   [Groq](https://console.groq.com), [Telegram Bot](https://t.me/BotFather) e um
   **service account** do Google com a planilha compartilhada como Editor.
3. **Seu perfil em texto** (resumo do CV/LinkedIn): experiências, stack, skills comprovadas, nível de
   inglês real, regime (CLT/PJ), localidade. Quanto mais honesto, melhor o match.

## O prompt (edite os campos entre colchetes e cole no agente)

```
Quero montar no meu n8n uma automação "Monitor Inteligente de Vagas" igual à estrutura do repositório
github.com/juniorogestor-wq/monitor-vagas-tech-n8n, adaptada ao MEU perfil. Use o workflow.json e os
docs desse repo como molde. Pilote o n8n pela API pública (não me faça clicar nó por nó).

MEU PERFIL (fonte única da verdade para o scoring e a carta - proibido inventar nada fora disto):
[cole aqui 8-15 linhas: cargo-alvo, experiências reais, stack/skills comprovadas, formação,
nível de inglês REAL, regime CLT/PJ, cidade/UF e disponibilidade]

MEUS CARGOS-ALVO (keywords da busca, em português, separadas por vírgula):
[ex: Engenheiro de IA, Arquiteto de IA, Especialista em Automação de IA, ...]

MINHAS REGRAS:
- Threshold de match: [ex: 70]%.
- Trava de idioma: manter só vagas com inglês [ex: nenhum, básico]; descartar o resto.
- Localidade: [ex: Brazil / São Paulo / remoto].
- Canais de entrega: Telegram (resumo) + Google Sheets (log completo com carta e faixa salarial).
- Frequência: [ex: 3x ao dia].

ENTREGUE:
1. Workflow importado e com as credenciais vinculadas (eu colo os segredos no painel).
2. Prompt de scoring que devolve JSON estrito (match_score, english_requirement, work_model,
   contract_type, salary_clt, salary_pj, salary_confidence, cover_letter, match_reasons, red_flags),
   com a carta ancorada 100% no meu perfil e faixa salarial sempre com flag de confiança.
3. Dedup contra as abas Vagas E Reprovadas (não reprocessar o que já vi).
4. Controle de custo: cap de vagas por rodada para respeitar o limite de tokens/min do LLM; se eu
   quiser mais volume/dia, aumente o número de rodadas no agendador (não a rajada).
5. Gate 3: prove com cenário feliz (vaga aderente -> Telegram), inválido (inglês alto/fora do perfil
   -> Reprovadas) e ausência (JSON malformado -> não quebra). Teste as keywords na SerpAPI de verdade
   antes de concluir que "não há vagas" (resultado vazio pode ser transitório).

Não comite nenhum segredo. Mantenha .env no servidor e só .env.example no repo.
```

## Gotchas que valem ouro (já pagos aqui)

- **Termos em português** rendem mais no Google Jobs BR; os mesmos em inglês costumam voltar vazios.
- **Não busque o que você vai rejeitar.** Se o seu perfil não é de ML clássico, não coloque
  "Engenheiro de Machine Learning" nas keywords - ele só enche a fila de reprovadas.
- **LLM free tier tem teto por minuto.** Resolva com cap por rodada + mais rodadas no dia, não com
  retry (o retry do n8n espera no máx. 5s, insuficiente para o cooldown).
- **Telegram** assume Markdown por default e quebra em `_ ( )` de links - use `parse_mode: HTML` e
  escape `& < >`.
- **Google Sheets (append)** casa colunas por **nome exato** do cabeçalho (sem acento/espaço).
- **Resultado vazio da busca pode ser transitório** - teste na fonte de novo antes de trocar a estratégia.

---

Feito isso, você tem a mesma máquina caçando as suas vagas todos os dias. Boa recolocação. 🚀
