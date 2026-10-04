# Prompt — CRUD de alertas, atendimento e experiência social do SGU

> Prompt histórico utilizado para iniciar o CRUD. A orientação de preservar o exemplo do template foi substituída pelo pedido posterior de remoção; o cadastro público e o tema também foram ampliados. Este arquivo registra o escopo anterior, não as instruções atuais. Consulte [a revisão posterior](../sgu-cadastro-temas-revisao.md).

Você está no repositório Rails do **SGU — Sistema de Gerenciamento Urbano, projeto de Engenharia de Software da UFRPE, com recorte de comunicação e acompanhamento de ocorrências no campus**. Continue a implementação existente até entregar fluxos completos, utilizáveis e testados. Banco, models, policies, presenters e services já receberam trabalho importante. Sua missão é conectar essa base a controllers, rotas, formulários, telas administrativas e operacionais e à experiência social, corrigindo lacunas reais com alterações coerentes.

Este pedido é de **implementação**, não apenas de análise. Primeiro analise cuidadosamente, apresente um checkpoint curto com os achados e depois implemente as fases abaixo. Não encerre após entregar o formulário de criação de alerta ou escrever recomendações. Continue até completar o escopo autorizado. Havendo bloqueio verdadeiro, conclua o trabalho independente e explique precisamente o que falta.

## 1. Resultado esperado

Entregue uma funcionalidade completa para:

- Administrar categorias e locais; criar, consultar e editar ocorrências no admin; atender, classificar, atribuir, restringir, encerrar e, quando autorizado, reabrir alertas.
- Permitir que pessoas autenticadas registrem ocorrências na área adequada, consultem seus registros e acompanhem o atendimento, sem acesso indevido à administração.
- Registrar pânico na mesma entidade `Alert`, com fluxo próprio, rápido, restrito e idempotente.
- Criar e gerir publicações editoriais de ocorrências, avisos e notícias: revisão, aprovação, publicação, retirada e expiração.
- Disponibilizar feed, detalhes da publicação, comentários com respostas de um nível, curtidas de publicações e comentários, salvos, acompanhamento e perfis públicos opt-in com seguir/deixar de seguir.
- Permitir edição segura do próprio perfil, administração dos perfis institucionais e moderação de denúncias/conteúdo.
- Gerar documentação completa para eu trazer ao Codex e revisar a entrega.

O frontend agora **faz parte** da tarefa: precisamos usar essas funcionalidades, não apenas ter tabelas/endpoints. Use o Rails e as telas nativas do projeto.

Não acrescente recursos apenas porque são comuns em redes sociais. Esta atividade não exige pontuação, ranking, badges, recomendações algorítmicas, mensagens privadas, notificações push/e-mail, integração policial, rastreamento contínuo ou nova autenticação. Faça uma experiência agradável que incentive acompanhar o conteúdo pelo seu valor, sem inventar mecanismos de dependência.

## 2. Análise inicial e preservação do trabalho

Leia `AGENTS.md` e as instruções aplicáveis. Se delegar documentação, respeite `.agents/documentation-specialist.md`. Este pedido e os textos destinados à equipe são em português; priorize essa orientação sobre o idioma padrão de um perfil auxiliar.

Inspecione branch, status do Git, commits recentes e diffs. O estado verificado antes deste prompt era **main limpa, alinhada a origin/main, após o merge da card-11**; confira novamente, pois pode ter mudado. Preserve todo trabalho existente, inclusive alterações não commitadas. Se ainda estiver em main limpa, crie uma branch local descritiva para implementação; use o prefixo prescrito pelas instruções vigentes, sem inventar número de card. Se já estiver em branch de tarefa adequada, reutilize-a.

Não faça pull, stash automático, reset, checkout com perda, merge, commit, push, deploy ou criação de MR automaticamente. Rotina segura de branch local não precisa de confirmação; operações que descartem alterações não estão autorizadas.

Leia pelo menos:

- `docs/data-model-upgrade.md`, `db/schema.rb`, migrations, seeds e `lib/tasks/sgu.rake`.
- `config/presentation/requisitos.yml`, `planejamento.yml`, `data_diagrams.yml`, `diagramas.yml`, `funcionalidades.yml` e `entrega.yml`.
- Models, policies, presenters e services de alertas, publicações, comentários, interações sociais, denúncias, usuários e papéis.
- Controllers, rotas, concerns de autenticação, layout administrativo, sidebar, landing e padrões existentes de formulários/Turbo/Stimulus.
- Specs relevantes e configuração de execução local/CI.

PDFs e referências externas podem não estar disponíveis. Nesse caso, use fontes versionadas e registre a limitação, sem inventar conteúdo ausente. Se documento e código divergirem, exponha a divergência e use as regras implementadas/testadas como base operacional provisória. Não declare aprovados os requisitos ainda pendentes de decisão da equipe.

Confirme versões pelos arquivos e runtime. A base recente usa **Rails 8.1.3.1 e Ruby 3.4.8**, ERB, Tailwind, Turbo, Stimulus, Pagy, Pundit e autenticação nativa. SQLite é o banco atual. Reutilize `users`, catálogos, tabelas sociais e services. Não introduza Devise, React, outra base de dados, API paralela ou provedor obrigatório de mapas para concluir esta tarefa.

