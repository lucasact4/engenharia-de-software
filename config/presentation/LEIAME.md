# Apresentação do SGU — guia de manutenção

A apresentação fica em `/apresentacao` (pública, sem login) e atende as diferentes entregas da disciplina.

## Qual slide atende a cada item da entrega?

**“Protótipo com o conceito visual do projeto” corresponde ao slide “Conceito visual”.** No perfil inicial **Segunda entrega — Status Report 2**, ele aparece como **04**. Dentro dele, selecione **Captura da landing**, **Captura do login**, **Captura no celular**, **Paleta de cores** e **Notas sobre as capturas** para apresentar as telas e a identidade visual existentes.

O subitem **Protótipo de referência (Figma ou similar)** é uma alternativa para mostrar um material separado das telas implementadas. O enunciado da professora não exige Figma nem uma ferramenta específica. Hoje esse material separado está vazio; marcar seu checkbox apenas exibe a pendência. As capturas de landing, login e celular já existem, mas a equipe ainda precisa validar se o conjunto atende ao item acadêmico antes de confirmá-lo no checklist.

O painel lista o **catálogo inteiro**, incluindo slides da outra entrega e apêndices. Por isso, nem todo item da lista precisa ficar marcado. Use as tabelas abaixo para escolher o slide e os conteúdos internos correspondentes.

### Primeira entrega

| Exigência da professora | Slide no painel | Conteúdos a selecionar |
| --- | --- | --- |
| 1. Lista de requisitos refinada | **Requisitos refinados** (`requisitos`; exemplo: 04) | Requisitos funcionais; Requisitos não funcionais; Critérios de aceite; Documento e card de refinamento |
| 2. Lista de ferramentas e tecnologias escolhidas | **Arquitetura e tecnologias** (`arquitetura`; exemplo: 06) | Tecnologias utilizadas; Versões. Explicação da arquitetura pode complementar a fala. |
| 3. Diagrama de casos de uso | **Diagrama de casos de uso** (`casos-de-uso`; exemplo: 05) | Marcar o slide; ele não possui subitens. Preencher o diagrama em `diagramas.yml`. |
| 4. Trello ativo com requisitos e links para ambientes | **Gestão e evidências** (`gestao`; exemplo: 07) | Quadro do Trello; Cards do projeto; Links para ambientes |
| 5. Planejamento dos próximos passos | **Próximos passos** (`proximos-passos`; exemplo: 09) | Marco demonstrável; Lista de próximos passos; Riscos; Dependências |
| 6. Reflexão sobre o período | **Retrospectiva e lições** (`retrospectiva`; exemplo: 08) | Pontos discutidos; Lições aprendidas |

### Segunda entrega — Status Report 2

| Exigência da professora | Slide no painel | Conteúdos a selecionar |
| --- | --- | --- |
| 1. Protótipo com o conceito visual do projeto | **Conceito visual** (`conceito-visual`; exemplo: 04) | Captura da landing; Captura do login; Captura no celular; Paleta de cores; Notas sobre as capturas. Protótipo de referência apenas quando houver material separado. |
| 2. GitHub estruturado, com duas funcionalidades completas | **Gestão e evidências** (`gestao`; exemplo: 08) e **Duas funcionalidades completas** (`funcionalidades`; exemplo: 05) | Em Gestão: GitHub e práticas de acompanhamento. Em Funcionalidades: Critérios de “completa”; Funcionalidade 1; Funcionalidade 2. Mostrar o repositório não comprova que as duas jornadas estão completas. |
| 3. Imagem de uma retrospectiva | **Retrospectiva e lições** (`retrospectiva`; exemplo: 09) | Imagem da retrospectiva; Pontos discutidos; Ações combinadas; Lições aprendidas |
| 4. Modelo conceitual | **Modelo conceitual** (`modelo-conceitual`; exemplo: 06) | Diagrama do modelo conceitual; Diferença para o modelo físico do banco |
| 5. Evidências de reuniões de monitoramento | **Gestão e evidências** (`gestao`; exemplo: 08) | Registros das reuniões |
| Status report: o que foi feito desde a última entrega | **Evolução no período** (`evolucao`; exemplo: 03) | Linha do tempo (commits); Situação das capacidades |
| Status report: o que será feito até a próxima entrega | **Próximos passos** (`proximos-passos`; exemplo: 10) | Marco demonstrável; Lista de próximos passos; Riscos; Dependências |
| Status report: o que aprendemos na sprint | **Retrospectiva e lições** (`retrospectiva`; exemplo: 09) | Lições aprendidas, com apoio da imagem e dos pontos discutidos |

