# Alertas, atendimento, mural e experiência social: implementação

> Registro histórico da implementação de 02/10/2026. A revisão posterior acrescentou cadastro público, revisão administrativa, migrações e temas, além de remover o exemplo do template. Consulte [Cadastro, temas e revisão do SGU](sgu-cadastro-temas-revisao.md) para o estado atual. Os resultados de testes e as limitações abaixo pertencem à entrega original.

Documento de entrega e roteiro de revisão. Registra o estado em 02/10/2026, na branch local `feat/alertas-crud-social`, criada a partir de `main` (`658bfde`, merge da card-11). Nada foi commitado, enviado ou publicado. O diretório não rastreado `docs/prompts/` já existia e foi preservado.

## 1. Entrega utilizável e limitações

**Funciona de ponta a ponta (com testes de request e de navegador):**

- **Ocorrências**
  - Registro pela pessoa autenticada (`/alertas/new`) e pelo admin (`/admin/ocorrencias/new`), sempre com a autoria da sessão.
  - Localização por GPS (pedida só após clique, com estados de carregamento, negado, indisponível, tempo esgotado e sem suporte) ou por local ativo do catálogo.
  - Fotos PNG/JPEG opcionais, validadas pela assinatura do arquivo.
  - Idempotência por chave de envio, com 409 para conteúdo divergente.
  - Protocolo exibido após o envio; "Meus alertas" com abas Meus registros, Ocorrências internas e Acompanhados.
  - Edição pelo autor enquanto `received`/`awaiting_information`.
  - Correção administrativa auditada, com motivo.
  - Remoção individual de foto, auditada.
- **Atendimento**
  - Fila `/atendimento` para coordenação, segurança e admin, mostrando só o que cada um pode atender.
  - Classificação: severidade avaliada e prioridade.
  - Atribuição a contas elegíveis.
  - Transições pela matriz `Alert::TRANSITIONS`, com encerramento com motivo, duplicidade por protocolo e reabertura com motivo (reabrir `closed` é exclusivo do admin).
  - Audiência e restrição (admin).
  - Histórico filtrado por leitor.
  - 422 e 409 preservando o que foi preenchido.
- **Pânico** (`/panico`)
  - Confirmação em dois passos e GPS com espera máxima de 6 s.
  - Chave estável por intenção confirmada, com reenvio do mesmo pedido congelado após falha de rede.
  - Tratamento de 409/422 e mensagem honesta: o sistema recebeu o pedido, o que não significa atendimento humano.
  - Visível na fila só para segurança e admin; nunca entra no mural nem no social.
- **Editorial** (`/admin/publicacoes`)
  - Rascunho, envio para revisão, aprovação ou rejeição da versão lida, publicação e retirada.
  - Fonte compatível e imutável; uma ocorrência gera no máximo uma publicação.
  - Edição relevante invalida a aprovação; fonte alterada bloqueia a publicação até nova revisão.
  - Aviso exige expiração.
- **Mural** (`/mural`)
  - Externo sem login; interno para contas ativas; rascunhos, retiradas, expiradas e fontes bloqueadas nunca aparecem.
  - Busca e filtros, paginação e cartões sem dados operacionais.
- **Social**
  - Comentários com respostas de um nível, edição marcada como "editado", apagamento lógico e moderação com tombstone sem texto nem autoria.
  - Curtidas em publicação e comentário.
  - Salvos privados e acompanhamento de publicação e de ocorrência.
  - Seguir/deixar de seguir perfis públicos opt-in.
  - Limpeza dos próprios vínculos inacessíveis sem revelar o alvo.
- **Perfis**
  - Próprio perfil (`/perfil`): nome, usuário, apresentação e opt-in público.
  - Perfis públicos (`/pessoas`) e seguidores.
  - Admin edita o perfil com auditoria e pode tirar um perfil do ar, mas não ativar o opt-in de terceiros; concede e revoga papéis reconhecidos.
- **Denúncias e moderação**
  - Denúncia privada de publicação ou comentário; "Minhas denúncias" com reabertura.
  - Análise administrativa separada das ações de moderação (remover comentário, retirar publicação).

**Limitações conhecidas:**

