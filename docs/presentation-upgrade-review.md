# Revisão da apresentação do SGU — card #11

Reorganização de 02/10/2026, na branch `card-11`, após o merge da `main` (`fe2fa0a`). As alterações continuam no diretório de trabalho; não houve novo commit, push ou deploy.

## Organização final

Cada item do enunciado tem uma única tela, na ordem pedida. O título exibido vem de `entrega.yml`; o id salvo continua estável. A posição do slide é calculada conforme a seleção e não se confunde com o número da exigência.

**Primeira entrega:** capa → requisitos refinados (`requisitos`) → ferramentas e tecnologias (`arquitetura`) → casos de uso (`casos-de-uso`) → Trello e ambientes (`gestao`) → próximos passos (`proximos-passos`) → reflexão e lições (`retrospectiva`) → encerramento.

**Segunda entrega — Status Report 2 (ativa):** capa → protótipo visual (`conceito-visual`) → GitHub e duas funcionalidades completas (`funcionalidades`) → imagem da retrospectiva (`retrospectiva`) → modelo conceitual (`modelo-conceitual`) → reuniões (`reunioes`) → o que foi feito (`evolucao`) → o que será feito (`proximos-passos`) → aprendizados da sprint (`status-report`) → encerramento.

São 8 páginas principais na primeira e 10 na segunda, contando capa e encerramento. A sequência vem de `entrega.yml` → `exigencias[].slides` e vale também para índice, personalização, admin e impressão. Ao trocar a entrega no formulário, as linhas mudam de ordem e grupo sem alterar seus checkboxes. Complementos ficam desmarcados nos perfis recomendados.

O resumo de GitHub e estrutura foi incorporado ao slide das duas funcionalidades. O antigo resumo de status report agora mostra somente aprendizados e ações da retrospectiva: não repete feito nem próximo. A imagem aparece uma vez no item 3; o slide de aprendizados referencia esse registro. Na primeira entrega, o slide de reflexão usa pontos, ações e lições. A evolução considera somente marcos posteriores à primeira entrega; o painel de capacidades permanece opcional e desmarcado no perfil recomendado.

Os dois perfis existentes foram reorganizados conforme o pedido, com cópia anterior em `tmp/presentation-profiles-before-simplification-20261002.json`. No banco de desenvolvimento, a segunda entrega (id 2) permanece ativa, com 10 slides e estimativa de 320 segundos (5min20s); a primeira (id 1) fica inativa, com 8 slides e 235 segundos (3min55s). A tarefa de bootstrap continua criando apenas perfis ausentes; não sobrescreve automaticamente uma seleção editada.

## Conteúdo disponível fora dos perfis

Problema e proposta, escopo, fluxo de ocorrências, detalhes do GitHub, conflitos de requisitos, checklist, DER físico e suas visões, evidências e roteiro/tempo permanecem disponíveis como complementos. Tecnologias e Trello atendem à primeira entrega, sem entrar na segunda por padrão. Não foi necessário excluir conteúdo: os extras podem ser habilitados para consulta, aumentando a sequência e o PDF.

Os diagramas em HTML/CSS, conexões, ampliação, logos locais e controles de versões da revisão anterior foram preservados. `presentation_profiles` continua na infraestrutura, sem vínculo artificial com o domínio do SGU.

## Pendências da equipe

Os avisos permanecem enquanto faltarem evidências reais. O slide público do protótipo informa a validação pendente das capturas e o caráter demonstrativo dos alertas. É necessário validar as capturas do protótipo; escolher e concluir duas jornadas funcionais; anexar imagem, pontos, ações e lições da retrospectiva; registrar reuniões; revisar premissas do conceitual; consolidar requisitos e produzir casos de uso. O backend integrado e o repositório estruturado não comprovam sozinhos duas funcionalidades completas.