Os números acima são exemplos da seleção inicial de cada perfil, definida em `db/seeds/presentation_profiles.rb`. Na conferência de 02/10/2026, o perfil ativo **Segunda entrega — Status Report 2** tinha 11 slides principais e estimativa de 6 minutos. Ocultar ou adicionar um slide recalcula a numeração; procure pelo **nome** e pelo **id**, não por um número fixo. A segunda entrega permite no máximo 7 minutos, que precisam ser conferidos em ensaio.

O slide **Status report** é uma opção para reunir feito, próximo e aprendizados em uma só tela. Ele está desmarcado nos perfis iniciais. Na segunda entrega, essas informações já aparecem em Evolução, Próximos passos e Retrospectiva. Marcar os dois formatos pode repetir a mesma fala.

## O que cada controle realmente altera

- **Admin → Apresentação → Editar seleção:** salva no banco quais slides e conteúdos aparecerão naquele perfil. **Usar como padrão** escolhe o perfil usado na apresentação pública.
- **Personalizar apresentação:** exibe ou oculta slides e conteúdos somente na aba aberta. **Concluir** fecha o painel; não salva o perfil. Recarregar volta à seleção salva.
- **Campo Entrega no admin:** muda capa, rodapé, checklist e limite de tempo. Escolher “primeira” ou “segunda” **não troca automaticamente os checkboxes**; para usar outra seleção pronta, abra o perfil correspondente.
- **Checkbox marcado:** significa “exibir este conteúdo”. Não significa “exigência cumprida”, não edita textos e não cria imagens, diagramas ou registros. Para preencher o material, edite o YAML indicado na seção “Onde atualizar cada coisa”. A confirmação da equipe é um campo separado no checklist de `entrega.yml`.

Há três camadas separadas:

| Camada | Onde fica | Quem altera |
| --- | --- | --- |
| **Conteúdo** (textos, listas, imagens, links) | YAMLs desta pasta e `app/assets/images/presentation/` | equipe, por commit |
| **Catálogo** (quais slides e blocos existem, ordem, tempo, padrões) | `roteiro.yml` + partials em `app/views/presentations/slides/` | equipe, por commit |
| **Perfis** (quais slides e blocos aparecem em cada ocasião) | banco de dados, tabela `presentation_profiles` | administrador, em **Admin → Apresentação** |

Além disso, durante a apresentação, o botão **Personalizar apresentação** permite ajustes temporários só no navegador.

Os perfis só controlam a exibição. Tudo o que está no catálogo vai no HTML público, inclusive o que está oculto. Por isso, não coloque nada confidencial nos YAMLs.

## Preparar o banco (uma vez)

Se houver migrações pendentes para o banco usado pelo aplicativo, execute `bin/rails db:migrate` no terminal do Dev Container. Não é necessário repetir migrações já aplicadas nem recriar o banco para trocar o perfil.

Para criar somente os perfis iniciais que ainda não existem:

```bash
bin/rails runner 'load Rails.root.join("db/seeds/presentation_profiles.rb")'
```

Esse arquivo não sobrescreve um perfil editado no admin. O `bin/rails db:seed` completo também redefine senha, acesso administrativo e exclusão dos usuários de exemplo em desenvolvimento; por isso, prefira o comando acima quando quiser apenas preparar os perfis.

