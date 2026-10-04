# Cadastro, temas e revisão do SGU

> Occurrence-publication follow-up: [Occurrence posts, public review, and verification](occurrence-social-flow.md) describes the current same-post workflow, administrator badge, descriptive locations, and private feed media. Earlier test counts and occurrence editorial rules in this document describe the previous delivery.

Revisão de 03/10/2026 da implementação iniciada em `feat/alertas-crud-social`. Este documento complementa o [registro original do CRUD](alertas-crud-implementacao.md): as verificações de 02/10 não representam a validação das mudanças descritas aqui.

## Cadastro e acesso

O cadastro público fica em `/criar-conta`, com acesso pela landing e por `/entrar`. Campos obrigatórios:

- Nome, com até 80 caracteres.
- E-mail com domínio exatamente `@ufrpe.br`. Subdomínios e outros domínios não atendem à regra; espaços nas extremidades e letras maiúsculas são normalizados.
- Perfil: visitante (`visitor`), professor (`professor`) ou estudante (`student`).
- Senha de pelo menos 8 caracteres, contendo maiúscula, minúscula, número e símbolo. O limite de 72 bytes corresponde ao limite do bcrypt; caracteres acentuados podem ocupar mais de um byte.
- Confirmação da senha.

O servidor revalida os campos. Selecionar um perfil concede apenas o papel correspondente: não concede administração, coordenação ou segurança. A conta começa com perfil público desativado, preservando o opt-in de `/perfil`.

**E-mail ainda não verificado:** o cadastro informa que a confirmação por e-mail não está implementada. O domínio é validado como texto, mas não prova que a pessoa possui a caixa de e-mail ou pertence à UFRPE. `email_verified_at` permanece vazio e não libera nem bloqueia o acesso nesta fase. O flag interno `email_verification_enabled = false` registra essa limitação; alterá-lo não implementa um fluxo de confirmação.

### Aprovação provisória

`SGU_AUTO_APPROVE_REGISTRATIONS` é lido quando a aplicação inicia:

| Valor | Comportamento dos novos cadastros |
| --- | --- |
| Ausente ou `true` | Conta aprovada automaticamente e autenticada após o cadastro. |
| `false` | Conta pendente; só poderá entrar após aprovação administrativa. |

Para testar aprovação manual dentro do ambiente de desenvolvimento, pare o `bin/dev` atual e inicie:

```bash
SGU_AUTO_APPROVE_REGISTRATIONS=false bin/dev
```

Volte ao comportamento provisório com:

```bash
SGU_AUTO_APPROVE_REGISTRATIONS=true bin/dev
```

A variável afeta cadastros novos; não reclassifica contas já existentes. Defina-a no ambiente em que o processo Rails realmente roda, incluindo o container quando utilizado. Reinicie o servidor após mudar o valor.

### Revisão administrativa

Somente administradores ativos acessam `/admin/cadastros`. Essa área trata contas criadas pelo cadastro público; contas legadas continuam na gestão de usuários.

- **Aprovar:** libera o acesso de uma conta pendente ou anteriormente reprovada, preservando sua autoria e seus dados.
- **Reprovar:** exige motivo, bloqueia novos logins e encerra as sessões existentes.
- O administrador, a data e o motivo da revisão ficam registrados; as ações são auditadas.
- O administrador não pode revisar a própria conta por esse fluxo.

A aprovação de cadastro não altera `users.admin` nem concede papéis adicionais. Contas desativadas por `deleted_at` continuam desativadas; aprovar um cadastro não substitui a gestão de desativação.

### Contas existentes e senhas

A migração mantém contas antigas como `approved`, sem mudar e-mails, senhas, privilégios administrativos, desativações ou o opt-in público. O requisito institucional vale para novos cadastros públicos: as contas de demonstração existentes continuam funcionando.

As regras de complexidade são aplicadas no cadastro e na troca de senha. O login continua aceitando senhas legadas para evitar bloquear contas existentes. Nome, e-mail, perfil, decisão de aprovação e senha não são campos intercambiáveis: o cadastro público não aceita escolher estado de aprovação nem poderes administrativos.

## Migrações e dados

| Arquivo | Alteração |
| --- | --- |
| `db/migrate/20261003100000_remove_legacy_dogs.rb` | Remove a tabela de exemplo. O rollback recria uma tabela vazia. |
| `db/migrate/20261003100100_add_registration_review_to_users.rb` | Acrescenta estado, perfil solicitado, dados de revisão, referência ao administrador e `email_verified_at`. |