Registre baseline verdadeiro: o que funciona, o que existe apenas no domínio, rotas faltantes, testes executados e limitações de ambiente. Números de testes de revisões anteriores não são resultados da sua execução.

Apresente um checkpoint curto com arquitetura, lacunas, riscos e ordem de implementação; depois execute. Decida autonomamente detalhes rotineiros e reversíveis. Só interrompa parte dependente de decisão indispensável que não possa ser inferida da base, continuando o trabalho independente.

## 3. Contratos de arquitetura e autorização

### Alerta operacional e publicação editorial

`Alert` é o registro operacional: autoria, localização, categoria, severidade relatada, classificação, prioridade, status, responsabilidade e histórico. `Publication` é conteúdo editorial revisado que pode ir ao feed. Alerta não fica público por ter sido criado ou encerrado.

Pedido de divulgação externa significa solicitar revisão. Não autoriza exposição do alerta original, localização precisa, fotos privadas ou texto bruto. Pânico não gera publicação, curtida, comentário ou salvo.

### Papéis e áreas de acesso

Os códigos reconhecidos são `security`, `coordination`, `professor`, `student`, `staff`, `visitor` e `resident`. Usuário pode ter múltiplos papéis. `users.admin` continua separado e é a fonte do acesso administrativo. Segurança/coordenação não se tornam administradores automaticamente.

Mantenha a entrada administrativa restrita ao administrador. Crie área operacional autenticada para os demais atores com ações permitidas pelas policies, compartilhando componentes quando útil. Não afrouxe a proteção global do admin para dar a atendentes acesso a toda a administração.

### Controllers de domínio

O `Admin::BaseController` executa CRUD genérico com `save`, `update` e `destroy`; isso não atende sozinho às regras de atendimento/editoriais. Use controllers próprios ou herança explicitamente adaptada, sem contornar services nem manter callbacks incompatíveis.

**Armadilha concreta:** autorização dentro de `ApplicationService` não marca automaticamente o `verify_authorized` do controller. A base administrativa tenta queries CRUD como `create?`, `update?` e `destroy?`, enquanto `AlertPolicy` possui `create_occurrence?`, `update_content?`, `transition?` e outras queries de domínio. Não basta herdar e chamar um service. Estabeleça uma base/controller de domínio com `authorize` correto, `policy_scope` e callbacks compatíveis, sem desativar toda a verificação de autorização.

Consulte objetos por scopes autorizados, autorize cada ação e use services como entrada de escrita. Services novos devem ser pequenos, necessários e testados, preservando auditoria. Não copie regras de domínio para views/Stimulus nem concentre a aplicação em um controller gigante.

### Presenters e projeções

Reutilize `AlertOptionsPresenter`, `RoleOptionsPresenter`, `SelectOption`, `PublicationProjection`, `CommentProjection` e `PublicIdentity`. Opções de catálogos, severidades, prioridades e transições já têm regras de permissão; não duplique enums, traduções e opções nos templates.

`PublicationProjection` usa identidade editorial neutra, sem autor operacional/GPS/fotos originais. `CommentProjection` oculta corpo/autoria removidos. `PublicIdentity` só identifica publicamente conta ativa com opt-in. Preserve esses contratos em HTML, Turbo e JSON. Não serialize models inteiros com `as_json` genérico.

As projeções atuais podem executar reloads, counts e exists por registro. Otimize composição/agregações das listagens evitando N+1, mas mantenha autorização atual e semântica de privacidade. Não remova checagens de acesso para acelerar a tela.

## 4. Categorias, locais e opções de formulário

Entregue CRUD administrativo utilizável para `Category` e `Location`: policies, listagem, busca, ordenação segura, paginação, criação, edição e ativação/desativação. Use campos reais: código estável, nome, posição, ativo/inativo, detalhes exigidos pela categoria e coordenadas de referência do local quando existirem. Respeite validações dos models.

A ocorrência tem **uma categoria**, portanto select simples. Papéis do usuário são múltiplos, mas pertencem a outro domínio.

- Categoria “Outros” ou qualquer categoria com `requires_details` exige detalhamento do alerta.
- Novos registros/associações usam entradas ativas e ordenadas.
- Item inativo já associado permanece no histórico e aparece na edição como indisponível para nova escolha, sem invalidar o registro antigo só por ter sido desativado.
- Não exclua fisicamente entradas associadas; prefira desativação com rótulo que explique o efeito.
- Preserve códigos utilizados. Analise efeitos de alterar `code` ou `requires_details` de entrada já usada; não reescreva histórico silenciosamente. Quando mudar a semântica, prefira desativar/substituir e documente a decisão, sem inventar versionamento de catálogo desnecessário.
- Bootstrap `sgu:catalogs:bootstrap` é idempotente, preservando nomes editados, extras e desativações. Mantenha o contrato.

