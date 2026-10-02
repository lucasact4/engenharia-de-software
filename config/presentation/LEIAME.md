# Apresentação do SGU — guia de manutenção

A apresentação pública fica em `/apresentacao`. O conteúdo vem dos YAMLs desta pasta; os perfis de exibição ficam no banco e são editados em **Admin → Apresentação**. O painel **Personalizar apresentação** altera somente a aba aberta.

## Qual slide atende a cada exigência?

**“Protótipo com o conceito visual do projeto” é o nome do slide da segunda entrega**, com o id `conceito-visual`. Selecione as capturas da landing, login e celular, a paleta e as notas para mostrar as telas existentes. O subitem **Protótipo de referência (Figma ou similar)** serve para um material separado; hoje está vazio. O enunciado não exige Figma.

Os nomes vêm de `entrega.yml` → `entregas[].exigencias`, conforme a entrega escolhida no perfil. Cabeçalho, índice, contador, admin e painel usam essa mesma fonte. O selo **2ª entrega · Item 1** identifica a exigência; **04**, por exemplo, é a posição atual do slide e muda quando a seleção muda. Procure pelo nome e pelo id, não por um número fixo.

Cada perfil recomendado segue a ordem do enunciado: capa, itens da entrega, itens do status report (somente na segunda) e encerramento. O catálogo também permite complementos, mas eles começam desmarcados. Slides sem exigência correspondente recebem o selo **Complementar**. Capa e encerramento ficam sempre visíveis.

### Primeira entrega

| Item | Nome exibido | Id | Conteúdos a selecionar |
| --- | --- | --- | --- |
| 1 | Lista de requisitos refinada | `requisitos` | Requisitos funcionais; Requisitos não funcionais; Critérios de aceite; Documento e card de refinamento |
| 2 | Lista de ferramentas e tecnologias escolhidas | `arquitetura` | Tecnologias utilizadas; Versões. A arquitetura pode complementar a fala. |
| 3 | Diagrama de casos de uso do sistema/App proposto | `casos-de-uso` | Marcar o slide e preencher o diagrama em `diagramas.yml`; não possui subitens. |
| 4 | Ferramenta de monitoramento dos projetos ativa com os requisitos e links para ambientes — Trello | `gestao` | Quadro do Trello; Cards e requisitos do projeto; Links para ambientes |
| 5 | Planejamento dos próximos passos do projeto | `proximos-passos` | Marco demonstrável; Lista de próximos passos; Riscos; Dependências |
| 6 | Reflexão sobre o período (Lições aprendidas) | `retrospectiva` | Pontos discutidos; Ações combinadas; Lições aprendidas |

### Segunda entrega — Status Report 2

| Item | Nome exibido | Id | Conteúdos a selecionar |
| --- | --- | --- | --- |
| 1 | Protótipo com o conceito visual do projeto | `conceito-visual` | Captura da landing; Captura do login; Captura no celular; Paleta de cores; Notas sobre as capturas. Protótipo de referência apenas quando houver material separado. |
| 2 | GitHub criado e estruturado com código fonte total ou parcial, contemplando as 2 funcionalidades do sistema proposto (Completas) | `funcionalidades` | GitHub e estrutura do código; Critérios de “completa”; Funcionalidade 1; Funcionalidade 2 |
| 3 | Imagem de uma retrospectiva | `retrospectiva` | Imagem da retrospectiva; o aviso permanece enquanto a equipe não anexar o registro real. |
| 4 | Modelo conceitual | `modelo-conceitual` | Diagrama do modelo conceitual; Produção, revisão da equipe e premissas; Diferença para o modelo físico do banco |
| 5 | Evidência de reuniões de monitoramento do projeto | `reunioes` | Registros das reuniões |
| Status report | O que foi feito desde a última entrega | `evolucao` | Linha do tempo (commits), limitada aos marcos posteriores à primeira entrega. Situação das capacidades é opcional e começa desmarcada. |
| Status report | O que será feito até a próxima entrega | `proximos-passos` | Marco demonstrável; Lista de próximos passos; Riscos; Dependências |
| Status report | O que aprendemos nesse sprint (Imagem de uma retrospectiva) | `status-report` | Lições aprendidas pela equipe; Ações combinadas para a próxima sprint; Referência à imagem da retrospectiva. |