- O catálogo de locais continua vazio de propósito: não há dados oficiais da UFRPE.
- Não há mídia editorial própria: o mural é textual.
- Não há notificações (e-mail, push ou tempo real).
- Não há exclusão física de alertas, publicações ou comentários.
- A busca textual usa variantes de caixa porque o `LIKE` do SQLite só ignora caixa em ASCII.
- Capturas não foram incluídas no slide de funcionalidades: qualquer imagem quebra a impressão em uma página.

## 2. Arquitetura e decisões

- **`Alert` vs `Publication`.** `Alert` é o registro operacional, nunca público. `Publication` é texto editorial próprio, assinado como "Equipe do SGU" e ligado à fonte apenas por `alert_id`, que não é exposto no mural. Pedir divulgação externa mantém o alerta `restricted`.
- **Controllers.**
  - `Admin::ApplicationController` (novo) concentra layout, menu, Pundit, `verify_authorized` e um **gate de administração** (`users.admin` ativo). O gate não usa `authorize`, para não mascarar a verificação de cada ação.
  - `Admin::BaseController` continua sendo o CRUD genérico (usuários, cães, categorias, locais).
  - Os controllers de domínio (`Admin::AlertsController`, `Admin::PublicationsController`, `Admin::ContentReportsController`, `Admin::CommentsController`, `Admin::UserRolesController`) herdam o `ApplicationController` administrativo, autorizam a query de domínio de cada ação (`create_occurrence?`, `assess?`, `transition?`, `correct_content?`, `review?`, `moderate?`…) e escrevem só pelos services.
  - `PortalController` (novo) é a base do portal (área autenticada e mural público): Pundit, `verify_authorized`, `resume_session` e respostas 404/403 (`ErrorResponses`).
- **Concerns.**
  - `AlertHandlingActions`: classificação, atribuição e transição, compartilhadas entre `/atendimento` e o admin, com 422/409 que recarregam o alerta e devolvem o preenchimento.
  - `AlertQueueFilters`: filtros e ordenação por allowlist.
  - `AlertFormParams`: campos por modo de localização; GPS e manual não se misturam.
  - `AdminCatalogActions`: ativar e desativar.
- **Policies.**
  - `AlertPolicy` ganhou `queue?`, `correct_content?`, `remove_photo?`, `show_operational_details?` e `HandlingScope`.
  - `PublicationPolicy` ganhou `manage?` e `FeedScope` (o que está no ar para quem lê, inclusive o admin).
  - Novas: `CategoryPolicy` e `LocationPolicy` (sem `destroy?`), `ProfilePolicy`, `PublicProfilePolicy` e `PanelPolicy`.
  - `DashboardPolicy` passou a exigir admin.
- **Presenters e projeções.**
  - `PublicationProjection.collection` e `CommentProjection.collection` autorizam em lote pelo scope e agregam contagens e estado do leitor sem N+1, com o mesmo formato de `as_json` (há teste de equivalência).
  - `AlertDetailPresenter` decide o que cada leitor vê.
  - `PublicationPermissions` calcula os botões; os services revalidam tudo.
  - `PublicIdentity` passou a incluir `id` **somente** com opt-in ativo, para o link do perfil.
- **Services novos.**
  - `Alerts::CorrectContent` (admin; texto e categoria; motivo e auditoria; marca a publicação).
  - `Alerts::RemovePhoto` (anexo do próprio alerta; auditoria; expurgo depois do commit).
  - `Users::UpdateProfile` (auditoria; admin não ativa opt-in).
  - `Social::Interactions.prune_inaccessible` (só vínculos próprios).
- **Outras decisões.**
  - `config.time_zone = "America/Recife"`: exibição e campos `datetime-local`; o banco continua em UTC.
  - Identidade visual: `--primary` do admin passou do vermelho do template para o verde SGU; componentes `sgu-*` ficam em `app/assets/tailwind/application.css`.
  - O exemplo legado `Dog` ficou no menu como "Cães (exemplo)". O rótulo antigo era "Avisos" e se confundia com avisos editoriais.

## 3. Principais arquivos