O catálogo de locais começa vazio por falta de dados oficiais da UFRPE. **Não invente prédios, coordenadas ou pontos oficiais.** Entregue cadastro e estado vazio explicando a pendência. Localização manual exige local ativo; GPS válido pode permitir o registro sem catálogo manual. Dados fictícios de teste/demonstração devem ser isolados, identificados e apenas opt-in em ambiente seguro, nunca inseridos silenciosamente como oficiais.

Não transforme papéis reconhecidos em CRUD livre de códigos arbitrários nem crie papel `admin`. Gerenciar os vínculos dos papéis existentes atende ao escopo. Não permita editar códigos de `Role` de forma que quebre reconhecimento ou escale privilégio.

## 5. Criação e edição de ocorrência

Entregue admin e área autenticada de registro, compartilhando componentes. Use `Alerts::CreateOccurrence`, ator da sessão e options presenters. Formulário:

- Título entre 5 e 160 caracteres; descrição entre 10 e 5.000.
- Categoria obrigatória; detalhamento até 500 quando exigido.
- Severidade relatada independente da prioridade. Respeite se é opcional no domínio; permita “Não informado” sem gravidade fictícia.
- Pedido de visibilidade com explicação de interno, restrito e pedido de divulgação externa.
- GPS ou seleção manual de local ativo, com campos/estados específicos de cada modo.
- Fotos opcionais segundo os limites abaixo.

Fotos continuam opcionais enquanto o conflito RF007 não for aprovado pela equipe. Não torne proposta pendente uma obrigação silenciosa.

Autoria, protocolo, status inicial, severidade avaliada, prioridade, responsável, visibilidade efetiva, bloqueio editorial e timestamps internos pertencem ao backend e a ações autorizadas. Não aceitar `author_id`, status, prioridade ou campos internos por mass assignment. Admin também cria com autoria do ator atual; não implemente criação arbitrária “em nome de outra pessoa” sem contrato próprio.

### Localização

GPS exige latitude/longitude juntas, faixas válidas e validação no servidor. Acurácia e instante de captura são exclusivos do GPS. Seleção manual referencia `Location`; não copie suas coordenadas de referência para campos que significam captura GPS do relato.

Solicite geolocalização só após ação clara. Mostre carregamento, autorização negada, timeout, indisponibilidade e fallback manual. Ocorrência comum não aceita `unavailable` conforme a regra atual; explique isso, sem coletar silenciosamente nem preencher coordenadas fictícias.

Não confie cegamente em timestamps/números do navegador; valide pares, formato e coerência dos metadados, corrigindo lacunas com testes. Filtre parâmetros sensíveis de logs. Não torne mapa pago, chave externa ou geocodificação requisito: seleção manual e coordenadas para quem está autorizado atendem ao início.

### Envio e edição

Associe erros aos campos, preserve preenchimento, mostre protocolo e ofereça retorno a “Meus alertas”. Use identificador idempotente estável por intenção de criação também para ocorrência; duplo clique/retry não pode gerar dois registros. Mudança incompatível com a mesma chave gera conflito claro; nova chave representa nova intenção, não toda tentativa técnica.

A regra atual permite edição do conteúdo pelo autor em `received` ou `awaiting_information`. Preserve isso. Para admin editar conteúdo de outro autor, implemente autorização separada e service auditado apropriado. Não amplie silenciosamente `update_content?` a qualquer ator/status nem contorne o contrato com CRUD genérico.

Separe edição de conteúdo, classificação, audiência, atribuição e transição. Campos imutáveis não devem aparecer como inputs escondidos de um formulário genérico.

## 6. Fotos e anexos protegidos

Reutilize `Alerts::PhotoUpload`: máximo 5 fotos PNG/JPEG de até 5 MiB cada, com assinatura validada no servidor. Extensão e MIME declarado pelo cliente não bastam.

Originais são operacionais e mais restritos que a leitura do alerta: autor e quem atende, conforme `show_photos?`. Não inclua suas URLs em feeds, galerias públicas ou previews de leitores internos sem essa permissão.

Endpoints padrão do Active Storage estão desativados; preserve isso. Use `AlertPhotosController` e `GET /alertas/:alert_id/fotos/:id`, verificando alerta, associação do attachment e autorização vigente. Inexistência/acesso indevido devem produzir 404 sem revelar arquivo. Não reative rotas públicas só para facilitar previews.

Não aceite signed IDs de blobs de outra pessoa como anexos do alerta. Prefira o upload controlado existente. Direct upload exigiria desenho completo de propriedade/autorização e não é necessário para concluir.

Se oferecer remoção individual, crie service autorizado e auditado que valide a pertença de cada attachment. Não purgue blob arbitrário por ID. Documente/teste a relação entre transação de dados, exclusão física posterior e falhas/concorrência; filesystem não tem atomicidade perfeita de banco. Erros não podem vazar blobs órfãos nem apagar fotos válidas inadvertidamente.

Não acrescente processamento de imagens só para thumbnails; arquivos autorizados com dimensões CSS podem bastar. Distinga **originais privados do alerta** de eventual **mídia editorial própria da publicação**. Feed textual, identidade editorial e ícones com interações reais satisfazem o início; documente que não há postagens com fotos se não forem implementadas.