Na segunda entrega, a sequência tem **8 slides de conteúdo**, além de capa e encerramento: os 5 itens da entrega, depois os 3 itens do status report. Na primeira, são **6 slides de conteúdo**, além de capa e encerramento, na ordem da tabela. A ordem vem dos vínculos em `entrega.yml` → `exigencias[].slides` e se aplica à apresentação, índice, admin, personalização e PDF.

O item 2 reúne GitHub e as duas funcionalidades em uma única tela. `evolucao` mostra somente o que foi feito; `proximos-passos` mostra o planejamento; `status-report` mostra os aprendizados. A imagem da retrospectiva aparece no item 3 e é referenciada no slide de aprendizados, sem repetir a imagem. Na primeira entrega, `retrospectiva` mostra pontos discutidos, ações combinadas e lições aprendidas.

**O modelo conceitual já existe em HTML/CSS**, distinto do DER físico, dos casos de uso e do fluxo. Sua produção técnica está concluída; a revisão da equipe e a aprovação das premissas continuam pendentes.

Os perfis recomendados estão em `db/seeds/presentation_profiles.rb`. A tarefa de preparação cria apenas perfis ausentes e preserva seleções editadas. Nesta reorganização, os dois perfis existentes foram ajustados explicitamente conforme o pedido, com cópia anterior em `tmp/presentation-profiles-before-simplification-20261002.json`; a **Segunda entrega — Status Report 2** permanece ativa (10 slides, estimativa de 5min20s). A **Primeira entrega** fica inativa (8 slides, estimativa de 3min55s). Não conte com a tarefa de preparação para reorganizar um perfil antigo: revise-o no admin.

Os conteúdos extras continuam disponíveis, desmarcados: problema e proposta, escopo, fluxo de ocorrências, detalhes de GitHub (`repositorio`), requisitos em conflito, DER físico e suas visões, evidências, checklist e roteiro/tempo. Tecnologias e Trello pertencem à primeira entrega e ficam fora do perfil recomendado da segunda. Eles podem ser habilitados para uma consulta específica, mas aumentam a sequência e o PDF.

A segunda entrega permite no máximo 7 minutos; confira a estimativa no admin e faça um ensaio.

## Conteúdo, catálogo e perfis

| Camada | Onde fica | Como alterar |
| --- | --- | --- |
| Textos, imagens, links e evidências | YAMLs desta pasta e `app/assets/images/presentation/` | Por commit |
| Slides, conteúdos, tempos e padrões | `roteiro.yml` e partials em `app/views/presentations/slides/` | Por commit |
| Nomes, ordem por entrega e vínculo com exigências acadêmicas | `entrega.yml` → `exigencias` | Por commit |
| Seleção por ocasião | Tabela `presentation_profiles` | Admin → Apresentação |
| Ajustes temporários | Memória da aba aberta | Personalizar apresentação |

Um checkbox significa **exibir conteúdo**, não **exigência cumprida**. Não cria imagens ou registros e não edita o texto. A confirmação da equipe fica em `confirmado_pela_equipe` nas exigências de `entrega.yml`.

Tudo do catálogo é renderizado no HTML público, mesmo oculto pela seleção. Não coloque dados confidenciais nesses arquivos.

## Preparar e usar os perfis

No terminal do Dev Container:

```bash
bin/rails db:migrate
bin/rails sgu:presentation:profiles
```

A segunda tarefa carrega somente `db/seeds/presentation_profiles.rb`, cria os perfis ausentes e preserva os existentes. O `db:seed` completo também redefine senha, acesso administrativo e exclusão dos usuários de exemplo em desenvolvimento; prefira a tarefa específica para preparar perfis. Em um banco novo, use `db:prepare` conforme o setup do projeto.

Sem perfil ativo, a página usa os `padrao` do roteiro e a `entrega_padrao`. Abrir a página nunca cria registros.

1. Entre como administrador e abra **Admin → Apresentação** (`/admin/apresentacao`). Usuários comuns não acessam a tela.
2. Abra **Novo perfil** ou **Editar seleção**. Escolha nome, entrega, slides e seus conteúdos.
3. A entrega muda capa, rodapé, nomes dos slides, selos, checklist e limite de tempo. **Não troca os checkboxes automaticamente**; para outra seleção pronta, abra o perfil correspondente.
4. Capa e encerramento são obrigatórios. Desmarcar um slide guarda suas escolhas internas; marcar um slide sem nenhum conteúdo visível o omite da sequência.
5. Clique em **Salvar configurações**. Valores inválidos e chaves fora do catálogo atual são recusados.
6. **Usar como padrão** escolhe o perfil público. Só um fica ativo; o ativo não pode ser excluído. **Visualizar** abre `/apresentacao?perfil=<id>` sem mudar o padrão.

