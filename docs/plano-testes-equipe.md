# Plano de testes da equipe — em consolidação

Branch `testes/planejamento-automacao-lucas`. [Plano comum no GitHub](https://github.com/lucasact4/engenharia-de-software/blob/testes/planejamento-automacao-lucas/docs/plano-testes-equipe.md) · [Card #53](https://trello.com/c/BSGE2VRG) · [Requisitos](https://docs.google.com/document/d/1Z-G_nlIvvTVX9EKb3dZUui2HXBQL_vz4f8bAMfQmtv0/edit).

## Objetivo e participação

Consolidar critérios, casos e evidências da equipe. Cada integrante escreve casos para dois RFs e automatiza pelo menos quatro casos de um deles. A avaliação tem parte coletiva (plano único) e individual (participação e demonstração). Lucas automatiza ambos os RFs selecionados. Este plano ainda não contém os casos de todos os integrantes.

Cada integrante entrega vídeo individual de até 2 minutos, usando o mesmo link deste plano compartilhado.

| Integrante | RFs selecionados | Situação nesta atividade |
| --- | --- | --- |
| Lucas Vitor | RF010 e RF016 | RF010 e RF016 automatizados: 13 exemplos passaram; manuais auxiliares não executados |
| José de Lemos | RF002 e RF007 | Pendentes: casos, automação e evidências |
| Alisson Cerqueira | RF011 e RF014 | Pendentes: casos, automação e evidências |
| Guilherme Santiago | RF012 e RF015 | Pendentes; RF012 não implementado: bloqueio para equipe rever seleção/escopo |
| Victor Novais | RF001 e RF005 | Pendentes: casos, automação e evidências |

Implementação: RF010 por José; núcleo RF016 por Alisson, com Victor no fluxo anônimo anterior; Lucas contribuiu na integração, schema e specs. Conferir autor do trecho e contribuições do testador antes de reconhecer independência do teste cruzado.

Os casos de Lucas e este plano foram preparados com apoio de ferramenta de programação, sujeitos à revisão dos responsáveis.

## Critérios de aceitação antes dos casos

RF010 pede mapa com postagens localizadas; RF016 pede registro de IP, User-Agent e timestamp da submissão anônima. Abaixo estão refinamentos verificáveis da implementação, não reprodução literal nem declaração de atendimento integral dos requisitos.

| ID | Critério refinado |
| --- | --- |
| RF010-AC01 | Sem consentimento de ponto exato, usar ponto representativo do local e `exact: false` |
| RF010-AC02 | Consentimento com GPS dentro do polígono selecionado permite coordenadas exatas |
| RF010-AC03 | Consentimento sem coordenadas usa referência do local, sem exatidão |
| RF010-AC04 | GPS fora do polígono selecionado usa referência do local, sem exatidão |
| RF010-AC05 | Agrupar relatos aproximados do mesmo local preservando quantidade, IDs e links |
| RF010-AC06 | Fluxo público respeita aprovação específica do mapa e filtros |
| RF010-L01 | Local apenas descritivo retorna `nil`: lacuna caracterizada, não aceite de todo relato localizado |
| RF016-AC01 | Submissão com identidade pública oculta captura IP, User-Agent e `submitted_at`, vinculados à ocorrência |
| RF016-AC06 | Ausência de `submitted_at` ou do vínculo com a ocorrência torna a auditoria inválida |
| RF016-AC02 | IP e User-Agent cifrados no armazenamento; leitores do modelo recuperam os valores |
| RF016-AC03 | Inspeção de metadados somente por administrador ativo; mural não os divulga |
| RF016-AC04 | Auditorias de ocorrências diferentes preservam seus próprios vínculos e metadados |
| RF016-AC05 | Modelo recusa atualização e exclusão da auditoria persistida (append-only) |

## RF010 — seis unidades automatizadas

Arquivo `spec/services/campus_map/rf010_marker_spec.rb`, títulos e comentários em português. Associações `build_stubbed`, sem persistência dos objetos; Rails/helper ainda exigem ambiente de teste preparado. Métodos privados `report_marker` e `spot_marker` acessados intencionalmente via `send`: há acoplamento à implementação, sem refatoração do código do colega. Não comprovam aprovação, autorização ou filtros do método público `call`.

Base: local ativo, polígono longitude/latitude fechado entre `[-34.951,-8.018]` e `[-34.949,-8.016]`; referência latitude/longitude `[-8.017,-34.95]`; GPS interno `[-8.0175,-34.9505]`.

| Caso / critério | Entrada e ação | Resultado esperado |
| --- | --- | --- |
| RF010-UT01 / AC01 | GPS interno, consentimento falso; chamar `report_marker` | Referência do local; `exact: false` |
| RF010-UT02 / AC02 | GPS interno, consentimento verdadeiro; chamar `report_marker` | Coordenadas GPS; `exact: true` |
| RF010-UT03 / AC03 | Consentimento verdadeiro, coordenadas nulas, local georreferenciado; chamar `report_marker` | Referência do local; `exact: false` |
| RF010-UT04 / L01 | Descrição `Perto da entrada`, sem local georreferenciado nem GPS; chamar `report_marker` | `nil`: LACUNA, teste de caracterização, não aceite integral do RF010 |
| RF010-UT05 / AC04 | GPS autorizado fora do polígono selecionado; chamar `report_marker` | Referência do local; `exact: false` |
| RF010-UT06 / AC05 | Dois relatos aproximados no mesmo local; gerar marcadores e chamar `spot_marker` | `count: 2`, IDs e links de ambos preservados |

Quatro exemplos existentes em `spec/services/campus_map/map_data_spec.rb` exercitam integração via `call`; não são autoria nova de Lucas nesta atividade nem garantem autorização completa.

## RF016 — sete testes automatizados de modelo

Arquivo `spec/models/anonymous_submission_audit_spec.rb`. Usa `create(:alert)`, banco de teste real e cifragem real, sem mocks. Testa o modelo, não o fluxo de ponta a ponta, a captura HTTP, Turnstile ou autorização. Base sintética: IP `192.0.2.10`, agente `AgentTeste/1.0`, instante UTC `2026-11-11T12:00:00Z`. A auditoria e a ocorrência são persistidas, diferentemente dos objetos `build_stubbed` de RF010.

| Caso / critério | Entrada e ação | Resultado esperado |
| --- | --- | --- |
| RF016-UT01 / AC01 | Chamar `record!` com ocorrência e metadados válidos; recarregar | Registro persistido, vínculo com a ocorrência e `submitted_at` preservados |
| RF016-UT02 / AC02 | Persistir IP sintético; comparar coluna e consultar `ip_address` | Ciphertext diferente do texto claro; leitor recupera o IP original |
| RF016-UT03 / AC02 | Persistir agente sintético; comparar coluna e consultar `user_agent` | Ciphertext diferente do texto claro; leitor recupera o agente original |
| RF016-UT04 / AC06 | `submitted_at: nil`, demais campos válidos; chamar `record!` | `ActiveRecord::RecordInvalid`, erro de ausência do instante, sem salvar auditoria |
| RF016-UT05 / AC06 | `alert: nil`, demais campos válidos; chamar `record!` | `ActiveRecord::RecordInvalid`, erro de ausência da ocorrência |
| RF016-UT06 / AC05 | Auditoria persistida; tentar `update!` e recarregar | `ActiveRecord::ReadOnlyRecord`; valores originais intactos |
| RF016-UT07 / AC05 | Auditoria persistida; tentar `destroy!` e recarregar | `ActiveRecord::ReadOnlyRecord`; registro permanece |

```sh
bundle exec rspec spec/services/campus_map/rf010_marker_spec.rb spec/models/anonymous_submission_audit_spec.rb --seed 12345 --format progress
```

Validação local assistida: **13 examples, 0 failures**, seed **12345** — seis unidades RF010 e sete testes de modelo RF016. RuboCop: **2 files inspected, no offenses detected**. O resultado não inclui as quatro integrações existentes nem comprova execução manual, autorização ou cobertura global.

## Casos manuais auxiliares — não executados

RF010: ambiente de teste com local da base, contas autorizadas e publicações fictícias em andamento. Preparar aprovação específica do mapa quando indicada; registrar IDs e reiniciar os dados entre casos.

| Caso / critério | Entrada e ação | Esperado | Status |
| --- | --- | --- | --- |
| RF010-M01 / AC06 | Uma publicação aprovada para o mapa e outra aprovada só no mural; abrir mapa público | Mostrar somente a elegível ao mapa | Planejado |
| RF010-M02 / AC06 | Relatos aprovados em duas categorias ativas; selecionar filtro de uma categoria na interface | Mostrar apenas relatos dessa categoria | Planejado |

RF016: ambiente de teste autorizado, conta autenticada habilitada a criar ocorrência, administrador ativo e usuário comum. Formulário válido: título `Lâmpada quebrada`, descrição `Lâmpada apagada na entrada do bloco`, categoria ativa e local manual `Entrada do bloco A`; selecionar identidade pública oculta (`anonymous_public`). Turnstile configurado e válido; indisponibilidade bloqueia os casos de submissão, sem contornar a proteção.

Preparar ocorrência com auditoria sintética de IP `192.0.2.10`, agente `AgentTeste/1.0` e instante `2026-11-11T12:00:00Z`, sem divulgar IP real, segredos ou ciphertext. Identificar o ID e garantir publicação elegível ao mural no cenário público.

| Caso / critério | Entrada e ação | Esperado | Status |
| --- | --- | --- | --- |
| RF016-M01 / AC01, AC03 | Como admin ativo, abrir detalhe da ocorrência preparada | Mostrar IP/agente sintéticos e instante equivalente ao UTC; UI pode formatar o fuso | Planejado |
| RF016-M02 / AC03 | Abrir mural e detalhe público da publicação elegível | Sem IP, agente ou timestamp da auditoria; distinguir data pública da postagem | Planejado |
| RF016-M03 / AC03 | Como usuário comum, inclusive autor, tentar URL administrativa direta | Sem metadados; barreira admin redireciona HTML ao painel e retorna 403 para outros formatos | Planejado |

## Fontes, evidências e pendências

Fontes técnicas: `app/services/campus_map/map_data.rb`, os dois specs do mapa e o spec de auditoria, `app/models/anonymous_submission_audit.rb`, `app/services/alerts/create.rb`, controllers público/admin de alertas, `app/controllers/admin/application_controller.rb` e detalhe administrativo. `record!` usa AES-256-GCM para IP/agente e grava `submitted_at`; controllers passam `request.remote_ip`, `request.user_agent`, `Time.current`; gravação ocorre na mesma transação e inspeção admin descriptografa os valores.

Registrar no card: implementador, testador, confirmação de independência do trecho, ambiente/data, commit, casos, comando/seed, esperado, observado e evidência. Os manuais acima não foram executados. Demais integrantes precisam incluir critérios, casos e resultados próprios neste plano comum.

Dos 28 requisitos (19 RF e 9 RNF), dez RFs estão selecionados. Permanecem sem responsável/casos consolidados RF003, RF004, RF006, RF008, RF009, RF013, RF017, RF018, RF019 e os nove RNFs. Seleção não significa cobertura comprovada; conclusão coletiva, independência dos testes cruzados e revisão do bloqueio RF012 continuam pendentes da equipe.
