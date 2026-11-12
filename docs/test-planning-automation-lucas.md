# Lucas Vitor — RF010 e RF016

Seção individual do [plano único da equipe](plano-testes-equipe.md#seções-individuais). Branch `testes/rf010-rf016-lucas-vitor`; [card #53](https://trello.com/c/BSGE2VRG). Recorte: RF010 automatizado e escrito; RF016 com plano manual. Preparado com apoio de ferramenta de programação, para revisão e apresentação por Lucas. Os casos manuais não foram executados.

## Critérios antes dos casos

RF010 exige mapa com postagens que têm localização; RF016 exige registro de IP, User-Agent e timestamp na submissão com identidade pública oculta. As regras abaixo são refinamentos verificáveis da implementação, não transcrição literal nem comprovação integral desses RFs.

| ID | Critério refinado |
| --- | --- |
| RF010-AC01 | Sem consentimento de localização exata, representar o relato no ponto do local com `exact: false` |
| RF010-AC02 | Com consentimento e coordenadas dentro do polígono selecionado, preservar o ponto GPS exato |
| RF010-AC03 | Consentimento sem coordenadas não autoriza inventar ponto exato: usar referência do local |
| RF010-AC04 | GPS fora do polígono selecionado deve usar ponto representativo, sem indicação de exatidão |
| RF010-AC05 | Agrupar relatos aproximados do mesmo local preservando quantidade, IDs e links |
| RF010-AC06 | No fluxo público, exibir somente publicações elegíveis ao mapa conforme aprovação, acesso e filtros |
| RF010-L01 | Lacuna: descrição de localização sem georreferência retorna `nil`; caracteriza comportamento atual, não satisfaz exibir todo relato localizado |

| ID | Critério refinado |
| --- | --- |
| RF016-AC01 | Submissão com identidade pública oculta registra IP, User-Agent e `submitted_at`, vinculados à ocorrência |
| RF016-AC02 | IP e User-Agent são cifrados no armazenamento e recuperáveis pelos leitores autorizados |
| RF016-AC03 | Somente administrador ativo acessa a inspeção administrativa; mural não divulga os metadados |
| RF016-AC04 | Cada auditoria permanece vinculada à ocorrência correta, sem misturar submissões |
| RF016-AC05 | Auditoria persistida é append-only pelo modelo: alterações e exclusões são recusadas |

## RF010 — seis testes de unidade

Arquivo `spec/services/campus_map/rf010_marker_spec.rb`, títulos e comentários em português. Dados `build_stubbed`, sem persistência dos objetos; Rails ainda inicializa pelo helper e requer ambiente de teste preparado. Sem navegador, GPS real ou serviço externo. Métodos privados `report_marker` e `spot_marker` acessados intencionalmente via `send`, sem refatorar o código do colega: há acoplamento à implementação. Os exemplos não garantem aprovação, autorização ou filtros do método público `call`.

Base: local ativo com polígono longitude/latitude fechado entre `[-34.951,-8.018]` e `[-34.949,-8.016]`, ponto representativo latitude/longitude `[-8.017,-34.95]`; GPS interno `[-8.0175,-34.9505]`. Publicações e relatos fictícios, sem dados pessoais.

| Teste / vínculo | Entrada | Ação | Esperado |
| --- | --- | --- | --- |
| RF010-UT01 / AC01 | GPS interno; consentimento falso | Chamar `report_marker` via `send` | Ponto representativo; `exact: false` |
| RF010-UT02 / AC02 | GPS interno; consentimento verdadeiro | Mesmo método | Coordenadas GPS preservadas; `exact: true` |
| RF010-UT03 / AC03 | Consentimento verdadeiro; coordenadas nulas; local georreferenciado | Mesmo método | Ponto representativo; `exact: false` |
| RF010-UT04 / L01 | Somente descrição `Perto da entrada`, sem local georreferenciado nem coordenadas | Mesmo método | `nil`: teste de caracterização da lacuna, não aceite integral do RF010 |
| RF010-UT05 / AC04 | GPS fora do polígono do local selecionado; consentimento verdadeiro | Mesmo método | Retornar referência do local; `exact: false` |
| RF010-UT06 / AC05 | Dois relatos aproximados no mesmo local, IDs e links distintos | Gerar marcadores e chamar `spot_marker` via `send` | `count: 2`, ambos os IDs e links preservados |

Quatro exemplos existentes em `spec/services/campus_map/map_data_spec.rb` complementam a integração via `call`: representação, consentimento/áreas, aprovação/invalidação e separação de pontos exatos. Não são de autoria de Lucas nesta atividade; não equivalem a teste completo de autorização.

```sh
bundle exec rspec spec/services/campus_map/rf010_marker_spec.rb --format documentation
bundle exec rspec spec/services/campus_map/rf010_marker_spec.rb spec/services/campus_map/map_data_spec.rb --format documentation --seed 12345
```

## RF010 — plano manual do fluxo público/interface

Pré-condições: ambiente de teste, mapa acessível, local e polígono da base acima, publicações fictícias com ocorrência em andamento; preparar aprovação específica do mapa quando indicada. Usar contas autorizadas e registrar os IDs. Cada caso começa com dados controlados; todos **não executados**.

| Caso / critério | Entrada | Ação pública/interface | Esperado |
| --- | --- | --- | --- |
| RF010-M01 / AC01 | Publicação aprovada, GPS interno, sem consentimento | Abrir mapa e marcador | Ponto representativo, sem expor GPS exato; link leva à publicação correta |
| RF010-M02 / AC02 | Publicação aprovada, GPS interno, consentimento verdadeiro | Abrir mapa e detalhe do marcador | Ponto exato e vínculo correto |
| RF010-M03 / AC06 | Uma publicação aprovada para o mapa e outra sem essa aprovação | Abrir mapa público | Somente a elegível aparece; aprovação do mural isolada não basta |
| RF010-M04 / AC05 | Duas publicações aprovadas e aproximadas no mesmo local | Abrir agrupamento | Contador 2 e dois links corretos |
| RF010-M05 / AC06 | Duas categorias ativas diferentes com relatos aprovados | Selecionar filtro de uma categoria | Exibir somente relatos da categoria selecionada |
| RF010-M06 / L01 | Relato aprovado com apenas descrição manual de local | Abrir mapa e procurar seu ID | Ausente no comportamento atual; registrar lacuna, sem declarar RF atendido |

## RF016 — plano de auditoria da submissão

Pré-condições: ambiente de teste autorizado; conta autenticada habilitada para criar ocorrência, administrador ativo e usuário comum; formulário válido com título `Lâmpada quebrada`, descrição `Lâmpada apagada na entrada do bloco`, categoria ativa e local manual `Entrada do bloco A`. Selecionar ocultação da identidade pública (`anonymous_public`); isso não significa envio sem login. Turnstile deve estar configurado e validado; se indisponível, marcar os casos de submissão como **bloqueados**, sem contornar a proteção.

Usar requisições controladas exclusivamente no ambiente de teste com IP documental `192.0.2.10`, User-Agent `AgentTeste/1.0` e relógio controlado `2026-11-11T12:00:00Z`. Para segunda submissão, `192.0.2.11`, `AgentTeste/2.0`, `2026-11-11T12:01:00Z`. Nunca divulgar IP real, chaves ou ciphertext em evidências. Casos abaixo são **planejados, não executados**; M06–M08 exigem verificação técnica autorizada, não apenas navegador.

| Caso / critério | Entrada | Ação | Esperado |
| --- | --- | --- | --- |
| RF016-M01 / AC01 | Ocorrência válida, identidade oculta, fixture 1, Turnstile válido | Submeter com conta autorizada; anotar ID/protocolo | Criar ocorrência e auditoria vinculada com os três metadados capturados |
| RF016-M02 / AC01, AC03 | ID de M01; administrador ativo | Abrir detalhe administrativo | Inspeção mostra IP e User-Agent sintéticos e horário equivalente ao instante UTC; interface pode formatar o fuso |
| RF016-M03 / AC03 | Publicação de M01 elegível ao mural | Abrir mural e detalhe público | Sem IP, User-Agent ou timestamp da auditoria; não confundir com data pública da postagem |
| RF016-M04 / AC03 | Usuário comum, inclusive autor de M01 | Tentar URL administrativa direta | Negar acesso aos metadados; HTML redireciona ao painel e formatos não HTML retornam 403 na barreira administrativa |
| RF016-M05 / AC04 | Duas submissões distintas com fixtures 1 e 2 | Inspecionar como admin cada ocorrência | Cada ID ligado à sua auditoria, IP, agente e instante corretos |
| RF016-M06 / AC02 | Auditoria de M01 | Em DB somente de teste aprovado, conferir colunas cifradas; ler pelos métodos do modelo | `ip_address_ciphertext` e `user_agent_ciphertext` diferem dos valores claros; leitores recuperam fixtures; não prometer cifra na UI administrativa |
| RF016-M07 / AC05 | Auditoria persistida; novo IP sintético | Pelo modelo, tentar `update!` e `destroy!`; recarregar | Recusar com `ActiveRecord::ReadOnlyRecord`; registro e valores preservados. Não comprova proteção contra SQL direto |
| RF016-M08 / AC01 | Criação com `anonymous_public: true` sem `request_audit` | Chamar serviço em teste autorizado, mantendo demais dados válidos | `ActiveRecord::RecordInvalid`; transação não persiste ocorrência sem captura da auditoria |

Fonte conferida: `AnonymousSubmissionAudit.record!` cifra IP/User-Agent com MessageEncryptor AES-256-GCM e registra `submitted_at`; o modelo bloqueia atualização/exclusão após persistência. `Alerts::Create#persist!` exige metadados quando a identidade é oculta e grava auditoria na transação. Controllers público e admin passam `request.remote_ip`, `request.user_agent` e `Time.current` (instante atual; comparar em UTC). Captura implementada no PR #25, commit `e2889d1`. Inspeção administrativa descriptografa para exibição e depende de administrador ativo; a criptografia deve ser conferida no armazenamento.

## Autoria e evidência cruzada

RF010: implementação de José, commits `74f297b`, `921d5de`, `b1d176a`, `fe915e3`; seis novos testes preparados para Lucas com apoio de ferramenta. RF016: modelo `AnonymousSubmissionAudit` e captura de metadados de Alisson, commit `e2889d1`; Victor implementou o fluxo anterior de postagem anônima. Lucas apoiou integração, schema e specs, sem autoria do modelo de captura. O teste cruzado proposto verifica esse núcleo do colega, com as contribuições anteriores explicitadas.

Evidência de execução local assistida, commit dos novos testes `b810fce`: **6 examples, 0 failures**, seed **36050**; RuboCop do novo spec sem infrações. Conjunto: **10 examples, 0 failures**, seed **12345** (6 novos + 4 existentes, sem atribuir autoria dos quatro a Lucas). Testes manuais cruzados permanecem pendentes. Nenhuma evidência antiga de RF013 é usada como resultado de RF010; sem percentual global de cobertura.

## Vídeo individual — 120 segundos

| Tempo | Mostrar |
| --- | --- |
| 0–20 s | Plano único, seção Lucas e critérios RF010/RF016 antes dos casos |
| 20–50 s | Seis unidades e comando; diferenciar UT04/lacuna e acoplamento a privados |
| 50–75 s | Saída real 6/6 e conjunto 10/10, seeds e autoria dos quatro existentes |
| 75–100 s | Casos escritos de ambos os RFs, destacando captura, cifra, acesso administrativo e expectativas RF016 ainda não executadas |
| 100–120 s | Card #53, implementador/testador, limitações e pendências; entregar o mesmo link do plano da equipe |

Referências conferidas no código e no histórico Git: `app/services/campus_map/map_data.rb`, `app/controllers/campus_map_controller.rb`, os dois specs do mapa, `app/models/anonymous_submission_audit.rb`, `app/services/alerts/create.rb`, `app/controllers/alerts_controller.rb`, `app/controllers/admin/alerts_controller.rb`, `app/controllers/admin/application_controller.rb`, `app/controllers/concerns/anonymous_publication_protection.rb` e `app/views/admin/alerts/show.html.erb`.