| Caminho | Finalidade |
| --- | --- |
| `app/controllers/admin/application_controller.rb` | Base administrativa com gate de admin |
| `app/controllers/portal_controller.rb`, `concerns/error_responses.rb` | Base do portal e respostas 404/403 |
| `app/controllers/alerts_controller.rb` | Registro, Meus alertas, detalhe, edição pelo autor, restrição da audiência |
| `app/controllers/panic_alerts_controller.rb`, `app/javascript/controllers/panic_controller.js` | Pânico (HTML e JSON) e envio idempotente no navegador |
| `app/controllers/handling/alerts_controller.rb`, `concerns/alert_handling_actions.rb`, `concerns/alert_queue_filters.rb` | Fila e ações de atendimento |
| `app/controllers/admin/alerts_controller.rb` | Ocorrências no admin, correção, audiência, restrição |
| `app/controllers/admin/{categories,locations}_controller.rb`, `concerns/admin_catalog_actions.rb` | Catálogos |
| `app/controllers/admin/publications_controller.rb`, `app/queries/publication_sources_query.rb` | Ciclo editorial e fontes compatíveis |
| `app/controllers/publications_controller.rb`, `publication_interactions_controller.rb` | Mural e curtir/salvar/acompanhar (Turbo Stream ou HTML) |
| `app/controllers/comments_controller.rb`, `comment_likes_controller.rb` | Comentários, respostas, curtidas |
| `app/controllers/content_reports_controller.rb`, `admin/content_reports_controller.rb`, `admin/comments_controller.rb` | Denúncias e moderação |
| `app/controllers/{profiles,public_profiles,follows,saved_publications,follow_ups,panel}_controller.rb` | Perfis, seguir, listas privadas, painel |
| `app/controllers/admin/user_roles_controller.rb`, `admin/users_controller.rb` | Papéis e perfil na gestão de contas |
| `app/presenters/alert_detail_presenter.rb`, `publication_permissions.rb` | Visibilidade por leitor e botões |
| `app/presenters/{publication,comment}_projection.rb` | Projeções em lote |
| `app/services/alerts/{correct_content,remove_photo}.rb`, `users/update_profile.rb` | Services novos |
| `app/models/concerns/catalog_entry.rb`, `category.rb`, `location.rb`, `role.rb`, `alert.rb` | Travas de catálogo e validação de metadados do GPS |
| `app/models/concerns/text_search.rb` | Busca com variantes de caixa (SQLite) |
| `app/views/shared/alerts/*` | Formulário, localização, detalhe, histórico, fotos e painel de atendimento compartilhados |
| `app/views/layouts/portal*` | Layout do portal (desktop e celular, sem JS para navegar) |
| `app/javascript/controllers/{geolocation,category_details,reveal}_controller.js` | Estados de GPS, detalhamento da categoria, campos de encerramento |
| `config/routes.rb` | Rotas novas (seção 4) |

## 4. Rotas

**Portal (autenticado):**

- `GET /painel`
- `GET|POST /alertas`, `GET /alertas/new`, `GET /alertas/:id`
- `GET|PATCH /alertas/:id/edit|/alertas/:id`
- `PATCH /alertas/:id/audiencia`
- `POST|DELETE /alertas/:id/acompanhamento`
- `GET|DELETE /alertas/:alert_id/fotos/:id`
- `GET|POST /panico`
- `GET /atendimento`, `GET /atendimento/:id`
- `PATCH /atendimento/:id/{classificacao,responsavel,situacao}`
- `POST|DELETE /mural/:id/{curtida,salvo,acompanhamento}`
- `POST /mural/:id/comentarios`
- `GET|PATCH|DELETE /comentarios/:id(/edit)`
- `POST|DELETE /comentarios/:id/curtida`
- `GET|POST /mural/:id/denuncia/new|/mural/:id/denuncia` e `/comentarios/:id/denuncia`
- `GET /denuncias`, `GET /denuncias/:id`, `PATCH /denuncias/:id/reabrir`
- `GET /salvos`, `GET /acompanhamentos`, `DELETE /acompanhamentos/indisponiveis?tipo=salvos|publicacoes|alertas`
- `GET|PATCH /perfil(/edit)`
- `POST|DELETE /pessoas/:id/seguir`

**Público (sem login):** `GET /mural`, `GET /mural/:id`, `GET /comentarios/:id`, `GET /pessoas`, `GET /pessoas/:id`, `GET /pessoas/:id/seguidores`.

**Admin (somente `users.admin` ativo):**