Se decidir adicionar imagem editorial por necessidade justificada, implemente armazenamento/anexos próprios, sanitização incluindo EXIF/GPS, autorização por audiência/estado editorial e testes. Nunca exponha original operacional por signed URL nem reutilize foto privada como mídia pública. Essa evolução é opcional, não um bloqueio para concluir o restante.

## 7. Admin, atendimento e histórico

Entregue listagem administrativa com busca por protocolo/título, filtros úteis por tipo, categoria, status, prioridade, visibilidade, local, responsável e período. Ordenação/colunas em allowlist e Pagy. Filtros sempre dentro do scope autorizado, sem registros restritos em busca ou autocomplete.

Organize detalhes em identificação, relato, categoria/localização, severidade relatada, classificação do atendimento, estado, responsável, fotos permitidas e histórico. Ofereça ações por `Alerts::Assess`, `Assign`, `Transition`, `ChangeAudience` e `Restrict`; opções pelo presenter/policy.

- Severidade relatada, avaliada e prioridade são dimensões distintas. “Ainda não classificado” não significa prioridade baixa.
- Respeite `Alert::TRANSITIONS`; não use select livre de todos os estados.
- Encerramento exige motivo. `invalid`, `out_of_scope` e `other` exigem observação. Duplicado exige referência válida, sem auto referência/ciclo; a seleção não revela alertas inacessíveis.
- Reabertura exige motivo; reabrir `closed` é administrativo. Respeite também a reabertura de `resolved` existente.
- Atribuição só oferece contas ativas elegíveis, conforme ator/tipo. Revalide no backend.
- Audiência/bloqueio têm efeitos editoriais; services devem tratar retirada/revisão sem copiar conteúdo privado.
- Use `lock_version`. Conflito concorrente retorna 409 e oferece recuperação sem sobrescrever silenciosamente outro atendimento nem perder preenchimento.
- Audit events são append-only, sem CRUD editável. Histórico mostra somente eventos/campos permitidos, sem notas privadas/coordenadas para leitores indevidos.

### O significado de excluir

O pedido de CRUD não autoriza apagar evidência, autoria e auditoria. A base não possui regra universal de exclusão lógica de `Alert`; não implemente `destroy!` físico por conveniência.

Prefira **encerramento com motivo**, já existente. Caso arquivamento seja realmente necessário, defina a semântica e faça migration progressiva/testes, preservando histórico. Não chame “Excluir” uma ação que apenas encerra sem explicar. Documente a interpretação do CRUD e não reescreva migrations antigas.

### Área operacional

Pessoas comuns precisam de “Registrar ocorrência”, “Meus alertas”, detalhes permitidos, edição autorizada e acompanhamento. Coordenação/segurança precisam de filas compatíveis com policies, sem navegação administrativa indiscriminada.

A policy distingue autoria, coordenação, segurança, atribuição e ocorrência/pânico. Leia-a inteira, preserve limites e não copie matriz presumida de documentação antiga. Lacuna necessária deve ser tratada explicitamente com justificativa e teste.

## 8. Pânico: mesma tabela, fluxo próprio

Use `Alerts::CreatePanic`, `kind: panic`, sempre restrito. Não exija título longo, descrição, categoria, foto ou catálogo manual.

Entregue botão acessível, identificado e confirmação intencional curta. Após confirmar, envie com os dados disponíveis; não espere indefinidamente permissão GPS/timeout. Ausência de localização utiliza modo/motivo permitidos e não impede o envio.

A chave idempotente é obrigatória: uma chave por intenção confirmada, mesma chave e payload em retries. Não gere nova UUID automaticamente a cada tentativa. GPS que chega depois não pode alterar silenciosamente o payload do retry; se atualizar localização for necessário, use ação separada autorizada ou estratégia explícita que não duplica o registro.

Trate falha de rede, resposta desconhecida e conflito 409, orientando a verificar protocolo/resultado antes de iniciar nova intenção. Apenas desabilitar botão não garante idempotência.

Mensagem precisa: o **sistema recebeu o registro**, não que uma pessoa atendeu ou que socorro/viatura foi acionado. Entregue fila restrita aos atores autorizados. Não implemente promessa de despacho, rastreamento contínuo ou integração policial ausente.

`AlertSubscription` é para ocorrência, não pânico. Não adicionar feed, curtidas, comentários, salvos ou divulgação neste fluxo.

## 9. Publicações: CRUD editorial seguro

Entregue listagem, criação, detalhes e edição próprios para `Publication`, com `Publications::Create`, `Update`, `Submit`, `Review`, `Publish`, `Withdraw` e `SyncWithSource`.

Tipos `occurrence`, `notice` e `news`. Ocorrência divulgada exige fonte compatível; aviso/notícia não recebem alerta artificial. Uma ocorrência tem no máximo uma publicação derivada. Fonte e tipo são imutáveis após criação conforme o model.

Título de 5–160, corpo de 10–10.000, audiência permitida, comentários habilitados/desabilitados e expiração apropriada. Aviso publicado exige expiração. Fonte selecionável vem de scope autorizado e `Publication.compatible_sources_for`, sem pânicos/alertas incompatíveis na busca.

