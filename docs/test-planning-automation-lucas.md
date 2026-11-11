# Participação individual — Lucas Vitor: planejamento e automação de testes

Branch: `testes/rf013-lucas-vitor`. Escopo: RF013 (denúncias), RF007 (fotos) e RF018 (categoria). [Card #53 — controle e evidências](https://trello.com/c/BSGE2VRG). [Plano na branch](https://github.com/lucasact4/engenharia-de-software/blob/testes/rf013-lucas-vitor/docs/test-planning-automation-lucas.md). Commit dos testes: `83f3f60`.

## Origem dos critérios e limites

Este plano detalha a participação individual de Lucas na estratégia da equipe. Os critérios abaixo refinam os requisitos RF013, RF007 e RF018 com regras verificáveis da implementação atual. Regras adicionais, como o limite de detalhes e os motivos da denúncia, devem ser revisadas com a equipe antes do aceite. [Documento oficial de requisitos](https://docs.google.com/document/d/1Z-G_nlIvvTVX9EKb3dZUui2HXBQL_vz4f8bAMfQmtv0/edit).

RF007 tem conflito registrado em `config/presentation/requisitos.yml`: foto opcional na versão anterior versus proposta de foto obrigatória, ainda aguardando decisão. O modelo atual aceita ocorrência sem foto. O plano distingue comportamento implementado de requisito pendente; aceitar zero fotos não comprova atendimento à proposta obrigatória.

## RF013 — critérios de aceitação e matriz automatizada

Arquivo: `spec/models/content_report_spec.rb`. Base de cada caso: denúncia nova, estado `pending`, denunciante e publicação obtidos com `build_stubbed`, motivo `spam`, nenhum comentário e nenhum detalhe; IDs sem denúncia prévia no banco de teste. Alterar somente a entrada indicada. A ação comum é chamar `valid?` (pelos matchers `be_valid`) e inspecionar validade, erros e alvo quando aplicável.

Cada linha define um critério de aceitação refinado e seu teste rastreável; resultados são expectativas, não registros de execução.

| Critério | Teste | Entrada concreta / alteração | Ação | Resultado esperado |
| --- | --- | --- | --- | --- |
| RF013-AC01 | RF013-UT01 | Somente publicação; `reason: "spam"` | Validar e consultar `target` | Válido; alvo é a publicação |
| RF013-AC02 | RF013-UT02 | Publicação nula; somente comentário ligado à publicação | Validar; consultar `target` e `target_publication` | Válido; alvo é o comentário e publicação de origem correta |
| RF013-AC03 | RF013-UT03 | Publicação e comentário nulos | Validar e consultar erros | Inválido; erro `base: single_target` |
| RF013-AC04 | RF013-UT04 | Publicação e comentário simultâneos | Validar e consultar erros | Inválido; erro `base: single_target` |
| RF013-AC05 | RF013-UT05 | `reporter: nil` | Validar e consultar erros | Inválido; erro `reporter: blank` neste aplicativo |
| RF013-AC06 | RF013-UT06 | `reason: "unsupported"` | Validar e consultar erros | Inválido; erro `reason: inclusion` |
| RF013-AC07 | RF013-UT07 | `reason: "other"`, `details: nil` | Validar e consultar erros | Inválido; erro `details: blank` |
| RF013-AC08 | RF013-UT08 | `reason: "other"`, `details: "  \n\t  "` | Validar e consultar erros | Whitespace normalizado para ausência; inválido, `details: blank` |
| RF013-AC09 | RF013-UT09 | `reason: "other"`, `details: "  O conteúdo expõe dados pessoais.  "` | Validar e ler detalhes | Válido; detalhes sem espaços externos |
| RF013-AC10 | RF013-UT10 | `details: "a" * 2000` | Validar | Válido no limite de 2000 caracteres |
| RF013-AC11 | RF013-UT11 | `details: "a" * 2001` | Validar e consultar erros | Inválido; erro `details: too_long` |

### Execução e isolamento

Na raiz do projeto, com dependências instaladas e banco de teste disponível:

```sh
bundle exec rspec spec/models/content_report_spec.rb --format documentation
```

Os testes de modelo isolam os validadores usando associações `build_stubbed` e `valid?`, sem navegador nem serviços externos e sem salvar a denúncia ou disparar seus callbacks de salvamento/notificação. Inicializam Rails por `rails_helper` e consultam o banco de teste nas validações de unicidade. Portanto, não são herméticos nem independentes de DB. O helper também mantém o schema de teste e usa DatabaseCleaner; executar somente no ambiente de teste preparado.

O recorte não demonstra sozinho autorização, interface, persistência, notificações, unicidade por denunciante/alvo ou revisão administrativa. Há testes de serviço e requisição complementares; a validação permanece parcial.

## RF007 — plano manual de fotos

Pré-condições: ambiente de teste autorizado, usuário autenticado, formulário de nova ocorrência com título `Lâmpada quebrada`, descrição `Lâmpada apagada na entrada do bloco`, categoria ativa e localização manual `Entrada do bloco A`. Preparar arquivos de teste reais, sem dados pessoais. Recomeçar com formulário válido em cada caso. Os critérios são refinados a partir de `Alert`, não texto literal do RF. Todos os casos manuais abaixo estão **não executados neste registro**.

| Caso / critério | Entrada concreta | Ação | Resultado esperado |
| --- | --- | --- | --- |
| RF007-M01 / RF007-AC01 | `entrada.png`, PNG real de 100 KiB | Anexar, enviar e reabrir ocorrência como autor | Salvar e permitir visualizar a foto |
| RF007-M02 / RF007-AC02 | Cinco JPEG reais, `foto1.jpg` a `foto5.jpg`, 100 KiB cada | Anexar os cinco e enviar | Salvar com cinco fotos; limite de quantidade aceito |
| RF007-M03 / RF007-AC03 | Seis PNG reais de 100 KiB cada | Anexar os seis e tentar enviar | Bloquear excesso; não salvar seis anexos |
| RF007-M04 / RF007-AC04 | PNG real com 5.242.881 bytes (5 MiB + 1) | Anexar e tentar enviar | Rejeitar arquivo acima de 5 MiB com indicação de erro |
| RF007-M05 / RF007-AC05 | `falsa.png`, conteúdo textual `isto não é imagem`, MIME declarado PNG | Anexar e tentar enviar | Rejeitar conteúdo que não é PNG/JPEG real |
| RF007-M06 / RF007-AC06 | Nenhuma foto | Enviar formulário válido | Implementação atual aceita; registrar divergência se a obrigatoriedade for aprovada |

Se o navegador bloquear antes do envio, registrar essa etapa e não afirmar que a validação do servidor foi exercitada. A regra de 5 MiB vale por arquivo; PNG e JPEG são os tipos aceitos.

## RF018 — plano manual de categoria

Usar o mesmo formulário válido, sem fotos para não misturar regras. Em ambiente de teste, dispor de categoria ativa `Infraestrutura` sem exigência de detalhe, categoria ativa `Outro` com `requires_details: true` e categoria inativa `Categoria desativada`. São dados de preparação propostos, não catálogo confirmado nem alterações efetuadas nesta tarefa. Todos os casos estão **não executados neste registro**.

| Caso / critério | Entrada concreta | Ação | Resultado esperado |
| --- | --- | --- | --- |
| RF018-M01 / RF018-AC01 | Categoria `Infraestrutura` ativa | Selecionar, enviar e reabrir | Salvar associada à categoria escolhida |
| RF018-M02 / RF018-AC02 | Categoria não selecionada | Tentar enviar ocorrência | Bloquear ausência de categoria |
| RF018-M03 / RF018-AC03 | `Outro`; detalhes vazios | Selecionar e tentar enviar | Bloquear; solicitar detalhamento |
| RF018-M04 / RF018-AC03 | `Outro`; detalhes com três espaços | Selecionar e tentar enviar | Bloquear; whitespace não satisfaz presença |
| RF018-M05 / RF018-AC04 | `Outro`; `Bicicletário danificado` | Selecionar, preencher e enviar | Salvar categoria e detalhe informado |
| RF018-M06 / RF018-AC05 | `Outro`; detalhe com 501 letras `a` | Preencher e tentar enviar | Bloquear detalhe acima de 500 caracteres |
| RF018-M07 / RF018-AC06 | `Categoria desativada` | Abrir seleção para nova ocorrência | Não oferecer categoria inativa para nova associação; se oferecida, registrar divergência; o modelo rejeita nova associação inativa |

A exigência de detalhe depende de `requires_details`, não apenas do nome `Outro`. RF018 trata da categoria da ocorrência, sem inferir severidade ou prioridade. Não aplicar a obrigatoriedade de categoria ao fluxo de pânico.

## Quem fez o quê

A tabela identifica a entrega individual preparada para Lucas. Cada integrante deve completar sua própria participação; este documento não substitui o plano consolidado dos demais requisitos da equipe.

| Integrante | Participação nesta atividade |
| --- | --- |
| Lucas Vitor | Responsável por apresentar e revisar os 11 testes RF013 e os planos RF007/RF018 preparados nesta entrega com apoio de ferramenta de programação |
| Guilherme Santiago | A definir / não confirmado |
| Jose de Lemos | A definir / não confirmado |
| Victor Novais | A definir / não confirmado |
| Alisson Cerqueira | A definir / não confirmado |

Revisor cruzado sugerido: **Victor Novais — A CONFIRMAR**. Sugestão não representa aceite, atribuição confirmada nem revisão realizada. Após confirmação, registrar revisão dos critérios e execução independente, com data, ambiente, comando, saída e divergências no card #53.

## Evidência local — 11/11/2026

Resultados executados no Dev Container durante a preparação desta entrega, com código dos testes no commit `83f3f60`:

- RF013: 11 exemplos novos de modelo junto com 5 de serviços e 5 de requisição de denúncias: **21 examples, 0 failures**, seed **64710**.
- Execução isolada final: **11 examples, 0 failures**, seed **12345**.
- `bundle exec rubocop spec/models/content_report_spec.rb`: **1 file inspected, no offenses detected**.
- Verificação deliberada de assertividade: `single_target` desabilitado somente em processo temporário; UT03 e UT04 produziram **2 exemplos / 2 falhas**, como esperado. Esses testes detectam a retirada da regra. A execução final voltou a passar com a regra original; o script temporário foi excluído.

Os resultados e o commit estão registrados no card #53. Testes manuais e cruzados permanecem pendentes. O percentual global mostrado pelo SimpleCov ao executar apenas este arquivo não representa a cobertura do RF013.

## Roteiro de vídeo — até 2 minutos

| Tempo | Demonstração |
| --- | --- |
| 0:00–0:15 | Identificar Lucas, branch e card #53; delimitar RF013 automatizado e RF007/RF018 planejados |
| 0:15–0:45 | Mostrar matriz e spec: alvo único, denunciante, motivo, detalhe e limites |
| 0:45–1:15 | Mostrar comando e saída real preservada dos testes; distinguir 11 modelos dos 21 exemplos combinados; explicar Rails e DB de teste |
| 1:15–1:40 | Mostrar planos manuais, entradas e resultados esperados; destacar conflito de foto opcional/obrigatória |
| 1:40–2:00 | Mostrar a tabela de participação e o card com a evidência do colega, se já executada; indicar o link deste plano |

Se uma execução ultrapassar o tempo, usar sua saída real previamente capturada e identificada. Não apresentar plano manual como teste realizado.

## Fontes e registro do teste cruzado

Regras verificadas em `app/models/content_report.rb`, `app/models/alert.rb`, `app/models/category.rb` e `config/presentation/requisitos.yml`. Testes complementares existentes em `spec/services/content_reports_spec.rb` e `spec/requests/moderation_request_spec.rb`.

O colega deve comentar no card #53 usando este modelo, preenchido após executar:

```text
Testador e confirmação de que não implementou o requisito:
Data, ambiente e commit:
Casos executados:
Resultado esperado:
Resultado observado (passou/falhou/bloqueado):
Evidência (captura ou saída):
Sugestões e passos para reproduzir falhas:
```