A equipe também precisa confirmar responsáveis, marco demonstrável, data da apresentação, acesso aos links e ensaio de até 7 minutos para a segunda entrega. Produção técnica e confirmação acadêmica continuam separadas; nenhuma evidência ou aprovação foi inventada.

## Validação desta reorganização

| Verificação | Resultado desta reorganização |
| --- | --- |
| RSpec completo | 465 exemplos, 0 falhas (seed 2816); cobertura de linhas de 98,12%. |
| RuboCop | 229 arquivos, nenhuma infração. |
| Zeitwerk | Carregamento das constantes validado. |
| Brakeman | Nenhum aviso de segurança. |
| Perfis de desenvolvimento | Segunda ativa: 10 slides/320s; primeira inativa: 8 slides/235s. Seleções anteriores salvas no backup indicado acima. |
| Desktop e celular | Perfis reais conferidos em 1440×1000 e 390×844, sem overflow horizontal; ordem e nomes confirmados no HTML. |
| PDF | A4 paisagem: primeira com 8 páginas, segunda com 10. Todas renderizadas e revisadas, sem cortes ou páginas extras. |
| Documentação | Links locais e comandos conferidos no código; `git diff --check` sem erros. |

Os resultados acima correspondem a esta reorganização. A conferência visual e a exportação usaram os perfis reais de desenvolvimento, sem alterar seus registros. PDFs de verificação ficam em `tmp/` e não constituem a entrega final. A confirmação acadêmica das evidências e o ensaio continuam a cargo da equipe.

## Tutorial curto para o card

No Dev Container:

```bash
bin/rails db:migrate
bin/rails sgu:presentation:profiles
```

Use o servidor existente ou inicie `bin/dev`. Abra `/admin/apresentacao`: primeira entrega tem 6 itens; segunda tem 5 itens mais 3 de status report e permanece ativa. Confira a ordem em `/apresentacao`, mantenha complementos desmarcados, preencha as evidências pendentes e revise o PDF. Personalizar apresentação vale só para a aba; mudanças permanentes são salvas no admin.

O bootstrap cria apenas perfis ausentes. Para um banco que já tinha os perfis anteriores, confira a seleção no admin; executar a tarefa novamente não a substitui.

## Descrição simples de MR

```markdown
## O que foi feito

Organiza os perfis da apresentação na ordem das exigências: uma tela por item, com a segunda entrega ativa. Reúne GitHub e duas funcionalidades no mesmo slide e separa feito, planejamento e aprendizados, removendo redundâncias. A imagem da retrospectiva aparece uma vez.

Mantém ids e conteúdos extras, desmarcados por padrão, e conserva avisos para evidências que dependem da equipe. Alinha slides, índice, admin, personalização e PDF; atualiza o guia e os perfis recomendados.

## Validação

RSpec: 465 exemplos, 0 falhas. RuboCop: 229 arquivos sem infrações. Zeitwerk validado e Brakeman sem avisos. Desktop, celular e PDFs de 8/10 páginas conferidos, sem cortes nem páginas extras. Detalhes em docs/presentation-upgrade-review.md.
```

## Comentário sugerido para o card #11

```markdown
Apresentação reorganizada na ordem do enunciado, com uma tela por item:

- Primeira entrega: 6 itens, além de capa e encerramento.
- Segunda entrega (ativa): 5 itens mais os 3 pontos do status report, além de capa e encerramento.
- GitHub e duas funcionalidades reunidos; feito, próximos passos e aprendizados separados.
- Imagem da retrospectiva apresentada uma vez; complementos disponíveis, desmarcados.
- Evidências ainda ausentes continuam sinalizadas como pendentes.

Próximo passo da equipe: preencher retrospectiva e reuniões, validar as duas funcionalidades, revisar o conceitual e os requisitos, produzir casos de uso e ensaiar a segunda entrega em até 7 minutos.
```

Guia de manutenção e mapeamento completo: [config/presentation/LEIAME.md](../config/presentation/LEIAME.md). Nenhum card foi criado ou atualizado remotamente.
