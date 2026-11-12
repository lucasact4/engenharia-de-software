# Plano único de testes da equipe — em consolidação

Branch `testes/rf010-rf016-lucas-vitor`. [Link comum de entrega](https://github.com/lucasact4/engenharia-de-software/blob/testes/rf010-rf016-lucas-vitor/docs/plano-testes-equipe.md). [Card #53 — recorte Lucas e evidências](https://trello.com/c/BSGE2VRG). [Documento de requisitos](https://docs.google.com/document/d/1Z-G_nlIvvTVX9EKb3dZUui2HXBQL_vz4f8bAMfQmtv0/edit).

## Estratégia e avaliação

Parte coletiva: um plano compartilhado com seções, autoria, critérios, casos e evidências rastreáveis. Parte individual: cinco vídeos próprios de até 2 minutos, todos com o mesmo link deste plano. Cada integrante seleciona dois RFs, escreve casos para ambos e automatiza no mínimo quatro casos de um RF. Não se presume obrigação de um terceiro requisito adicional. Estratégia Lucas: RF010 com seis unidades e plano manual; RF016 manual.

Antes das matrizes, registrar critérios verificáveis, distinguindo texto do requisito, refinamento implementado e lacunas. Unidade verifica algoritmo; integração exercita fluxo público/dependências; manual verifica interface e resultado observado. Não transformar teste verde de caracterização de lacuna em aceite do requisito inteiro.

Cada seção deve conter: responsável, implementador do trecho, critérios `RFxxx-ACnn`, testes `RFxxx-UTnn`/`RFxxx-Mnn`, entrada concreta, ação, esperado, status e evidência. Execução registra testador, ambiente/data, commit, comando, seed, saída e divergências no card correspondente. Casos sem execução ficam planejados; bloqueios ficam explícitos.

## Quem fez o quê e estado real

Seleções dos colegas conforme escolhas comunicadas por captura; isso não confirma autoria, automação pronta ou execução. Conferir implementador e ausência de contribuições do testador ao trecho antes de reconhecer independência do teste cruzado.

| Integrante | RFs selecionados | Automação e casos escritos | Execução / independência |
| --- | --- | --- | --- |
| Alisson Cerqueira | RF011, RF014 | Automação A DEFINIR; autoria/casos não confirmados | Não confirmada; conferir autor e contribuições |
| José de Lemos | RF002, RF007 | Automação A DEFINIR; autoria/casos não confirmados | Não confirmada; conferir autor e contribuições |
| Guilherme Santiago | RF012, RF015 | Automação A DEFINIR; autoria/casos não confirmados | Não confirmada; RF012 bloqueado por não implementação, equipe deve rever escolha/escopo |
| Victor Novais | RF001, RF005 | Automação A DEFINIR; autoria/casos não confirmados | Não confirmada; conferir autor e contribuições |
| Lucas Vitor | RF010, RF016 | Seis unidades RF010 e escrita dos dois RFs com apoio de ferramenta; seção vinculada | Execução local assistida: 6/6 e conjunto 10/10; manuais pendentes |

RF010 implementado por José (`74f297b`, `921d5de`, `b1d176a`, `fe915e3`). RF016: modelo `AnonymousSubmissionAudit` e captura de Alisson (`e2889d1`); Victor implementou o fluxo anterior de postagem anônima. Lucas apoiou integração, schema e specs, sem autoria do modelo de captura. A seção de Lucas delimita os testes ao núcleo dos colegas e explicita essas contribuições anteriores.

## Seções individuais

- [Lucas — critérios, seis unidades RF010, planos RF010/RF016, evidências e roteiro](test-planning-automation-lucas.md).
- Alisson, José, Guilherme e Victor: seções/links, critérios, casos, implementadores e evidências **pendentes de inclusão pelos responsáveis**. Podem escrever neste plano ou vincular seções individuais; o link entregue continua sendo o plano comum.

## Cobertura dos 28 requisitos

Inventário de 19 RFs e 9 RNFs, conferido na auditoria local. `RF003` corresponde ao identificador `RF03` usado na fonte. Seleção indica responsabilidade de planejamento, não cobertura comprovada. Os dez RFs selecionados ainda dependem de consolidação e execução; este documento não é um plano completo dos 28.

| Requisito | Responsável selecionado / situação |
| --- | --- |
| RF001 | Victor — casos/evidências pendentes |
| RF002 | José — seleção confirmada; casos/evidências pendentes |
| RF003 | Pendente de seleção pela equipe |
| RF004 | Pendente de seleção pela equipe |
| RF005 | Victor — casos/evidências pendentes |
| RF006 | Pendente de seleção pela equipe |
| RF007 | José — casos/evidências pendentes |
| RF008 | Pendente de seleção pela equipe |
| RF009 | Pendente de seleção pela equipe |
| RF010 | Lucas — seis unidades executadas; lacuna L01 e manuais pendentes |
| RF011 | Alisson — casos/evidências pendentes |
| RF012 | Guilherme — não implementado; bloqueio para equipe rever |
| RF013 | Pendente de seleção pela equipe; fora do recorte Lucas |
| RF014 | Alisson — casos/evidências pendentes |
| RF015 | Guilherme — casos/evidências pendentes |
| RF016 | Lucas — plano de metadados; execução e independência pendentes |
| RF017 | Pendente de seleção pela equipe |
| RF018 | Pendente de seleção pela equipe; fora do recorte Lucas |
| RF019 | Pendente de seleção pela equipe |
| RNF001 | Pendente: responsável, critérios e evidências |
| RNF002 | Pendente: responsável, critérios e evidências |
| RNF003 | Pendente: responsável, critérios e evidências |
| RNF004 | Pendente: responsável, critérios e evidências |
| RNF005 | Pendente: responsável, critérios e evidências |
| RNF006 | Pendente: responsável, critérios e evidências |
| RNF007 | Pendente: responsável, critérios e evidências |
| RNF008 | Pendente: responsável, critérios e evidências |
| RNF009 | Pendente: responsável, critérios e evidências |

## Evidência disponível e próximos preenchimentos

Commit `b810fce`: execução local assistida de seis novas unidades RF010, **6 examples, 0 failures**, seed **36050**, e RuboCop sem infrações. Conjunto com quatro integrações já existentes: **10 examples, 0 failures**, seed **12345**. Os quatro exemplos existentes não são autoria nova de Lucas. Casos manuais não executados; demais participações não confirmadas. Evidências de RF013 não sustentam este recorte.

Equipe deve completar seções, rever bloqueio RF012, confirmar autoria/independência e registrar resultados reais antes de declarar conclusão coletiva. Fonte do inventário: `docs/auditoria-rastreabilidade-requisitos.md`; detalhes técnicos e limitações estão na seção Lucas. Plano preparado com apoio de ferramenta, sujeito à revisão dos responsáveis.