Estados válidos: `pending`, `approved`, `rejected`. O perfil solicitado aceita somente os três códigos públicos ou `NULL` para contas legadas. Existem constraints no banco e validações no modelo.

A migration histórica de criação do exemplo e a fixture de schema antigo permanecem para testar atualizações de bancos existentes. Não são funcionalidades do sistema atual. Recuperar linhas removidas exige restaurar um backup; rollback de schema não recupera esses dados.

Antes da aplicação local das duas migrações, foi criado um backup consistente pela API SQLite e verificada sua integridade: `tmp/backups/development-before-registration-20261003-051841.sqlite3`. Naquele momento havia 2 usuários e 0 linhas na tabela de exemplo. Esse arquivo é local, ignorado pelo Git e não substitui uma política de backup para ambientes compartilhados.

Consulte [Atualização do modelo de dados](data-model-upgrade.md) para ensaio em banco isolado, integridade, limites de rollback e restauração. Migre sem resetar contas:

```bash
bin/rails db:migrate
RAILS_ENV=test bin/rails db:migrate
bin/rails sgu:catalogs:bootstrap
```

O bootstrap insere apenas papéis e categorias ausentes. Não use `db:seed` em um banco compartilhado só para criar catálogos: os seeds de desenvolvimento podem redefinir as contas de demonstração.

## Tema e manutenção visual

O modo escuro é o padrão em landing, autenticação, portal, admin e apresentação. O botão de sol/lua alterna os temas; a preferência fica em `localStorage` sob a chave `sgu.theme`, acompanha a navegação Turbo e é sincronizada entre abas da mesma origem. Na ausência de preferência salva, ou quando o armazenamento está indisponível, o padrão continua escuro. A impressão utiliza superfícies claras.

| Arquivo ou diretório | Responsabilidade |
| --- | --- |
| `app/assets/stylesheets/theme.css` | Paleta compartilhada, botão de tema, impressão clara e preferência por movimento reduzido. |
| `app/assets/javascripts/theme.js` | Aplicação síncrona da preferência no head, alternância, persistência e sincronização. |
| `app/views/shared/_theme_head.html.erb` e `_theme_toggle.html.erb` | Inclusão comum dos assets e controle acessível de tema. |
| `app/assets/tailwind/application.css` | Manifesto de compilação do Tailwind. |
| `app/assets/tailwind/{tokens,base,components,admin,portal,auth}.css` | Cores semânticas, regras básicas e componentes por área. |
| `app/assets/stylesheets/presentation.css` | Manifesto da apresentação; preserva a ordem dos imports. |
| `app/assets/stylesheets/presentation/` | Treze módulos: `tokens`, `base`, `deck`, `slides`, `content`, `academic`, `customization`, `delivery`, `responsive`, `print`, `diagrams`, `adjustments` e `theme`. |

Para mudar uma cor comum, ajuste a variável correspondente em `theme.css`. Nos templates e componentes Tailwind, prefira as classes semânticas definidas por `tokens.css`, como `bg-surface`, `text-ink` e `border-line`; evite repetir valores de cor por página. A apresentação tem variáveis próprias, adaptadas pelo módulo `presentation/theme.css`.

Compile com `bin/rails tailwindcss:build` ou mantenha `bin/dev` rodando. Não edite `app/assets/builds/tailwind.css` diretamente: ele é resultado da compilação. Regras específicas de uma área pertencem ao seu módulo, e a ordem dos manifests faz parte da cascata.

Os diagramas continuam em HTML/CSS. O DER foi atualizado para representar as seis novas colunas de cadastro/revisão em `users` e a referência `registration_reviewed_by_id` à própria tabela, com reposicionamento das entidades operacionais para evitar sobreposições. A autoria operacional permanece separada da identidade editorial do mural.

O rodapé identifica a equipe como **Equipe UFRPE de Engenharia de Software**.

### Ajustes encontrados na revisão

- O helper que formatava nomes de arquivos foi renomeado para `presentation_file_path`, evitando colisão com a rota `presentation_path` e corrigindo o botão administrativo **Visualizar**.
- Os slides sociais descrevem as telas que já existem; o planejamento passou a indicar a validação do cadastro institucional e a homologação dos fluxos existentes, pois o formulário já foi desenvolvido e a verificação do e-mail continua pendente.
- Slides inativos no celular ficam imediatamente ocultos, evitando sobreposição durante a navegação.
- A lista administrativa de cadastros usa cartões no celular para manter os dados e as ações legíveis.


## Verificações da revisão