Ofereça rascunho, envio à revisão, aprovação/rejeição com motivo obrigatório quando aplicável, publicação e retirada. Mostre separadamente estado e revisão: aprovado não significa publicado.

Mudança relevante invalida aprovação anterior conforme `content_version`/`reviewed_content_version`. Revisão e publicação revalidam versão, acesso e concorrência. Fonte alterada marca revisão/sincronização, sem publicar automaticamente sua descrição operacional.

Fonte com `publication_blocked` ou audiência solicitada incompatível não pode continuar exposta porque uma publicação histórica ainda possui `state: published`. Avalie compatibilidade por `Publication.compatible_sources_for` e pelos services. Um alerta que solicita `public_external` mantém visibilidade operacional `restricted`, e isso é esperado: esse valor isolado não impede a aprovação/publicação editorial externa. Reduzir a audiência solicitada para restrita ou aplicar bloqueio editorial pode invalidar a fonte. Preserve filtragem dinâmica e efeitos do domínio após mudança de acesso, expiração ou alteração da fonte.

Retirada preserva histórico e impede novas interações que dependam do acesso. Não exclua fisicamente publicações com comentários, denúncias/vínculos. Exclusão de rascunho sem referências só se houver contrato explícito, autorizado e testado; caso contrário, use ciclo editorial e documente a limitação.

## 10. Feed e detalhes

Crie feed/página de publicação com identidade SGU, paginação, estados vazios e filtros/busca úteis. Público anônimo só recebe publicação externa, aprovada para conteúdo atual, publicada, não expirada e com fonte permitida. Conteúdo interno depende de autenticação e policy.

Exemplos da landing são demonstrativos. Não faça a landing consultar alertas operacionais nem transforme exemplos fictícios em dados oficiais. Integre acesso claro ao feed/área autenticada sem quebrar apresentação/conteúdo institucional.

Cartões mostram título, trecho seguro, tipo, data, contagens corretas e ações autorizadas. Não expor GPS, email, autoria operacional, fotos privadas ou notas de atendimento fora da projeção.

Anônimo lê conteúdo externo autorizado; interação requer login. Preserve retorno legítimo após entrar, sem open redirect externo. Usuário comum não vai ao admin como destino padrão.

Autorização deve valer para request direto, Turbo, JSON, busca, autocomplete, salvos, perfis e contagens. Esconder botão não basta. Não revelar nem quantidade de registros ocultos por consulta fora do scope. Abrir página/GET não cria vínculo nem segue alguém automaticamente.

## 11. Comentários e respostas

Comentários pertencem a `Publication`, não a `Alert`. Use `Comments::Create`, `Update`, `Delete`, `Moderate` e policy.

- Corpo de 1–2.000, texto simples escapado; não usar `html_safe`. Trate links/quebras de linha com segurança.
- Respostas de **um nível**, pai raiz da mesma publicação; rejeite IDs de outra publicação, resposta a resposta e alvo sem autorização.
- Conta ativa, acesso atual e comentários habilitados são revalidados no envio, mesmo após página aberta antes de retirada/bloqueio.
- Autor edita/remove conforme policy; indique edição quando apropriado.
- Remoção lógica preserva respostas. Texto/autoria removidos não ficam em HTML oculto, atributos `data-*`, JSON, Turbo ou preview; use tombstone e `CommentProjection`.
- Moderação administrativa exige motivo. Conteúdo oculto não aceita novas respostas/curtidas quando a regra impedir.
- Remover pai não apaga silenciosamente respostas de outras pessoas.

Paginar raízes e carregar respostas controladamente, sem árvore ilimitada. IDs de DOM únicos, formulário claro para responder/editar, erro no local correto.

## 12. Curtidas, salvos, acompanhamento e seguir

Use `Social::Interactions` e índices únicos. Separe:

- Curtir/descurtir publicação e comentário.
- Salvar/remover publicação dos próprios salvos.
- Acompanhar/deixar de acompanhar publicação.
- Acompanhar/deixar de acompanhar ocorrência autorizada.
- Seguir/deixar de seguir perfil público elegível.

Salvar, acompanhar publicação, acompanhar ocorrência e seguir pessoa são ações/tabelas diferentes. Use rótulos/ícones claros; não converta tudo em coração.

Adição/remoção idempotentes: endpoints explícitos POST/DELETE, sem toggle ambíguo em retry. Concorrência não duplica vínculos/contagens. Usuário vem da sessão, nunca de `user_id` do cliente.

Interação nova exige acesso atual. Bookmark/assinatura não concede acesso se conteúdo ficou restrito, expirou ou foi retirado. Meus salvos/acompanhamentos filtram pela autorização vigente.

Os serviços permitem limpar vínculo próprio após perda de acesso. Remova via scope do próprio vínculo sem mostrar detalhes do alvo privado nem remover vínculo alheio. Remover vínculo próprio não equivale a poder ler o objeto.

Bookmarks/assinaturas são privados. Não mostrar identidades de quem salvou ou listas públicas de assinantes. Contagens seguem projeções atuais, incluindo exclusão de contas desativadas onde prevista. Não exponha atividade individual de likes sem decisão explícita de privacidade.