- `/admin/ocorrencias` (index, show, new, create, edit e update = correção) + `PATCH …/{classificacao,responsavel,situacao,audiencia,restricao}`
- `/admin/categorias` e `/admin/locais` (CRUD sem destroy) + `PATCH …/{ativar,desativar}`
- `/admin/publicacoes` (CRUD sem destroy) + `PATCH …/{envio,revisao,publicacao,retirada}`
- `/admin/denuncias` (index, show) + `PATCH …/analise`
- `PATCH /admin/comentarios/:id/moderacao`
- `POST|DELETE /admin/users/:user_id/roles(/:code)`

Não há rota de exclusão para alertas, publicações, categorias, locais ou denúncias.

## 5. Matriz de permissões

| Ação | Anônimo | Conta comum | Autor | Coordenação | Segurança | Admin | Desativada |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Ler mural externo | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | só externo |
| Ler mural interno | – | ✓ | ✓ | ✓ | ✓ | ✓ | – |
| Registrar ocorrência/pânico | – | ✓ | ✓ | ✓ | ✓ | ✓ | – |
| Ler ocorrência interna (sem operacional) | – | ✓ | ✓ | ✓ | ✓ | ✓ | – |
| Ler registro restrito | – | – | ✓ (próprio) | ocorrências | pânico e atribuídos | ✓ | – |
| Coordenadas, autoria, fotos originais | – | – | ✓ | ✓ (o que atende) | ✓ (o que atende) | ✓ | – |
| Editar relato | – | – | ✓ (received/awaiting) | – | – | correção com motivo | – |
| Remover foto | – | – | ✓ (quando pode editar) | – | – | ✓ (motivo) | – |
| Fila `/atendimento` | – | – | – | ocorrências | pânico e atribuídos | tudo | – |
| Classificar e transicionar | – | – | – | ocorrências | pânico e atribuídos | ✓ | – |
| Reabrir `closed` | – | – | – | – | – | ✓ | – |
| Atribuir | – | – | – | ocorrências | pânico | ✓ | – |
| Restringir audiência | – | – | ✓ (só reduzir) | – | – | ✓ (ampliar com motivo) | – |
| Bloquear divulgação | – | – | – | – | – | ✓ | – |
| Editorial | – | – | – | – | – | ✓ | – |
| Comentar, curtir, salvar, acompanhar, denunciar | – | ✓ (acesso atual) | ✓ | ✓ | ✓ | ✓ | – |
| Editar ou apagar comentário | – | próprio | – | – | – | – | – |
| Moderar comentário, analisar denúncia | – | – | – | – | – | ✓ | – |
| Seguir perfil | – | público e ativo, não a si | | | | | – |
| Editar próprio perfil | – | ✓ | | | | ✓ (sem ativar opt-in de outros) | – |
| Conceder papéis | – | – | – | – | – | ✓ (não a si) | – |
| Entrar no `/admin` | – | – | – | – | – | ✓ | – |

## 6. Fluxos

- **Ocorrência**
  1. Formulário (chave UUID gerada no GET).
  2. `Alerts::CreateOccurrence`.
  3. Redireciona ao detalhe com o protocolo.
  - Repetir a mesma chave e conteúdo devolve o registro existente ("nada foi duplicado").
  - A mesma chave com outro conteúdo devolve 409 e o formulário preservado; só a opção explícita "é uma nova ocorrência" usa a chave substituta que veio no próprio formulário. Ela é estável em novas tentativas do mesmo envio.
- **Pânico**
  1. "Pedir ajuda".
  2. "Confirmar".
  3. GPS por até 6 s; sem resposta, segue como `timeout`, `permission_denied`… ou `not_shared` se a pessoa desmarcar.
  4. O payload é congelado e guardado em `sessionStorage`.
  5. `fetch` JSON.
  - Falha de rede ou resposta desconhecida mantém o pedido pendente, com "Reenviar o mesmo pedido".
  - 409/422 orientam conferir "Meus alertas".
  - Sem JS: formulário comum com a chave do servidor.
  - GPS tardio não altera o pedido congelado (teste em navegador).
- **Atendimento**
  1. Fila com filtros.
  2. Detalhe com Classificação, Responsável e Situação.
  - Encerrar exige motivo; `invalid`/`out_of_scope`/`other` exigem explicação.
  - Duplicidade usa um protocolo acessível; inacessível e inexistente dão o mesmo erro.
  - Reabrir `resolved` exige motivo; reabrir `closed` é só do admin.
  - `lock_version` antigo devolve 409, com os dados recarregados e o preenchimento mantido.