A suíte completa executada independentemente **antes destas melhorias** passou com 619 exemplos e 0 falhas. A suíte final passou com **629 exemplos, 0 falhas**, seed `8542`, em 97,71 s.

| Verificação final | Resultado |
| --- | --- |
| `bundle exec rspec` | 629 exemplos, 0 falhas. |
| `bundle exec rubocop` | 296 arquivos, sem ofensas. |
| `bin/rails zeitwerk:check` | OK. |
| `bin/brakeman --no-pager` | 0 erros, 0 alertas. |
| `bin/importmap audit` | Sem vulnerabilidades nos pacotes auditáveis; Preline local sem versão ignorado. |
| `git diff --check` | OK. |
| Servidor reiniciado | `bin/dev` ativo na porta 3000; `/`, `/entrar` e `/criar-conta` responderam HTTP 200. |

A contagem final incorpora a remoção dos testes específicos do exemplo e a inclusão dos novos cenários; a diferença líquida de exemplos não corresponde ao número de testes acrescentados.

O Tailwind foi compilado. O resultado de `importmap audit` não representa uma auditoria do arquivo local do Preline, cuja versão não é identificável pelo comando.

A medição dos 12 pares semânticos de texto/fundo em cada tema resultou em contraste mínimo de **6,39:1 no escuro** e **5,76:1 no claro**. Os pares medidos superam 4,5:1; essa verificação da paleta não substitui uma auditoria completa de contraste de todas as combinações renderizadas, navegação assistiva ou leitores de tela.

### Navegador, impressão e banco local

O roteiro final de QA em navegador passou com 1 exemplo e 0 falhas, seed `49770`, em 27,76 s. Foram geradas e revisadas **84 capturas** combinando escuro/claro e desktop/celular, com dados fictícios em ambiente de teste isolado. Não houve transbordamento horizontal das páginas; diagramas largos no celular usam rolagem interna.

As capturas e o relatório de contraste ficam em `tmp/sgu-theme-qa/`. Os PDFs de teste têm **10 páginas** com o perfil ativo e **13 páginas** ao incluir os três DERs opcionais, com um slide por página. As 13 páginas foram renderizadas e inspecionadas, sem cortes. Esses artefatos são locais e não versionados.

Não foram realizados testes com leitor de tela, Safari, Firefox ou celular físico. A revisão visual e os testes automatizados não substituem a homologação das jornadas pela equipe.

Após o último ajuste dos textos de planejamento, 28 testes de `Presentation`/`PresentationDiagram` passaram, seed `8725`.

O banco de desenvolvimento foi conferido após as migrações: 2 usuários aprovados, 7 papéis, 7 categorias e 0 locais oficiais. A tabela de exemplo está ausente, `integrity_check` retornou `ok`, `foreign_key_check` não apontou erros e não havia migrações pendentes. Uma nova execução do bootstrap criou 0 itens, confirmando sua idempotência nesse banco.

Para repetir as verificações no Dev Container:

```bash
bin/rails tailwindcss:build
bin/rails zeitwerk:check
bundle exec rubocop
bin/brakeman --no-pager
bin/importmap audit
bundle exec rspec
git diff --check
```

`bin/importmap audit` requer acesso à rede. O CSS deve ser recompilado após mudanças e o `bin/dev` reiniciado se o watcher estiver usando uma configuração antiga.

## Pendências reais

- Implementar confirmação de posse do e-mail com envio, token, prazo e reenvio antes de considerar a identidade institucional comprovada.
- Definir quando desligar a aprovação automática e quem revisará os cadastros.
- Preencher o catálogo de locais apenas com dados oficiais confirmados da UFRPE.
- Validar as jornadas com a equipe e resolver os requisitos ainda abertos do card #13; as fotos de ocorrência continuam opcionais.
- Decidir se uma publicação retirada pode voltar ao ar mantendo uma aprovação ainda válida. A revisão de cadastro não altera essa regra editorial.

## Tutorial curto para o card

```text
1. Rode db:migrate, sgu:catalogs:bootstrap e reinicie bin/dev.
2. Em /criar-conta, cadastre um e-mail @ufrpe.br e escolha visitante, professor ou estudante.
3. A liberação é automática nesta fase; o aviso informa que o e-mail ainda não foi verificado.
4. Como admin, abra /admin/cadastros para aprovar ou reprovar com motivo.
5. Reprovar encerra as sessões e bloqueia o login; aprovar libera novamente.
6. O tema começa escuro; o botão de sol/lua alterna e salva a preferência.
```
