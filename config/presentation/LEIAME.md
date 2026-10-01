# Apresentação da segunda entrega — guia de manutenção

A apresentação fica em `/apresentacao` (pública, sem login). O conteúdo está nesta pasta, em YAML; o layout de cada slide está em `app/views/presentations/slides/`. Para atualizar o conteúdo, edite o YAML e recarregue a página: não é preciso mexer no ERB.

## Onde atualizar cada coisa

| O quê | Arquivo |
| --- | --- |
| Equipe, disciplina, prazo, data da apresentação, links, checklist da entrega | `entrega.yml` |
| Ordem dos slides, tempo de fala, quem apresenta, tema escuro, apêndices | `roteiro.yml` |
| Problema, público, dimensões da ocorrência, requisitos selecionados, conflitos, documento de requisitos (card #13) | `requisitos.yml` |
| Linha do tempo (commits) e situação das capacidades do produto | `evolucao.yml` |
| Capturas de tela e paleta | `conceito_visual.yml` |
| As duas funcionalidades completas | `funcionalidades.yml` |
| Modelo conceitual, casos de uso (#14) e fluxo revisado (#5) | `diagramas.yml` |
| Stack, mudanças em relação à 1ª entrega e justificativas | `tecnologias.yml` |
| Cards, práticas e reuniões de monitoramento | `gestao.yml` |
| Retrospectiva: imagem, pontos, ações e lições | `retrospectiva.yml` |
| Marco, próximos passos, riscos e dependências | `planejamento.yml` |

No **modo leitura** (`/apresentacao?modo=leitura`), cada slide mostra uma nota tracejada com o arquivo a atualizar. Essas notas não aparecem no modo apresentação nem no PDF.

## Estados

Use somente estes valores no campo `estado`:

- `implementado`
- `parcial`
- `planejado`
- `aguardando_decisao`
- `aguardando_evidencia`

Só marque `implementado` com evidência verificável (código, teste, captura). Propostas de requisito continuam `aguardando_decisao` até haver aprovação registrada.

Campos vazios e blocos de pendência são intencionais: indicam conteúdo ainda não confirmado. Preencha requisitos, funcionalidades, reuniões e retrospectiva com registros reais; não invente decisões, testes, datas ou imagens. Atualize também o checklist em `entrega.yml` e marque `confirmado_pela_equipe: true` somente após a revisão da equipe.

## Imagens e diagramas

1. Salve o arquivo em `app/assets/images/presentation/` (diagramas em `app/assets/images/presentation/diagramas/`).
2. No YAML, informe o caminho relativo a `app/assets/images`. Exemplo: `presentation/diagramas/casos-de-uso-v1.png`.
3. Preencha versão, origem e data quando existirem.

Links devem ser públicos (`https://…`). Um caminho local (`C:\…`, `\\wsl…`, `/mnt/…`) nunca vira link: ele aparece como texto, e o spec `spec/models/presentation_spec.rb` falha.

### Atualizar as capturas das telas

As imagens existentes não são atualizadas automaticamente. Para refazê-las manualmente:

1. Com o SGU rodando, abra `/` e `/entrar` no navegador. Use as ferramentas de desenvolvimento para definir a largura da tela; registre largura e altura adotadas em `conceito_visual.yml` (a captura mobile atual usa 390 px de largura).
2. Aguarde fontes e imagens carregarem. Capture a área visível para a imagem desktop e, quando necessário, a página inteira para `imagem_ampliada`. Confira que menus, diálogos e o cursor não cobrem conteúdo relevante.
3. Antes da captura, oculte somente o aviso de credenciais de desenvolvimento na página de login usando o inspetor do navegador (a alteração é temporária, sem editar o projeto). Não inclua senhas, tokens, e-mails pessoais ou outros dados privados na imagem. Informe essa ocultação na nota da captura.
4. Salve as capturas em `app/assets/images/presentation/` e ajuste os caminhos, textos alternativos, notas e `capturado_em` em `conceito_visual.yml`. Informe um commit somente se ele corresponder ao código efetivamente capturado; para mudanças não publicadas, deixe-o vazio.
5. Recarregue `/apresentacao?modo=leitura` e confira as imagens, inclusive a ampliação e a impressão. Capturas de telas com alertas de exemplo devem manter `demonstrativo: true`.

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
- O conteúdo da apresentação não consulta o banco, mas o aplicativo em desenvolvimento verifica migrations pendentes antes de atender a requisição. Se aparecer esse erro, prepare o banco com `bin/rails db:prepare` no Dev Container e recarregue. Seeds não são necessários para o conteúdo da apresentação.

## Gerar o PDF

**Pelo navegador:** use o botão **Imprimir / salvar PDF** (ou Ctrl+P) e escolha "Salvar como PDF". A folha de estilos já define A4 paisagem, imprime todos os slides e apêndices (um por página) e remove os controles. Ative "Gráficos de plano de fundo" para manter as cores dos selos.

**Por script:** use o terminal do Dev Container, com as gems do projeto instaladas, o serviço `selenium` ativo e o servidor da porta 3100 iniciado conforme acima. O Chrome do Selenium precisa alcançar `http://rails-app:3100/apresentacao`; o endereço `localhost` dentro desse serviço não aponta para o aplicativo Rails.

```bash
bundle exec ruby script/exportar_apresentacao_pdf.rb
```

O arquivo é gravado em `tmp/apresentacao/sgu-segunda-entrega.pdf` (pasta ignorada pelo git). Outro destino pode ser passado como argumento.

O script aceita `APRESENTACAO_URL` para mudar o endereço visto pelo Chrome (padrão: `http://rails-app:3100/apresentacao?modo=leitura`) e `SELENIUM_REMOTE_URL` para mudar o serviço Selenium (padrão: `http://selenium:4444/wd/hub`, também definido no Dev Container). Ao escolher outro endereço, confirme que o Selenium consegue acessá-lo e que o Rails aceita seu host.

Após cada alteração de conteúdo ou estilo, gere novamente e abra o PDF: confira todas as páginas, cortes, tamanho dos textos, imagens, diagramas e links clicáveis. Os controles e notas de manutenção não devem aparecer. Um arquivo PDF gerado não comprova, sozinho, que o conteúdo está correto ou pronto para entrega. Compartilhe o PDF final explicitamente, pois a cópia em `tmp/` não será publicada no GitHub.

## Verificações

Execute dentro do Dev Container. Os testes de navegação com JavaScript precisam do serviço Selenium ativo e de `SELENIUM_REMOTE_URL` configurado (o Dev Container já define essa variável). O Capybara inicia seu próprio servidor de testes; não é necessário iniciar o servidor adicional da porta 3100 para esses specs.

```bash
bundle exec rspec spec/models/presentation_spec.rb spec/requests/presentations_request_spec.rb spec/helpers/presentations_helper_spec.rb spec/features/presentation_navigation_spec.rb
```

Os specs conferem:

- estados válidos;
- imagens existentes;
- ausência de caminhos locais;
- links internos válidos;
- limite de 7 minutos;
- que o apêndice de modelo de dados lista todas as tabelas de `db/schema.rb`;
- navegação por teclado sem entrar nos apêndices, recuperação de fragmento inválido na URL, retorno do foco após fechar a ampliação de imagem e modo leitura.

Ao carregar os YAMLs, o modelo também valida algumas chaves obrigatórias, identificadores e tempos do roteiro, estados conhecidos e cores no formato `#RRGGBB`. Isso não é uma validação completa de todos os campos nem uma confirmação das informações apresentadas.

Esses testes não conferem a disponibilidade ou as permissões dos links externos, a legibilidade do PDF nem o tempo de fala real. Abra Trello, GitHub e os registros compartilhados sem a sessão da equipe para conferir o acesso da professora. Teste a apresentação no celular e faça um ensaio cronometrado de até 7 minutos antes de finalizar o card.