- **Editorial**
  1. Rascunho.
  2. Envio para revisão.
  3. Aprovar (vale para `reviewed_content_version` = versão exibida) ou rejeitar com motivo.
  4. Publicar (revalida aprovação atual, fonte, expiração e aviso com validade).
  5. Retirar (motivo).
  - Edição relevante volta a publicação para rascunho e "não enviada".
  - Uma publicação retirada pode voltar ao ar se a aprovação da versão atual continuar válida e a fonte for compatível. É uma ação explícita do admin; não foi criada uma regra nova.
- **Comentários e social**
  - Raízes paginadas (20) e até 5 respostas por raiz, com link para a conversa completa (respostas paginadas).
  - Pai buscado no scope de leitura; resposta a resposta, pai de outra publicação ou pai oculto são rejeitados.
  - Envio revalida acesso e `comments_enabled`.
  - Interações em POST/DELETE explícitos.

## 7. Campos, validações e catálogos

- **Ocorrência**
  - Título 5–160, descrição 10–5.000, categoria obrigatória.
  - Detalhamento até 500, obrigatório se a categoria exige; é descartado se a categoria não exige.
  - Severidade percebida opcional ("Não informar").
  - Audiência solicitada interna, restrita ou pública externa, com explicação.
  - Fotos opcionais (o RF007 continua pendente).
- **GPS**
  - Par lat/lon obrigatório e nas faixas válidas; formato numérico validado no servidor.
  - Precisão entre 0 e 100.000 m.
  - `location_captured_at` válido, no máximo 5 min no futuro e 24 h no passado. Só vale ao gravar um novo valor: registros antigos não quebram.
- **Manual:** local ativo; as coordenadas de referência do local **não** são copiadas para o relato.
- **Catálogos**
  - Inativos aparecem na edição como "(indisponível)" e não podem ser escolhidos de novo; registros antigos continuam válidos.
  - O `code` trava após o primeiro uso, e `requires_details` também (para categorias).
  - Códigos de papéis reconhecidos nunca mudam.
  - A validação de detalhamento passou a rodar só quando a categoria ou o detalhe mudam, para evitar que uma mudança no catálogo impeça o atendimento de alertas antigos.
- **Mídia e perfil**
  - Não há mídia editorial: fotos originais nunca vão ao mural.
  - Perfis não têm aba de posts: publicações são da equipe editorial e não transferem autoria do alerta.

## 8. Encerramento, retirada, tombstone e histórico

- **Excluir = encerrar.** Alertas são encerrados com motivo e continuam no histórico.
- **Retirada.** Publicações são retiradas com motivo; comentários, curtidas e denúncias são preservados, e novas interações ficam bloqueadas.
- **Comentários.** Apagar ou moderar é lógico: o HTML e as projeções não levam texto nem autoria, e as respostas de outras pessoas ficam. O admin vê o texto preservado na tela de moderação.
- **Auditoria.** `AuditEvent` continua append-only. Ações novas auditadas: `alert.content_corrected`, `alert.photo_removed`, `user.profile_updated`.
- **Histórico por leitor.**
  - Equipe: tudo, com ator e motivo.
  - Autor: eventos e motivos de mudança de situação, sem notas de classificação nem atribuição.
  - Leitor interno: apenas recebimento e mudanças de situação.

## 9. Migrations

Nenhuma migration nova; `db/schema.rb` não mudou. As regras novas são validações de model, sem constraints de banco. Não há backfill nem rollback a fazer.

## 10. Setup e operação local

```bash
bin/rails db:migrate                 # se houver pendências no banco local
bin/rails sgu:catalogs:bootstrap     # papéis e categorias, sem mexer em contas
bin/rails tailwindcss:build          # ou bin/dev
```

- **Reinicie o `bin/dev`** se ele já estava rodando: o watcher antigo do Tailwind regravou o CSS sem as classes novas durante este trabalho, e as telas ficavam sem estilo.
- Locais reais: cadastre só pontos verificados em `/admin/locais` (código, nome, posição; coordenadas opcionais em par).
- Papéis: em `/admin/users/:id`, conceda "Coordenação" ou "Segurança" para acessar a fila.