A estimativa soma apenas os slides principais selecionados; apêndices não entram no tempo, mas entram no PDF quando marcados. A duração real depende do ensaio.

### Ajustes temporários

Em **Personalizar apresentação**, as mudanças recalculam sequência, índice, contador, progresso, numeração, apêndices e impressão. **Concluir** só fecha o painel. **Restaurar padrão do perfil** ou recarregar desfaz os ajustes; nada é salvo no banco nem no navegador.

Se o slide atual for ocultado, a página segue ao próximo visível, ou ao anterior quando necessário. Tab/Enter operam o painel e Esc o fecha. Sem JavaScript, o modo leitura usa o perfil salvo e não oferece o painel.

### Catálogo e compatibilidade

As chaves salvas são `<id do slide>` e `<id do slide>.<id do conteúdo>`, como `reunioes.registros`. Não dependem do título ou da posição.

- Para um novo slide, adicione `id`, `titulo`, `tempo` e `padrao` ao roteiro e crie sua partial, trocando hífens por underscores no arquivo.
- Para um conteúdo, adicione-o a `conteudos` e marque o bloco na partial com `presentation_item`. `presentation_group` oculta contêineres vazios; `dentro_de` define dependência do conteúdo pai.
- Chaves ausentes usam o `padrao`. Mude títulos sem renomear ids para preservar perfis.

O campo `substitui` permite herdar escolhas antigas. Os ids dos slides de evolução, planejamento, retrospectiva e aprendizados foram preservados; os antigos conteúdos `status-report.feito` e `status-report.proximo` saíram do catálogo para evitar duplicação. `status-report.aprendizados` continua válido. Ao salvar um perfil, as chaves removidas deixam de fazer parte da seleção. Para os complementos extraídos do antigo slide de gestão, `repositorio` herda `gestao` e `gestao.praticas`; `repositorio.praticas` herda `gestao.praticas`. `reunioes` herda `gestao` e `gestao.reunioes`; `reunioes.registros` herda `gestao.reunioes`.

Entre as chaves antigas presentes no perfil, todas precisam estar marcadas. Sem nenhuma delas, vale o padrão da chave nova. Uma escolha explícita nova tem prioridade. Ao salvar pelo formulário, as escolhas resolvidas usam o catálogo atual; não apague o JSON antigo antes de conferir a seleção.

## Onde atualizar cada coisa

| Conteúdo | Arquivo |
| --- | --- |
| Equipe, disciplina, links, entregas, títulos, exigências, prazos e limites | `entrega.yml` |
| Catálogo, tempo, responsáveis, padrões e apêndices | `roteiro.yml` |
| Problema, público, conflitos, RF/RNF e critérios de aceite | `requisitos.yml` |
| Marcos, capacidades e data da primeira entrega | `evolucao.yml` |
| Capturas, paleta e protótipo separado | `conceito_visual.yml` |
| Critérios e evidências das duas funcionalidades | `funcionalidades.yml` |
| Situação, produção, revisão, versão e origem dos diagramas | `diagramas.yml` |
| Tabelas, colunas, vínculos, conceitos, arquitetura e disposição | `data_diagrams.yml` |
| Renderização e estilo dos diagramas | `app/views/presentations/shared/_er_diagram.html.erb` e `app/assets/stylesheets/presentation.css` |
| Stack, logos, fontes de versões, mudanças e justificativas | `tecnologias.yml` |
| Trello, ambientes, práticas do GitHub e reuniões | `gestao.yml` |
| Imagem, pontos, ações e lições da retrospectiva | `retrospectiva.yml` |
| Marco, próximos passos, riscos e dependências | `planejamento.yml` |

O slide de aprendizados (`status-report`) usa apenas `retrospectiva.yml`; ele não repete os marcos nem os próximos passos. Em `/apresentacao?modo=leitura`, notas tracejadas indicam o arquivo a atualizar; somem na apresentação e no PDF.

Estados válidos: `implementado`, `parcial`, `planejado`, `aguardando_decisao` e `aguardando_evidencia`. Só marque implementado com evidência verificável. Uma proposta continua aguardando decisão até haver aprovação registrada.

## Diagramas em HTML/CSS