Follow exige perfil ativo/público opt-in, proíbe seguir a si e não concede acesso privado. Opt-out/desativação revalidam visibilidade, listas, contagens e novas interações; seguir alguém nunca torna sua conta pública nem a reativa. A base não possui um estado inativo de `UserFollow` nem exige apagar vínculos históricos no opt-out. Preserve os dados, registre e teste o comportamento dos vínculos quando o perfil voltar a ser público, sem inventar um novo ciclo de consentimento como requisito aprovado.

Não há entidade de notificação nesta base. Entregue vínculos/telas honestamente, sem prometer e-mail, push ou aviso em tempo real inexistente.

## 13. Perfil e administração de usuários

### Próprio perfil

Crie área autenticada para editar `display_name` até 80, `username` de 3–30 minúsculas `[a-z0-9_]` e único quando preenchido, `bio` até 500 e `public_profile`. Respeite normalização/validação; opt-in começa falso. Username é opcional no model atual. Se a rota pública usar username, trate perfil público sem username com rota autorizada por ID ou regra explícita compatível com contas existentes, sem gerar link inválido nem exigir migration só por preferência de URL.

Policy/action própria, sem liberar o CRUD administrativo de `UserPolicy` para conseguir editar o próprio perfil. Strong params só destes campos; não aceitar email, senha, admin, deleted_at, roles ou nested attributes sensíveis como efeito colateral.

### Perfil público

Só conta ativa com opt-in, seguindo `PublicIdentity`. Mostre nome, username quando houver, bio e ação de seguir permitida. Se não há avatar no schema, iniciais/ícone bastam; upload de avatar não é requisito desta entrega.

Não mostrar email, sessão, papéis internos, sinalizadores administrativos, alerta restrito, GPS, bookmarks ou histórico privado. Listas/contagens de seguidores respeitam elegibilidade atual, sem revelar quem optou pela privacidade.

Não invente publicações próprias para usuário comum: a criação editorial atual é administrativa, com identidade editorial neutra, e `Publication.author` não é automaticamente o autor do alerta. Não transfira autoria nem exponha origem operacional para fabricar perfil estilo Instagram. Atividade pública só se for compatível e útil; prefira omitir aba de posts artificial e documentar essa decisão.

### Administração

Amplie a gestão existente com campos de perfil e concessão/revogação por `Roles::Grant`/`Roles::Revoke`. Preserve auditoria; não escreva join table diretamente por select sem domínio.

Mudar privilégio `admin` é operação sensível distinta de editar bio/papel institucional. Preserve controles e teste autoelevação. Desativação usa `Users::Deactivate`, preserva histórico e invalida sessões conforme contrato.

Cadastro público/verificação institucional têm decisões pendentes. Não crie signup que permite escolher segurança/coordenação/admin nem declare aprovado o fluxo institucional. Conclua perfis de contas existentes/gestão administrativa; documente dependências dos requisitos.

## 14. Denúncias e moderação

Entregue denúncia por usuário autorizado e área administrativa de listagem/filtro/análise/estado. Use `ContentReports::Create`, `Review`, `Reopen`, validando alvo/acesso atual. Policies adicionais apenas quando necessárias.

Identidade/motivo do denunciante não aparecem publicamente na postagem. Proteja dados na listagem administrativa, sem endpoint aberto de denúncias.

Revisão de denúncia e moderação são operações distintas. Não retire publicação implicitamente sem regra/auditoria explícita. Ofereça ação autorizada de remover comentário por `Comments::Moderate` ou retirar publicação por `Publications::Withdraw`, com motivo e resultado claro.

Preserve histórico/tombstones. Gerir denúncia pelo ciclo de análise/reabertura não precisa de CRUD destrutivo aberto que apague evidência.

## 15. Interface, segurança e organização

Use identidade SGU verde/dourado, espaçamento, tipografia e componentes existentes. Interface bonita, profissional e clara, sem complexidade que esconda o significado das ações.

Revise desktop/celular, teclado, labels, foco, contraste e mensagens. Inclua estados vazios, loading, sucesso/erro, cancelamento, geolocalização recusada e conflito. Não dependa só de cor/hover. Tooltip complementa informação, não a substitui.

Formulários HTML como base, Turbo/Stimulus como melhoria. Confirme funcionamento sem JS nos fluxos suportados; localização manual não depende de GPS. Evite nested forms, IDs duplicados, listeners repetidos e streams substituindo registro incorreto.

Compartilhe partials/helpers para reduzir duplicação real; opções/traduções pelos presenters/I18n. Regras de domínio ficam no backend. Comentários de código curtos, úteis, em português quando adequado: topo de controller/model/policy e regras não óbvias de privacidade, histórico, concorrência/idempotência. Evite narrar cada linha ou textos repetitivos.

Erros consistentes: 404 para inexistente/inacessível sem revelar existência; 403 para ação negada em contexto autorizado; 422 validação; 409 concorrência/idempotência. Ajuste ao contrato atual documentando diferenças. Não use rescue genérico para esconder bugs.

Mudança de estado exige método correto, autenticação, CSRF e autorização no servidor. Não confiar em IDs, roles, visibilidade/timestamps do cliente. Scopes antes de busca/ordenação/contagens/paginação.