Sem nenhum perfil ativo, `/apresentacao` usa os valores `padrao` atuais do `roteiro.yml` com a entrega de `entrega_padrao` (`entrega.yml`). A seleção pode mudar quando esses arquivos forem atualizados. Abrir a página nunca cria registros.

## Perfis no admin

1. Entre com um usuário administrador (credenciais de desenvolvimento no README) e abra **Admin → Apresentação** (`/admin/apresentacao`). Usuários comuns não veem o menu nem acessam a tela.
2. A lista indica o **perfil padrão da apresentação pública**, a entrega, a quantidade de slides e a estimativa de tempo de cada perfil.
3. **Novo perfil** ou **Editar seleção** abre o formulário:
   - **Nome** e **Entrega** (primeira ou segunda). A entrega define o título da capa e do rodapé, o prazo, o checklist do apêndice e o limite de tempo do aviso; não substitui a seleção de slides e conteúdos.
   - Um checkbox por slide e, abaixo dele, os checkboxes dos conteúdos daquele slide. Capa e encerramento aparecem marcados e travados, e o servidor recusa qualquer tentativa de ocultá-los.
   - Desmarcar um slide oculta o slide inteiro, mas mantém as escolhas dos conteúdos, que voltam quando o slide for marcado de novo.
   - Um slide marcado com todos os conteúdos desmarcados é **omitido** (o formulário avisa). Assim não aparece uma tela só com o título.
   - A estimativa soma o `tempo` dos slides principais marcados e fica vermelha acima do limite da entrega (7 min na segunda). É só uma estimativa e não substitui o ensaio cronometrado.
4. Clique em **Salvar configurações**. Mensagens de sucesso ou erro aparecem no topo; uma chave fora do catálogo ou um valor que não seja marcado/desmarcado é recusado.
5. Para trocar o perfil usado em `/apresentacao`, clique em **Usar como padrão** na lista ou marque **Perfil padrão da apresentação pública** no formulário. Só um perfil fica ativo por vez. O perfil ativo não pode ser excluído.
6. **Visualizar** abre `/apresentacao?perfil=<id>`, que mostra um perfil salvo sem torná-lo padrão.

## Ajustes temporários durante a apresentação

1. Clique em **Personalizar apresentação** (ícone de controles deslizantes na barra superior).
2. O painel mostra o perfil em uso, a estimativa de tempo e os mesmos slides e conteúdos do admin. Marcar ou desmarcar aplica a mudança na hora: sequência, índice, contador, barra de progresso, numeração, apêndices e impressão passam a considerar só o que está visível.
3. Se o slide atual for ocultado, a apresentação segue para o próximo slide visível (ou o anterior, se não houver próximo). Ao fechar o painel, o foco vai para esse slide.
4. **Restaurar padrão do perfil** desfaz todos os ajustes. Recarregar a página tem o mesmo efeito.
5. Os ajustes ficam só na memória desta aba: nada é salvo no navegador nem enviado ao servidor. Para mudar o padrão, use o admin.

O painel abre e fecha pelo teclado (Tab até o botão, Enter; Esc fecha). Ele não aparece na impressão. Sem JavaScript, o modo leitura mostra exatamente o perfil salvo, mas o painel não fica disponível.

## Catálogo (`roteiro.yml`)

Cada slide tem `id`, `titulo`, `tempo`, `padrao` e, quando faz sentido, `conteudos`. A chave salva nos perfis é o `id` do slide (`gestao`) ou `<slide>.<conteúdo>` (`gestao.reunioes`, `retrospectiva.imagem`). Essas chaves não dependem do título, da posição nem da numeração.

- **Novo slide:** adicione a entrada com `padrao: true` ou `false` e crie `app/views/presentations/slides/_<id com _>.html.erb`. Perfis já salvos usam o `padrao` até alguém editar o perfil.
- **Novo conteúdo dentro de um slide:** adicione-o em `conteudos` e envolva o bloco na partial com `presentation_item slide, "<id>"`. Use `presentation_group` para um contêiner que deve sumir quando todos os blocos internos sumirem. Use `dentro_de: <id>` para um bloco que só aparece com o bloco pai (ex.: versões dentro de tecnologias).
- **Renomear um id** faz os perfis perderem a escolha daquele item, que volta ao `padrao`. Prefira mudar só o `titulo`.
- Capa e encerramento são obrigatórios (`Presentation::REQUIRED_SLIDES`).