DER, modelo conceitual e arquitetura usam `_er_diagram.html.erb` e `PresentationDiagram`, sem imagem SVG para o desenho. O catálogo define entidades, colunas, relações e coordenadas; a altura acompanha a quantidade de linhas e o modelo calcula os caminhos das conexões. O DER informa a versão de `db/schema.rb`.

Ao criar migrações, atualize `tables`, `foreign_keys` e as visões pertinentes em `data_diagrams.yml`. Os apêndices operacional, social e de infraestrutura devem cobrir todas as colunas. `required` e `unique` das FKs determinam as cardinalidades; relações polimórficas são tracejadas e ficam em `relations`.

`presentation_profiles` aparece na infraestrutura, sem vínculo inventado com o domínio. Configura a apresentação e não representa um conceito do SGU.

Selecione uma entidade para destacar suas conexões e ler vínculos e cardinalidades na faixa acima do desenho. **Ampliar** mantém essa interação. As relações também aparecem por escrito. No celular há rolagem interna para preservar o texto; revise o PDF após alterar a disposição.

Em `diagramas.yml`, produção técnica, revisão da equipe e premissas são independentes. O modelo conceitual foi produzido no card #6; não gere outro para atender a essa entrega. Depois da revisão, registre estado, data e responsáveis em `revisao_equipe`, além da versão e situação geral.

Para uma imagem fornecida pela equipe, salve-a em `app/assets/images/presentation/` e use caminho relativo a `app/assets/images`, com descrição, origem, versão e data quando aplicáveis. Diagramas pendentes de casos de uso e fluxo podem ser exportados em PNG/SVG; os desenhos nativos existentes permanecem HTML/CSS. Só URLs públicas HTTP(S) viram links; caminhos locais aparecem como texto.

## Tecnologias e versões

Os cards mostram logo local ou símbolo neutro, nome e função. Os assets ficam em `app/assets/images/presentation/logos/`; fontes e condições de uso estão em `tecnologias.yml`. Um símbolo neutro não representa a marca.

Quando **Versões** está selecionado dentro de **Tecnologias utilizadas**:

- Passe o mouse ou foque um card com Tab para ver a dica; Esc a fecha.
- **Mostrar versões** exibe os dados abaixo de todos os cards; **Ocultar versões** recolhe. O estado vale só na página aberta.
- Desmarcar Versões oculta dicas, dados e botão. Ocultar Tecnologias utilizadas também oculta suas versões.
- Na impressão, as versões selecionadas aparecem mesmo recolhidas na tela. Sem JavaScript, aparecem abaixo dos cards.

Cada versão possui `rotulo` e uma fonte: `gem` lê o `Gemfile.lock`; `ruby_version_file: true` lê `.ruby-version`; `sqlite_engine: true` lê a biblioteca SQLite carregada; `texto` explica ferramentas sem versão única. Gem de integração não é confundida com a tecnologia subjacente. Tailwind identifica integração Rails e pacote do CLI; SQLite identifica adaptador Ruby e motor.

## Materiais que ainda dependem da equipe

