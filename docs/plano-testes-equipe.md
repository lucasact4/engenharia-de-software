# Plano de testes da equipe — em consolidação

[Plano comum no GitHub — main](https://github.com/lucasact4/engenharia-de-software/blob/main/docs/plano-testes-equipe.md) · [Card #53](https://trello.com/c/BSGE2VRG) · [Requisitos](https://docs.google.com/document/d/1Z-G_nlIvvTVX9EKb3dZUui2HXBQL_vz4f8bAMfQmtv0/edit).

## Participação e evidências

Plano compartilhado com autoria individual dos casos. Cada integrante entrega seu vídeo de até 2 minutos com o mesmo link deste plano. Os critérios abaixo orientam os testes; resultados parciais não comprovam atendimento integral do requisito.

| Integrante | RFs | Situação |
| --- | --- | --- |
| Lucas Vitor | RF010, RF016 | 13 exemplos validados localmente; cinco manuais auxiliares planejados |
| José de Lemos | RF002, RF007 | Oito casos relatados como aprovados no HTML; specs e logs não disponíveis localmente |
| Alisson Cerqueira | RF011, RF014 | Sete aprovações e uma falha relatadas no HTML; código/log vinculados não disponíveis |
| Guilherme Santiago | RF012, RF015 | Casos, automação e evidências pendentes; RF012 não implementado: equipe deve rever bloqueio/escopo |
| Victor Novais | RF001, RF005 | Casos, automação e evidências pendentes |

Implementação: RF010 por José; núcleo RF016 por Alisson, com Victor no fluxo anônimo anterior; Lucas contribuiu na integração, schema e specs. Conferir autoria do trecho e contribuições do testador antes de reconhecer independência cruzada. Casos de Lucas e consolidação deste plano tiveram apoio de ferramenta de programação.

**Evidências de 11/11/2026:** [relatório de José](evidencias/jose-rf002-rf007.html) e [relatório de Alisson](evidencias/alisson-rf011-rf014.html), preservados como recebidos. Os resultados dos colegas foram transcritos, sem reexecução: os arquivos de código e logs dessas execuções não foram fornecidos. As entradas abaixo respeitam o detalhamento disponível nos relatórios.

## RF010 — Lucas: mapa e privacidade

**Critérios:** AC01 sem consentimento usa referência; AC02 GPS autorizado dentro do polígono usa ponto exato; AC03 sem coordenadas usa referência; AC04 GPS fora do polígono selecionado usa referência; AC05 agrupamento preserva quantidade/IDs/links; AC06 fluxo público respeita aprovação e filtro. L01: localização só descritiva é lacuna, não aceite do requisito.

Arquivo: `spec/services/campus_map/rf010_marker_spec.rb`. Testa algoritmos internos com objetos sem persistência; autorização e filtros ficam nos casos manuais. Base: polígono longitude/latitude entre `[-34.951,-8.018]` e `[-34.949,-8.016]`, referência `[-8.017,-34.95]` e GPS interno `[-8.0175,-34.9505]` (latitude/longitude).

| Caso / critério | Entrada e ação | Esperado / resultado | Status |
| --- | --- | --- | --- |
| RF010-UT01 / AC01 | GPS interno, sem consentimento; `report_marker` | Referência; `exact: false` | Passou localmente |
| RF010-UT02 / AC02 | GPS interno, consentimento; `report_marker` | GPS preservado; `exact: true` | Passou localmente |
| RF010-UT03 / AC03 | Consentimento, coordenadas nulas, local georreferenciado; `report_marker` | Referência; `exact: false` | Passou localmente |
| RF010-UT04 / L01 | `Perto da entrada`, sem local georreferenciado nem GPS; `report_marker` | `nil`: caracteriza LACUNA, não atendimento integral | Passou localmente |
| RF010-UT05 / AC04 | GPS autorizado fora do polígono selecionado; `report_marker` | Referência; `exact: false` | Passou localmente |
| RF010-UT06 / AC05 | Dois relatos aproximados no mesmo local; `spot_marker` | `count: 2`, ambos os IDs e links preservados | Passou localmente |

## RF016 — Lucas: metadados da submissão

**Critérios:** AC01 registro vincula ocorrência e instante; AC02 IP/agente cifrados e recuperáveis; AC03 metadados só no admin, ausentes do mural; AC04 vínculos próprios por ocorrência; AC05 modelo impede alteração/exclusão; AC06 ocorrência e instante obrigatórios.

Arquivo: `spec/models/anonymous_submission_audit_spec.rb`. Testa o modelo com banco de teste e cifragem reais, sem verificar interface ou autorização. Dados fictícios: `192.0.2.10`, `AgentTeste/1.0`, `2026-11-11T12:00:00Z`.

| Caso / critério | Entrada e ação | Esperado / resultado | Status |
| --- | --- | --- | --- |
| RF016-UT01 / AC01 | `record!` com ocorrência/metadados válidos; recarregar | Persistência, vínculo e `submitted_at` preservados | Passou localmente |
| RF016-UT02 / AC02 | Persistir IP; comparar coluna e consultar leitor | Cifra diferente do texto claro; leitor recupera IP | Passou localmente |
| RF016-UT03 / AC02 | Persistir agente; comparar coluna e consultar leitor | Cifra diferente do texto claro; leitor recupera agente | Passou localmente |
| RF016-UT04 / AC06 | `submitted_at: nil`; `record!` | `RecordInvalid`, sem salvar auditoria | Passou localmente |
| RF016-UT05 / AC06 | `alert: nil`; `record!` | `RecordInvalid` por ausência da ocorrência | Passou localmente |
| RF016-UT06 / AC05 | Registro persistido; `update!`; recarregar | `ReadOnlyRecord`, originais intactos | Passou localmente |
| RF016-UT07 / AC05 | Registro persistido; `destroy!`; recarregar | `ReadOnlyRecord`, registro permanece | Passou localmente |

```sh
bundle exec rspec spec/services/campus_map/rf010_marker_spec.rb spec/models/anonymous_submission_audit_spec.rb --seed 12345 --format progress
```

Última execução local dos dois arquivos: **13 exemplos, 0 falhas**, seed **12345**. RuboCop: dois arquivos sem infrações. Esse resultado não inclui os testes já existentes nem os casos manuais.

## RF002 — José: pesquisa de pessoas

**Critérios:** RF002-AC01 pesquisar campos textuais; AC02 nome parcial sem diferenciar maiúsculas; AC03 CPF/CNPJ completos após remover pontuação; AC04 não pesquisar documento por trecho numérico. Arquivo informado por José: `spec/controllers/admin/users_search_spec.rb` (ainda não disponível na main).

| Caso / critério | Entrada e ação relatadas | Esperado / observado no HTML | Status |
| --- | --- | --- | --- |
| RF002-01 / AC01 | Pesquisar nome, razão social, mãe e e-mail das pessoas de teste | Pessoa correspondente em cada um dos quatro campos | Passou — relato |
| RF002-02 / AC02 | Pesquisar trecho do nome variando maiúsculas/minúsculas | Pessoa encontrada por trecho | Passou — relato |
| RF002-03 / AC03 | Pesquisar CPF e CNPJ de teste completos com pontuação, sem divulgar documentos reais | Pessoas corretas por documento exato normalizado | Passou — relato |
| RF002-04 / AC04 | Pesquisar apenas trecho numérico do CPF | Não retornar a pessoa pelo documento parcial | Passou — relato |

## RF007 — José: fotos

**Critérios:** RF007-AC01 fotos opcionais, PNG/JPEG reais aceitos; AC02 conteúdo falso rejeitado; AC03 máximo cinco fotos e limite de 5 MB por arquivo; AC04 não reutilizar arquivo de outro relato. Arquivo informado por José: `spec/models/alert_photos_spec.rb` (ainda não disponível na main).

| Caso / critério | Entrada e ação relatadas | Esperado / observado no HTML | Status |
| --- | --- | --- | --- |
| RF007-01 / AC01 | Validar relato sem foto e com imagens PNG/JPEG reais | Ambas as condições aceitas | Passou — relato |
| RF007-02 / AC02 | Anexar texto com nome e MIME declarados PNG; validar | Conteúdo incompatível rejeitado | Passou — relato |
| RF007-03 / AC03 | Validar seis fotos e, separadamente, arquivo acima do limite de tamanho | Excesso de quantidade e tamanho rejeitados | Passou — relato |
| RF007-04 / AC04 | Anexar a outro relato blob já pertencente a uma postagem | Reutilização rejeitada | Passou — relato |

Resultado informado por José: **8 exemplos, 0 falhas**, quatro por arquivo.

## RF011 — Alisson: pânico (integração)

**Critérios:** RF011-AC01 exigir autenticação; AC02 pedir confirmação; AC03 registrar GPS/motivo em pedido restrito; AC04 selecionar agentes próximos. Raio/posição do agente não definidos no requisito; o teste relatado adotou locais de referência cadastrados, não um raio formal aprovado.

| Caso / critério | Entrada e ação relatadas | Esperado / observado no HTML | Status |
| --- | --- | --- | --- |
| RF011-01 / AC01 | Sem autenticação, solicitar pânico | Exigir login / direcionou ao login, sem criar pedido | Passou — relato |
| RF011-02 / AC02 | Abrir solicitação antes de confirmar | Não criar pedido / controles de pedir ajuda, confirmar e cancelar presentes | Passou — relato |
| RF011-03 / AC03 | Confirmar pedido com GPS e motivo | Pedido restrito, protocolo e aviso / registrados e visíveis ao agente de teste | Passou — relato |
| RF011-04 / AC04 | Pedido e dois agentes com referências próxima/distante; verificar destinatários | Só próximo / os dois receberam aviso interno, inclusive o distante | Falhou — relato |

## RF014 — Alisson: notificações (serviço/processamento)

**Critérios:** RF014-AC01 encaminhar aos canais configurados; AC02 evitar repetição; AC03 preservar anonimato; AC04 avisar usuário próximo (raio de 500 m para ocorrência comum). E-mail e push foram simulados: os casos não comprovam envio real nem eliminam a possibilidade de duplicação em outros fluxos.

| Caso / critério | Entrada e ação relatadas | Esperado / observado no HTML | Status |
| --- | --- | --- | --- |
| RF014-01 / AC01 | Processar aviso com e-mail/push simulados | Uma chamada por canal / ambos chamados uma vez e registrados como enviados | Passou — relato |
| RF014-02 / AC02 | Exercitar repetição do aviso no fluxo testado | Manter original sem duplicata / nenhuma duplicata nesse recorte | Passou — relato |
| RF014-03 / AC03 | Processar postagem com anonimato | Sem aviso ao autor ou entrega externa / nenhum criado | Passou — relato |
| RF014-04 / AC04 | Ocorrência comum com usuários próximo/distante, limite 500 m | Avisar somente próximo / apenas próximo recebeu na central | Passou — relato |

Resultado informado por Alisson: **8 exemplos, 1 falha**, seed **14011**. O plano, ZIP e log citados no HTML ainda não foram fornecidos; por isso seus links originais não estão disponíveis nesta cópia.

## Manuais auxiliares de Lucas — planejados

Ambiente de teste autorizado, dados fictícios e IDs conhecidos. Mapa: ocorrências em andamento, categorias ativas e aprovação específica preparada. Auditoria: conta autenticada com identidade pública oculta, admin e usuário comum; Turnstile configurado/válido, senão bloquear preparação; usar apenas metadados sintéticos da base RF016.

| Caso / critério | Entrada e ação | Esperado | Status |
| --- | --- | --- | --- |
| RF010-M01 / AC06 | Uma publicação aprovada para mapa, outra só para mural; abrir mapa | Somente a elegível ao mapa aparece | Planejado |
| RF010-M02 / AC06 | Publicações aprovadas em duas categorias; filtrar uma categoria | Apenas a categoria escolhida | Planejado |
| RF016-M01 / AC01, AC03 | Admin abre ocorrência preparada com auditoria | Metadados sintéticos e instante correto, com possível formatação de fuso | Planejado |
| RF016-M02 / AC03 | Abrir mural/detalhe público da publicação elegível | Sem IP, agente ou timestamp da auditoria | Planejado |
| RF016-M03 / AC03 | Usuário comum, inclusive autor, tenta URL administrativa | Sem metadados; HTML ao painel, demais formatos 403 na barreira admin | Planejado |

## Pendências da equipe

Confirmar autoria/independência cruzada e anexar código/logs dos relatos; investigar RF011-04 e definir proximidade, sem registrar correção não comprovada. Guilherme e Victor ainda devem acrescentar casos/evidências. Demais RFs/RNFs e conclusão coletiva permanecem pendentes; seleção de dez RFs não equivale à cobertura completa dos 28 requisitos.