O spec `spec/requests/presentations_request_spec.rb` falha se um conteúdo do catálogo não estiver marcado na partial ou se uma partial marcar uma chave fora do catálogo.

## Onde atualizar cada coisa

| O quê | Arquivo |
| --- | --- |
| Equipe, disciplina, links, entregas (título, prazo, data, limite de tempo, checklist) | `entrega.yml` |
| Ordem, tempo de fala, quem apresenta, tema, apêndices e catálogo de conteúdos | `roteiro.yml` |
| Problema, público, dimensões, conflitos, **requisitos refinados** e documento (card #13) | `requisitos.yml` |
| Linha do tempo (commits), capacidades e data da primeira entrega (base do status report) | `evolucao.yml` |
| Protótipo, capturas de tela e paleta | `conceito_visual.yml` |
| As duas funcionalidades completas | `funcionalidades.yml` |
| Modelo conceitual, casos de uso (#14) e fluxo revisado (#5) | `diagramas.yml` |
| Stack, mudanças em relação à 1ª entrega e justificativas | `tecnologias.yml` |
| Cards, links para ambientes, práticas e reuniões de monitoramento | `gestao.yml` |
| Retrospectiva: data, formato, imagem, pontos, ações e lições | `retrospectiva.yml` |
| Marco, próximos passos, riscos e dependências | `planejamento.yml` |

O slide **Status report** não tem YAML próprio: ele reúne os marcos posteriores a `data_primeira_entrega` (`evolucao.yml`), os próximos passos (`planejamento.yml`) e as lições (`retrospectiva.yml`).

No **modo leitura** (`/apresentacao?modo=leitura`), cada slide mostra uma nota tracejada com o arquivo a atualizar. Essas notas não aparecem no modo apresentação nem no PDF.

## Estados

Use somente estes valores no campo `estado`:

- `implementado`
- `parcial`
- `planejado`
- `aguardando_decisao`
- `aguardando_evidencia`

Só marque `implementado` com evidência verificável (código, teste, captura). Propostas de requisito continuam `aguardando_decisao` até haver aprovação registrada.

Campos vazios e blocos de pendência são intencionais: indicam conteúdo ainda não confirmado. Preencha requisitos, funcionalidades, reuniões e retrospectiva com registros reais; não invente decisões, participantes, testes, datas, links ou imagens. Atualize também o checklist da entrega em `entrega.yml` e marque `confirmado_pela_equipe: true` somente após a revisão da equipe.

## Imagens e diagramas

1. Salve o arquivo em `app/assets/images/presentation/` (diagramas em `app/assets/images/presentation/diagramas/`, reuniões em `app/assets/images/presentation/reunioes/`).
2. No YAML, informe o caminho relativo a `app/assets/images`. Exemplo: `presentation/diagramas/casos-de-uso-v1.png`.
3. Preencha versão, origem e data quando existirem.
4. Prefira PNG ou SVG legível em 1600 px de largura; o slide oferece ampliação (lightbox) e a impressão reduz a imagem.

Links devem ser públicos (`https://…`). Um caminho local (`C:\…`, `\\wsl…`, `/mnt/…`) nunca vira link: ele aparece como texto, e o spec `spec/models/presentation_spec.rb` falha.

### Atualizar as capturas das telas

As imagens existentes não são atualizadas automaticamente. Para refazê-las manualmente:

1. Com o SGU rodando, abra `/` e `/entrar` no navegador. Use as ferramentas de desenvolvimento para definir a largura da tela; registre largura e altura adotadas em `conceito_visual.yml` (a captura mobile atual usa 390 px de largura).
2. Aguarde fontes e imagens carregarem. Capture a área visível para a imagem desktop e, quando necessário, a página inteira para `imagem_ampliada`. Confira que menus, diálogos e o cursor não cobrem conteúdo relevante.
3. Antes da captura, oculte somente o aviso de credenciais de desenvolvimento na página de login usando o inspetor do navegador (a alteração é temporária, sem editar o projeto). Não inclua senhas, tokens, e-mails pessoais ou outros dados privados na imagem. Informe essa ocultação na nota da captura.
4. Salve as capturas em `app/assets/images/presentation/` e ajuste os caminhos, textos alternativos, notas e `capturado_em` em `conceito_visual.yml`. Informe um commit somente se ele corresponder ao código efetivamente capturado; para mudanças não publicadas, deixe-o vazio.
5. Recarregue `/apresentacao?modo=leitura` e confira as imagens, inclusive a ampliação e a impressão. Capturas de telas com alertas de exemplo devem manter `demonstrativo: true`.

## Como produzir os materiais pendentes

**Requisitos refinados e critérios de aceite (card #13).** Consolide o documento de requisitos com a equipe, resolvendo antes os conflitos listados em `requisitos.yml`. Cada requisito precisa de identificador estável (RF001, RNF001), descrição curta e pelo menos um critério de aceite verificável, de preferência no formato *Dado / Quando / Então*. Registre a versão aprovada em `documento` (título, versão, origem e link público) e copie para `requisitos_refinados` só os requisitos aprovados, marcando `mvp: true` nos que entram no MVP. Ao decidir um conflito, mude o `estado` dele.

**Diagrama de casos de uso (card #14).** Liste os atores (estudante, servidor, equipe de segurança, administração, visitante) e os casos de uso aprovados nos requisitos. Desenhe em uma ferramenta UML (draw.io, PlantUML, Lucidchart), com fronteira do sistema e relações `include`/`extend` só quando existirem de fato. Exporte em PNG ou SVG e preencha `casos-de-uso` em `diagramas.yml`.

**Protótipo visual e capturas.** O que existe hoje são telas reais de landing e login, com capturas desktop e mobile. Se a equipe fizer um protótipo separado (Figma, Penpot ou papel fotografado), preencha `prototipo` em `conceito_visual.yml` com ferramenta, link público de visualização, captura e uma nota dizendo o que difere das telas implementadas. Para as capturas das telas reais, siga a seção acima.

**Evidências das duas funcionalidades.** A equipe escolhe duas jornadas do SGU e só as declara completas quando cumprirem os critérios de `funcionalidades.yml`. Elementos herdados da base Rails (login, CRUD de exemplo `Dog`) não devem ser contados automaticamente: verifique sua relação com o escopo aprovado do SGU e se fazem parte de uma jornada completa e validada. Para cada uma, registre os requisitos atendidos, os passos da jornada, os arquivos de código, os specs que a cobrem, uma captura e como foi validada. Se a modelagem de ocorrências desenvolvida em outra branch (`card-6`) for integrada, cite apenas o que estiver nesta branch, com commit e testes.

**Modelo conceitual (2ª entrega).** Mostre os conceitos do domínio e suas relações (ocorrência, categoria, status, visibilidade, localização, pessoa usuária, perfil de acesso…), com multiplicidades e sem tipos de coluna, chaves estrangeiras ou nomes de tabela. O apêndice “Modelo de dados atual” mostra o modelo físico de `db/schema.rb` e não substitui o conceitual. A branch `card-6` já contém os diagramas em HTML/CSS (commit `389dc12`, `PresentationDiagram` e `config/presentation/data_diagrams.yml`). Priorize integrar e revisar esse material antes de produzir outro diagrama. Nesta branch (`card-11`), `modelo-conceitual` em `diagramas.yml` ainda está sem imagem e o renderer em HTML/CSS não está integrado.

**Retrospectiva.** Faça a dinâmica com a equipe (ex.: [funretrospectives.com](https://www.funretrospectives.com/), formato Manter / Melhorar / Experimentar). Fotografe ou capture o quadro real, sem dados pessoais além dos nomes. Preencha em `retrospectiva.yml`: `data`, `formato`, `imagem`, `imagem_descricao`, `pontos`, `acoes` (com responsável e prazo) e `licoes`. As lições também alimentam o status report.

**Evidências de reuniões de monitoramento.** Registre apenas reuniões que aconteceram, cada uma com data, tipo, participantes, pauta e decisões, e com uma evidência: captura da ata, do card do Trello com comentário datado ou do chat da reunião (sem dados pessoais). Salve a imagem em `app/assets/images/presentation/reunioes/` e preencha `reunioes` em `gestao.yml` no formato comentado do arquivo.

**Atualizações do Trello.** Confira se o quadro está público ou compartilhado com a professora, se tem um card por requisito ou entrega e se a descrição traz links para os ambientes (repositório e, quando existir, o ambiente publicado). Preencha a `url` do card #11 em `gestao.yml` e ajuste os estados dos cards. Só cadastre um ambiente publicado em `ambientes` depois de um deploy real.

**Status report e próximos passos.** Depois do merge desta branch, adicione um marco em `evolucao.yml` com o commit publicado. Defina com a equipe o `marco` demonstrável em `planejamento.yml` e revise os passos, riscos e dependências. Na véspera, preencha `responsavel` em `roteiro.yml`, confirme `data_apresentacao` em `entrega.yml` e faça um ensaio cronometrado.

### Situação atual dos materiais

Levantamento feito em 02/10/2026 na branch `card-11`.

**Diferença entre branches:** o `db/schema.rb` desta branch declara quatro tabelas de aplicação (`users`, `sessions`, `dogs` e `presentation_profiles`). O banco de desenvolvimento consultado mantém 22 tabelas de aplicação: as tabelas do domínio trabalhadas na `card-6` continuam presentes. Essa conferência de estrutura não reconstrói o histórico de todos os registros. Os diagramas em HTML/CSS daquela branch também ainda não estão no código da `card-11`. Isso exige integração de código e revisão do schema e das evidências. Executar seeds ou marcar checkboxes não integra branches. Não use reset do banco para resolver essa diferença.

| Seção | Situação real | Material faltante | Onde preencher | Como produzir |
| --- | --- | --- | --- | --- |
| Requisitos refinados (1ª) | Aguardando evidência: card #13 em aberto, 6 conflitos aguardando decisão | Documento aprovado, lista de RF/RNF e critérios de aceite | `requisitos.yml` → `documento`, `requisitos_refinados`, `conflitos[].estado` | Ver "Requisitos refinados e critérios de aceite" |
| Ferramentas e tecnologias (1ª) | Implementado: stack lida do repositório e do `Gemfile.lock` | Justificativa da equipe para cada mudança de stack | `tecnologias.yml` → `mudancas[].justificativa` | Registrar o motivo que a equipe sustenta (ex.: base Rails reutilizada) |
| Diagrama de casos de uso (1ª) | Aguardando evidência (card #14) | Imagem do diagrama, versão e data | `diagramas.yml` → `casos-de-uso`; imagem em `presentation/diagramas/` | Ver "Diagrama de casos de uso" |
| Trello com requisitos e ambientes (1ª) | Parcial: quadro e cards existem; card #11 sem link; não há ambiente publicado | Link do card #11, conferência de acesso e links no quadro | `gestao.yml` → `cards`, `ambientes` | Ver "Atualizações do Trello" |
| Próximos passos (1ª e status report) | Parcial: passos listados, marco aguardando decisão | Marco demonstrável da próxima entrega | `planejamento.yml` → `marco` | Decidir em reunião e registrar |
| Reflexão / lições (1ª e status report) | Aguardando evidência | Lições registradas pela equipe | `retrospectiva.yml` → `licoes` | Ver "Retrospectiva" |
| Protótipo com conceito visual (2ª) | Parcial: capturas de landing, login e celular disponíveis; protótipo separado vazio | Validação da equipe de que as telas apresentadas atendem ao item; material separado apenas se escolhido | `conceito_visual.yml` → `capturas`, `paleta`, `prototipo` | Apresentar as capturas; ver "Protótipo visual e capturas" para material separado |
| GitHub estruturado (2ª) | Implementado: repositório, CI e Dependabot | Código das duas funcionalidades | `funcionalidades.yml` (código e testes) | Ver "Evidências das duas funcionalidades" |
| Duas funcionalidades completas (2ª) | Aguardando decisão: nenhuma escolhida | Escolha, implementação, testes, captura e validação | `funcionalidades.yml` → `itens` | Ver "Evidências das duas funcionalidades" |
| Imagem da retrospectiva (2ª) | Aguardando evidência | Foto ou captura real, data e formato | `retrospectiva.yml` → `imagem`, `data`, `formato` | Ver "Retrospectiva" |
| Modelo conceitual (2ª) | Pendente na `card-11`; material em HTML/CSS já existe na `card-6` | Integração e revisão do diagrama existente | `diagramas.yml` → `modelo-conceitual`; código e catálogo da `card-6` | Ver "Modelo conceitual" e integrar antes de produzir novamente |
| Reuniões de monitoramento (2ª) | Aguardando evidência: nenhuma registrada | Data, participantes, pauta, decisões e evidência de cada reunião | `gestao.yml` → `reunioes` | Ver "Evidências de reuniões de monitoramento" |
| O que foi feito desde a última entrega | Parcial: marcos até 30/09/2026; trabalho do card #11 não publicado | Commit publicado após o merge | `evolucao.yml` → `marcos` | Ver "Status report e próximos passos" |
| Fluxo de ocorrências (card #5) | Aguardando evidência | Diagrama revisado | `diagramas.yml` → `fluxo-ocorrencias` | Exportar o fluxo revisado e preencher como os outros diagramas |
| Data, responsáveis e ensaio (2ª) | Data a confirmar, responsáveis vazios, sem ensaio cronometrado | Data, responsável por slide e tempo real | `entrega.yml` → `data_apresentacao`; `roteiro.yml` → `responsavel` | Combinar com a equipe e ensaiar com cronômetro |
| Checklists das entregas | Todos os itens com `confirmado_pela_equipe: false` | Revisão da equipe | `entrega.yml` → `entregas[].checklist` | Revisar item a item depois de preencher os materiais |

## Executar localmente

No terminal do Dev Container, inicie o sistema normalmente:

```bash
bin/dev
```

Abra `http://localhost:3000/apresentacao`. Se `bin/dev` já estiver rodando, não inicie uma segunda instância. A apresentação é uma rota do mesmo aplicativo e não precisa de outro container nem de um servidor próprio.

**Alternativa para exportação via Selenium:** em outro terminal do mesmo Dev Container, pode ser iniciado um servidor na porta 3100. Esse processo atende o mesmo aplicativo, mas deixa o servidor usado pelo `bin/dev` intacto:

```bash
RAILS_DEVELOPMENT_HOSTS=rails-app bin/rails server -b 0.0.0.0 -p 3100 -P tmp/pids/apresentacao-3100.pid
```

- O VS Code está configurado para encaminhar as portas 3000 e 3100 (`.devcontainer/devcontainer.json`). Confirme o endereço efetivo na aba **Portas**, principalmente se outro projeto estiver usando a mesma porta no computador. Para a alternativa acima, abra `http://localhost:3100/apresentacao`.
- `RAILS_DEVELOPMENT_HOSTS=rails-app` permite que o Chrome do serviço Selenium acesse o servidor para testes e exportação.
- Encerre somente o servidor adicional com Ctrl+C no terminal correspondente quando terminar a exportação.
- A página lê os perfis no banco. Se aparecer o erro de migrations pendentes, rode `bin/rails db:migrate` (ou `bin/rails db:prepare` em um banco novo) e recarregue.

## Gerar o PDF

**Pelo navegador:** use o botão **Imprimir / salvar PDF** (ou Ctrl+P) e escolha "Salvar como PDF". A folha de estilos define A4 paisagem, imprime um slide por página (incluindo os apêndices selecionados) e remove os controles. A impressão respeita o perfil e os ajustes temporários da página aberta. Ative "Gráficos de plano de fundo" para manter as cores dos selos.

**Por script:** use o terminal do Dev Container, com as gems do projeto instaladas, o serviço `selenium` ativo e o servidor da porta 3100 iniciado conforme acima. O Chrome do Selenium precisa alcançar `http://rails-app:3100/apresentacao`; o endereço `localhost` dentro desse serviço não aponta para o aplicativo Rails.

```bash
bundle exec ruby script/exportar_apresentacao_pdf.rb
```

O arquivo é gravado em `tmp/apresentacao/sgu-segunda-entrega.pdf` (pasta ignorada pelo git). Outro destino pode ser passado como argumento.

O script exporta o perfil ativo. Ajustes temporários não entram, porque ele abre uma página nova. Para exportar outro perfil salvo, use `APRESENTACAO_URL="http://rails-app:3100/apresentacao?modo=leitura&perfil=<id>"`, com o id que aparece no link **Visualizar** do admin. A variável `SELENIUM_REMOTE_URL` muda o serviço Selenium (padrão: `http://selenium:4444/wd/hub`, também definido no Dev Container). Ao escolher outro endereço, confirme que o Selenium consegue acessá-lo e que o Rails aceita seu host.

Após cada alteração de conteúdo ou estilo, gere novamente e abra o PDF: confira todas as páginas, cortes, tamanho dos textos, imagens, diagramas e links clicáveis. Os controles e notas de manutenção não devem aparecer. Um arquivo PDF gerado não comprova, sozinho, que o conteúdo está correto ou pronto para entrega. Compartilhe o PDF final explicitamente, pois a cópia em `tmp/` não será publicada no GitHub.

## Verificações

Execute dentro do Dev Container. Os testes de navegação com JavaScript precisam do serviço Selenium ativo e de `SELENIUM_REMOTE_URL` configurado (o Dev Container já define essa variável). O Capybara inicia seu próprio servidor de testes; não é necessário iniciar o servidor adicional da porta 3100 para esses specs.

```bash
bundle exec rspec spec/models/presentation_spec.rb spec/models/presentation spec/models/presentation_profile_spec.rb \
  spec/policies/presentation_profile_policy_spec.rb spec/requests/presentations_request_spec.rb \
  spec/requests/admin/presentation_profiles_request_spec.rb spec/helpers/presentations_helper_spec.rb \
  spec/features/presentation_navigation_spec.rb spec/features/admin/presentation_profiles_features_spec.rb
```

Os specs conferem:

- estados válidos, imagens existentes, ausência de caminhos locais e links internos válidos;
- catálogo válido (ids, `padrao` explícito, capa e encerramento obrigatórios) e coerente com as partials;
- padrões sem perfil salvo, sem criar registros; perfil ativo e `?perfil=` refletidos na página;
- persistência e isolamento entre perfis, um único perfil ativo, recusa de chaves inválidas, de valores não booleanos e da ocultação de slides obrigatórios;
- acesso ao admin restrito a administradores;
- renumeração, slides sem conteúdo omitidos, grupos vazios ocultos e aviso de tempo acima do limite;
- no navegador: navegação por teclado sem entrar nos apêndices, fragmento inválido ou oculto, painel temporário (foco, Esc, ocultar o slide atual, restaurar, recarregar sem gravar no banco), índice e apêndices renumerados e quantidade de páginas impressas;
- que o apêndice de modelo de dados lista todas as tabelas de `db/schema.rb`.

Esses testes não conferem a disponibilidade ou as permissões dos links externos, a legibilidade do PDF nem o tempo de fala real. Abra Trello, GitHub e os registros compartilhados sem a sessão da equipe para conferir o acesso da professora. Teste a apresentação no celular e faça um ensaio cronometrado antes de cada entrega (até 7 minutos na segunda).