| Material | O que falta |
| --- | --- |
| Requisitos (card #13) | Resolver conflitos, aprovar RF/RNF e critérios de aceite; registrar documento e versão em `requisitos.yml`. |
| Casos de uso (card #14) e fluxo (card #5) | Produzir os diagramas aprovados, anexar imagem e registrar origem/versão/data em `diagramas.yml`. Um não substitui o outro nem o conceitual. |
| Conceito visual | Validar as capturas existentes; o slide público avisa que essa validação está pendente e que os alertas exibidos são demonstrativos. Protótipo separado só se escolhido pela equipe. |
| Duas funcionalidades | Escolher e implementar duas jornadas completas; preencher requisitos, passos, código, specs, captura e validação em `funcionalidades.yml`. Backend do card #6 sozinho não comprova uma jornada completa. |
| Modelo conceitual | Revisar multiplicidades e premissas, registrar aprovação. Foto opcional, visibilidade restrita e acessos de coordenação/segurança dependem do card #13. |
| Retrospectiva | Realizar a dinâmica, anexar imagem real e registrar data, formato, pontos, ações e lições em `retrospectiva.yml`. |
| Reuniões | Registrar reuniões realizadas: data, tipo, participantes, pauta, decisões e evidência em `gestao.yml`. |
| Trello e ambientes | Preencher link do card #11 e conferir acesso da professora; só cadastrar URL de homologação depois de deploy real. |
| Próxima entrega | Decidir marco demonstrável, responsáveis e data da apresentação; ensaiar por até 7 minutos. |

Campos vazios indicam pendências, não convites para inventar evidências. Confirme `confirmado_pela_equipe: true` apenas após revisão. A linha do tempo inclui o card #6 integrado à main em 02/10/2026; commits de melhorias ainda locais ficam sem link até serem publicados.

Para refazer capturas: abra `/` e `/entrar` com o sistema rodando, registre tamanho desktop/mobile, aguarde fontes e imagens e capture sem menus cobrindo o conteúdo. Oculte temporariamente pelo inspetor o aviso de credenciais de desenvolvimento; não inclua senhas ou dados pessoais. Atualize caminhos, descrições, notas e `capturado_em` em `conceito_visual.yml`. Informe commit somente se corresponder ao código capturado; alertas estáticos mantêm `demonstrativo: true`.

## Executar e gerar PDF

No terminal do Dev Container, inicie `bin/dev` e abra `http://localhost:3000/apresentacao`. Não inicie outra instância se já estiver rodando. Confira o endereço encaminhado na aba **Portas** do VS Code; outro projeto pode ocupar a mesma porta no computador.

Pelo navegador, use **Imprimir / salvar PDF** ou Ctrl+P. A folha de estilos define A4 paisagem, um slide por página, incluindo apêndices selecionados. A impressão respeita ajustes temporários e remove controles e notas de manutenção. Ative gráficos de plano de fundo.

Para exportar com Selenium, inicie um servidor adicional em outro terminal do Dev Container:

```bash
RAILS_DEVELOPMENT_HOSTS=rails-app bin/rails server -b 0.0.0.0 -p 3100 -P tmp/pids/apresentacao-3100.pid
```

Com o serviço Selenium ativo, em outro terminal:

```bash
bundle exec ruby script/exportar_apresentacao_pdf.rb
```

O script abre `http://rails-app:3100/apresentacao?modo=leitura` e grava `tmp/apresentacao/sgu-segunda-entrega.pdf`; aceita outro destino como argumento. `localhost` dentro do Selenium não aponta para o Rails. As portas 3000/3100 são encaminhadas pelo Dev Container; confirme o endereço efetivo em **Portas**. Encerre só o servidor adicional com Ctrl+C ao terminar.

O script exporta uma página nova com o perfil ativo; ajustes temporários não entram. Para outro perfil salvo:

```bash
APRESENTACAO_URL="http://rails-app:3100/apresentacao?modo=leitura&perfil=<id>" bundle exec ruby script/exportar_apresentacao_pdf.rb
```

Substitua `<id>` pelo link Visualizar do admin. `SELENIUM_REMOTE_URL` tem padrão `http://selenium:4444/wd/hub`, definido pelo Dev Container. Se alterar o host, confirme que Selenium o alcança e Rails o aceita.

Abra o PDF novo e confira todas as páginas, cortes, diagramas, textos e links. A pasta `tmp/` é ignorada pelo Git: compartilhe o arquivo final explicitamente.

## Verificações

Os specs com JavaScript precisam de Selenium; Capybara inicia seu próprio servidor, sem exigir a porta 3100.

```bash
bundle exec rspec spec/models/presentation_spec.rb spec/models/presentation spec/models/presentation_profile_spec.rb \
  spec/models/presentation_diagram_spec.rb spec/policies/presentation_profile_policy_spec.rb spec/requests/presentations_request_spec.rb \
  spec/requests/admin/presentation_profiles_request_spec.rb spec/helpers/presentations_helper_spec.rb \
  spec/features/presentation_navigation_spec.rb spec/features/presentation_diagrams_spec.rb spec/features/admin/presentation_profiles_features_spec.rb
```

Esses arquivos cobrem catálogo, imagens e links internos, seleção por perfil, restrição do admin, navegação, ajustes temporários, impressão, títulos por entrega e correspondência do DER com o banco de teste. O spec de navegação inclui dicas e expansão das versões no celular e exportação real pelo script com carregamento de logos. Testes automatizados não confirmam acesso da professora a links externos, aprovação acadêmica nem duração real. Confira links sem sessão da equipe, leia o PDF e ensaie.

A revisão desta atualização, o tutorial curto e os textos para MR/card estão em [docs/presentation-upgrade-review.md](../../docs/presentation-upgrade-review.md).