## 11. Comandos executados e resultados (02/10/2026)

Ambiente: devcontainer Linux; Ruby 3.4.8; Rails 8.1.3.1; SQLite; Selenium remoto para os testes JS.

| Comando | Resultado |
| --- | --- |
| `RAILS_ENV=test bin/rails db:prepare` | ok (banco de teste) |
| `bundle exec rspec` (baseline, antes das mudanças) | 465 exemplos, 0 falhas |
| `bundle exec rspec` (final) | **619 exemplos, 0 falhas**, cobertura de linhas 97,36% |
| `bundle exec rubocop` | 294 arquivos, sem ofensas |
| `bin/rails zeitwerk:check` | All is good |
| `bin/brakeman --no-pager` | 0 alertas, 0 erros |
| `bin/importmap audit` | sem pacotes vulneráveis (havia rede) |
| `bin/rails tailwindcss:build` | ok |
| `git diff --check` | ok |

**Observações:**

- Numa rodada intermediária, `presentation_navigation_spec.rb:101` falhou uma vez e passou isolado e na rodada final (intermitente, sem relação com as mudanças).
- As falhas reais de impressão do slide de funcionalidades foram corrigidas compactando o YAML.
- **Testes legados alterados de propósito:**
  - Usuário comum em `/admin` agora vai para `/painel`.
  - O login de não-admin vai para `/painel`.
  - O dashboard exige admin.
  - O detalhe de usuário é uma página própria.
  - `PublicIdentity` inclui `id: nil` quando o perfil é privado.

**Evidência das duas jornadas (navegador real):**

- `spec/features/alert_journey_spec.rb`: registro com GPS simulado, atendimento pela coordenação até "Resolvida" e acompanhamento pelo autor sem notas internas. Inclui o fallback de permissão negada e o erro de validação preservando os dados.
- `spec/features/editorial_journey_spec.rb`: rascunho, revisão, aprovação, publicação, leitura anônima, comentário, resposta, curtir, salvar, acompanhar, moderação, retirada e limpeza dos salvos.

## 12. QA visual

- **Como foi feito.** Um roteiro de capturas temporário (fora do repositório) gerou 31 telas em desktop (1280 px) e celular (390 px): landing, mural anônimo, painel, formulário, GPS negado, erros, alerta do autor, publicação com comentários e tombstone, salvos, perfil, pânico, fila, detalhe de atendimento, admin (dashboard, ocorrências, detalhe, categorias, locais vazios, publicação, nova publicação, denúncia, usuário e papéis).
- **Dados.** Fictícios e marcados "(demonstração)"; sem dados pessoais. A foto de teste é um PNG sintético.
- **Corrigido após a revisão.** Plural em português ("2 comentários"), concordância do selo de visibilidade, grade de fotos com formulário de remoção e alinhamento dos rádios.
- **Teclado e foco.** Links "Pular para o conteúdo", foco visível (`sgu-focus-ring`), menus por `<details>`, rótulos em todos os campos, `aria-invalid`/`aria-describedby` nos erros, `aria-pressed` nos botões de estado e `role=status` nas mensagens de GPS e pânico.
- **Não feito.** Auditoria com leitor de tela real, medição automática de contraste, testes em Safari/Firefox e em celular físico. Para a revisão, as capturas podem ser regeradas com Capybara (`page.save_screenshot`) a partir dos mesmos fluxos das features.

## 13. Segurança e desempenho