Faça eager loading, agregações e índices necessários. Meça/teste queries das páginas principais, sem prometer desempenho só por ter um `includes`. Otimização não pode expor conteúdo revogado/contadores proibidos.

Preserve diagramas HTML/CSS, logos, perfis e organização da apresentação; não substitua por SVG. Não remova `Dog`/testes legados em massa como limpeza incidental. Se a navegação do exemplo confundir, ajuste-a com cuidado e explique o alcance.

## 16. Dados existentes e execução segura

Não recrie `User`, `Alert`, `Publication`, catálogos/tabelas sociais: use a base existente. Lacuna real de schema exige migration nova, com defaults/backfill/constraints e impacto explicado. Não edite migration já aplicada. Teste upgrade com usuários/alertas/vínculos antigos; rollback destrutivo só em banco descartável.

Execute migrations/bootstrap somente no alvo local/teste identificado. Preserve dados persistentes antes de operações relevantes. Não usar `db:drop`, `db:reset` ou recriação de base para esconder problema.

Para catálogos ausentes, `bin/rails sgu:catalogs:bootstrap`. Evite `db:seed` para esse fim: seeds de desenvolvimento alteram contas demonstrativas. Não redefina senha, reative conta ou crie locais oficiais fictícios como efeito colateral.

QA usa fixtures/factories ou preparação isolada explícita. Não fabrique evidência de reunião, retrospectiva, aprovação editorial, funcionalidade ou campus oficial.

## 17. Fases de implementação e critérios de conclusão

Implemente incrementalmente, mantenha o sistema utilizável e rode testes durante o trabalho:

1. **Diagnóstico/contratos:** baseline, permissões, rotas, lacunas de services/policies e premissas.
2. **Catálogos/criação:** admin de categorias/locais, presenters, ocorrência, GPS/manual, uploads e idempotência.
3. **Atendimento/pânico:** edição permitida, filas, classificação, atribuição, transições, restrição, encerramento/reabertura e histórico.
4. **Editorial/leitura:** publicações, revisão/versionamento, publicação/retirada/expiração, feed e projeções.
5. **Social/perfis:** comentários/respostas, likes, salvos, assinaturas, follows, perfis, roles e moderação.
6. **Integração:** desempenho, segurança, acessibilidade/mobile, regressões e handoff.

Não use a divisão em fases para parar antes de concluir sem bloqueio real. Checklist final:

- [ ] Admin cadastra categoria/local, ativa/desativa e mantém associações antigas.
- [ ] Conta ativa registra ocorrência com localização válida, recebe protocolo, consulta registro; erros preservam dados e são compreensíveis.
- [ ] Identidade/privilégios vêm da sessão; retries não duplicam alertas.
- [ ] Fotos respeitam limites/assinatura e só são lidas/removidas por quem pode; URLs privadas não vazam.
- [ ] Pessoas comuns, coordenação, segurança e admin acessam apenas telas/ações permitidas; atendimento completo funciona.
- [ ] Encerramento/reabertura/classificação/audiência/atribuição respeitam domínio, motivos, auditoria e concorrência.
- [ ] Pânico funciona sem GPS, restrito/idempotente/com protocolo; nunca entra no social.
- [ ] Editorial aprova a versão atual e reavalia fonte/expiração/retirada em leitura/interação.
- [ ] Feed externo/interno segue audiência e autorização sem exposição operacional.
- [ ] Comentários de um nível, edição/tombstones/moderação corretos sem corpo/autoria escondidos no payload.
- [ ] Likes, salvos, assinaturas e follows separados, idempotentes, com privacidade apropriada.
- [ ] Próprio perfil sem autoelevação; perfil opt-in e acesso/listas/contagens reavaliados após opt-out/desativação.
- [ ] Denúncia/moderação privadas, explícitas e auditadas.
- [ ] Desktop/mobile/teclado, estados vazios/erro/loading e conflitos revisados.
- [ ] Dados/apresentação preservados; testes/checks reais registrados.
- [ ] Documento final permite revisão no Codex e contém MR/comentário curto do card.

## 18. Testes e verificação final

Use model/service/policy/request/feature specs do projeto para riscos/fluxos reais; não apenas espelhe métodos. Matriz com anônimo, autor, outro usuário, desativado, admin, coordenação e segurança; papéis comuns quando fizerem diferença. Use contas distintas para verificar propriedade/acesso alheio.

Casos essenciais:

- GPS/manual, catálogo vazio/inativo, detalhes de categoria, pares/metadados inválidos, autoria/privilégios adulterados e limites de texto.
- PNG/JPEG válidos, assinatura incompatível, excesso de tamanho/quantidade, attachment alheio/replay de blob e acesso revogado antes do download.
- Repetição/concorrência com mesma chave, payload conflitante, `lock_version` antigo e formulário preservado após 409.
- Pânico sem localização, chave estável, equipes autorizadas e impossibilidade de publicação/social.
- Transições proibidas/permitidas, motivos, duplicado inválido/cíclico, assignee inativo e audiência restrita.
- Aprovação de versão antiga, edição relevante, fonte alterada/bloqueada, expiração/retirada após abrir página.
- Comentário em publicação inacessível/desabilitada, pai de outra publicação, profundidade inválida/pai oculto, XSS escapado e remoção sem texto/autoria em HTML/JSON/Turbo.
- Likes idempotentes/concorrentes, remoção de vínculo próprio, bookmark/assinatura sem concessão de acesso e limpeza após revogação sem revelar alvo.
- Self-follow/perfil privado/inativo, opt-out/desativação e contagens/identidades; ausência de email/bookmarks/alertas privados em perfil.
- Autoelevação no perfil, atendimento sem privilégios, admin inacessível ao usuário comum, sessões desativadas, CSRF/métodos incorretos.
- Histórico com catálogo inativo, associação nova rejeitada e bootstrap preservando edição; se houver migrations, upgrade com dados/constraints e rollback descartável.

Valide duas jornadas inteiras:

1. Pessoa registra → equipe autorizada atende → muda estado/resolve → autor acompanha, com privacidade.
2. Admin prepara/revisa/aprova/publica → leitor acessa → comenta/responde/curte/salva/acompanha → retirada/moderação revoga exposição/ações corretamente.

Execute suite completa e checks no runtime correto. Referências, confirmando executáveis/configuração:

```bash
bin/rails tailwindcss:build
RAILS_ENV=test bin/rails db:prepare
bundle exec rspec
bundle exec rubocop
bin/rails zeitwerk:check
bin/brakeman --no-pager
bin/importmap audit
git diff --check
```

`RAILS_ENV=test bin/rails db:prepare` prepara explicitamente o banco de teste, como na CI, sem apontar para desenvolvimento ou produção. Migration pendente usa `bin/rails db:migrate`; catálogos faltantes usam bootstrap específico. Confirme alvo antes.

Audit importmap pode exigir rede. Se indisponível, registre “não concluído” e o motivo, sem resultado limpo fictício. Faça o mesmo com browser/containers/scanners; execute o possível. Corrija regressões introduzidas. Falha preexistente exige baseline e evidência de independência.

Faça QA visual real de admin, registro, GPS/fallback, validação/conflito, feed, comentários, salvos, perfil e moderação em desktop/celular, incluindo teclado/Turbo. Screenshot usa dados identificados de demonstração, sem dados pessoais/fotos privadas.

## 19. Apresentação e documento de implementação

Atualize só documentos/configurações relevantes para o funcionamento final, evitando duplicação. Preserve a organização da apresentação. Em `config/presentation/funcionalidades.yml`, registre duas jornadas realmente completas/testadas, como registro/atendimento e editorial/interação. Implementar código não confirma requisito acadêmico, RF pendente, reunião, retrospectiva ou validação humana. Mantenha as pendências honestas.

Crie obrigatoriamente **`docs/alertas-crud-implementacao.md`**, em português, para eu voltar ao Codex e solicitar revisão. Deve ser independente deste chat e conter:

1. Entrega utilizável e limitações.
2. Arquitetura Alert/Publication, services/controllers/policies/presenters/projections e decisões.
3. Principais arquivos alterados/criados com caminho real/finalidade, sem reproduzir o diff.
4. Rotas/ações implementadas em admin, operacional e público.
5. Matriz de permissões por ator/ação, incluindo fotos/moderação/perfil.
6. Fluxos de ocorrência, pânico, atendimento/reabertura, editorial, comentários/social.
7. Campos/validações/seletores, catálogos ativos/inativos, localização/uploads e decisão de mídia editorial/perfil sem posts pessoais.
8. Semântica de encerramento/retirada/tombstone e histórico/auditoria.
9. Migrations novas, se houver, defaults/backfill/constraints, efeito nos dados antigos/rollback.
10. Setup/operação local curtos e verificados, cadastro de locais reais, sem credenciais reais.
11. Comandos executados, ambiente, resultados reais, falhas/limitações e evidência das duas jornadas; não reutilizar contagens antigas.
12. QA visual/screenshots disponíveis, dados demonstrativos e verificações não realizadas.
13. Segurança/desempenho: uploads, scopes, revogação, idempotência, concorrência e N+1.
14. Premissas provisórias/ações humanas: locais oficiais, decisões de requisitos, evidências acadêmicas e o que falta para retomar.
15. Descrição curta de MR em Markdown e tutorial **muito curto** para comentário do card, com comandos realmente necessários e fluxo essencial. Não inventar número de card.
16. Checklist de revisão posterior no Codex com riscos/arquivos que merecem atenção.

Atualize guias existentes quando a mudança os tornar incorretos, sem espalhar instrução idêntica em README/reports/comentários. Se algo ficou fora por segurança ou decisão/dado ausente, especifique o item, motivo e próximo passo.

## 20. Resposta final

Resuma em português o que está utilizável, como acessar, resultados realmente obtidos, caminho do documento e pendências. Bloqueios materiais separados; não trate trabalho parcial como completo.

Não crie commit/MR/push/deploy sem pedido posterior. Não escreva apenas um prompt para outro agente nem ofereça implementar depois: **analise e implemente agora, de ponta a ponta, respeitando a base existente**.