- **Uploads.** Assinatura PNG/JPEG no servidor; limite de 5 fotos com 5 MiB cada. Signed IDs de blobs alheios são ignorados (teste). Fotos são servidas só por `AlertPhotosController`, com 404 a cada pedido sem acesso; as rotas padrão do Active Storage continuam desativadas.
- **Remoção de foto.** Exige pertença do anexo ao alerta e `lock_version`. O expurgo do arquivo é feito por job depois do commit: falha na transação não apaga nada; falha no expurgo deixa um arquivo órfão inacessível.
- **Scopes.** Toda leitura passa por `policy_scope`/`FeedScope`/`HandlingScope` antes de busca, contagem e paginação.
- **Revogação.** Perda de papel, retirada, expiração ou restrição valem na requisição seguinte. Salvos e acompanhamentos não concedem acesso.
- **Escrita.** Identidade sempre da sessão; mass assignment limitado por allowlists nos controllers e services.
- **Open redirect.** `return_to` aceita só caminhos internos (testes com `https://`, `//` e `/\`).
- **CSRF.** Teste com `allow_forgery_protection` ligado. GET não altera estado.
- **Concorrência.** `lock_version` em atendimento, correção, edição de relato, publicação e comentário: 409 com recuperação. Interações usam índices únicos e upsert.
- **N+1.** O feed tem contagem de consultas estável ao crescer (teste); comentários e publicações usam projeções em lote. A fila e o admin usam `includes`.
- **Logs.** `latitude`/`longitude` já eram filtrados.

## 14. Premissas provisórias e ações humanas

- Locais oficiais da UFRPE: pendente.
- Requisitos do card #13 ainda abertos: RF005, RF007 (fotos continuam opcionais), RF009, RF012, visibilidade e cadastro institucional.
- A matriz de acesso segue a `AlertPolicy` provisória (coordenação para ocorrências; segurança para pânico e atribuídos).
- Validação humana das duas jornadas e das capturas: a fazer.
- Adaptar o layout do slide de funcionalidades se a equipe quiser imagem.
- Cadastro público e verificação institucional não foram criados.
- Alteração do privilégio `admin` continua fora das telas (console/seeds).

## 15. MR e comentário do card

**Descrição da MR (rascunho):**

```markdown
## Alertas, atendimento, mural e social do SGU
- Registro de ocorrência (GPS/manual, fotos, idempotência) e Meus alertas
- Pânico idempotente e restrito; fila de atendimento para coordenação/segurança
- Admin: ocorrências (correção auditada, audiência, restrição), categorias, locais, publicações, denúncias, papéis
- Mural público/interno, comentários (1 nível), curtidas, salvos, acompanhamentos, perfis opt-in e seguir
- /admin agora é exclusivo de administradores; demais contas entram em /painel
- Sem migrations. Testes: 619 exemplos, 0 falhas; RuboCop, Brakeman e importmap audit limpos
Documento: docs/alertas-crud-implementacao.md
```

**Tutorial curto para o card:**

```text
bin/rails sgu:catalogs:bootstrap && bin/dev   (reinicie o bin/dev se já estiver rodando)
1. Entre com test@test.com → Registrar ocorrência → use GPS → anote o protocolo.
2. Como dev@dev.com (admin), conceda "Coordenação" a uma conta em /admin/users.
3. Com essa conta, /atendimento → classifique e resolva; o autor vê a situação em Meus alertas.
4. Em /admin/publicacoes crie uma notícia → enviar → aprovar → publicar; veja em /mural.
```

## 16. Checklist da revisão no Codex

- [ ] `Admin::ApplicationController#require_admin_area`: o gate não pode marcar `verify_authorized`; conferir que toda ação de domínio chama `authorize`.
- [ ] `PublicationInteractionsController#destroy`, `AlertSubscriptionsController#destroy`, `CommentLikesController#destroy`, `FollowsController#destroy`: usam `skip_authorization` porque removem só o vínculo da sessão. Confirmar que nada além disso é afetado.
- [ ] `AlertDetailPresenter#history`: regras de quem vê motivo e ator.
- [ ] `PublicationProjection.collection`/`CommentProjection.collection`: equivalência com `as_json` e descarte do que está fora do scope.
- [ ] `PanicAlertsController#panic_params` e `panic_controller.js`: payload congelado e chave estável.
- [ ] `AlertsController#requested_client_request_id`: troca de chave só com escolha explícita.
- [ ] `Alerts::RemovePhoto`: transação, lock, expurgo após commit.
- [ ] `Users::UpdateProfile`: admin não ativa opt-in; campos aceitos.
- [ ] `Alert#category_details`/`#gps_capture_time`: só validam quando o valor muda.
- [ ] `TextSearch`: limitação de caixa no SQLite (Postgres resolveria com `ILIKE`/`unaccent`).
- [ ] `config.time_zone = "America/Recife"`: efeito em datas exibidas e em `datetime-local`.
- [ ] Testes legados alterados (seção 11) e comportamento novo de `/admin` para não-admins.
- [ ] Publicação retirada pode ser republicada sem nova revisão se a aprovação da versão atual continuar válida: decidir se isso é desejado.
