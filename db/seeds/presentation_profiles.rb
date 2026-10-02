# Perfis iniciais da apresentação (/apresentacao). Idempotente: cria só os perfis ausentes e
# nunca altera um perfil já editado no admin. Cada lista traz as chaves do catálogo
# (config/presentation/roteiro.yml) que ficam marcadas; as demais ficam desmarcadas.
presentation = Presentation.load

profiles = [
  {
    name: "Primeira entrega",
    delivery: "primeira",
    description: "Requisitos refinados, ferramentas, casos de uso, Trello, próximos passos e lições aprendidas.",
    enabled: %w[
      problema problema.dores problema.publico problema.proposta
      escopo escopo.dimensoes escopo.conflitos
      requisitos requisitos.funcionais requisitos.nao-funcionais requisitos.criterios requisitos.documento
      arquitetura arquitetura.tecnologias arquitetura.versoes arquitetura.diagrama
      casos-de-uso
      gestao gestao.trello gestao.cards gestao.ambientes
      proximos-passos proximos-passos.marco proximos-passos.passos proximos-passos.riscos proximos-passos.dependencias
      retrospectiva retrospectiva.pontos retrospectiva.licoes
      encerramento.links
      checklist conflitos roteiro
    ]
  },
  {
    name: "Segunda entrega — Status Report 2",
    delivery: "segunda",
    description: "Protótipo, GitHub e duas funcionalidades, retrospectiva, modelo conceitual, reuniões e status report (até 7 minutos).",
    active: true,
    enabled: %w[
      problema problema.dores problema.proposta
      evolucao evolucao.linha-do-tempo evolucao.capacidades evolucao.observacoes
      conceito-visual conceito-visual.prototipo conceito-visual.landing conceito-visual.login conceito-visual.mobile conceito-visual.paleta conceito-visual.notas
      funcionalidades funcionalidades.criterios funcionalidades.funcionalidade-1 funcionalidades.funcionalidade-2
      modelo-conceitual modelo-conceitual.diagrama modelo-conceitual.distincao
      arquitetura arquitetura.tecnologias arquitetura.versoes arquitetura.mudancas
      gestao gestao.cards gestao.praticas gestao.reunioes gestao.trello
      retrospectiva retrospectiva.imagem retrospectiva.pontos retrospectiva.acoes retrospectiva.licoes
      proximos-passos proximos-passos.marco proximos-passos.passos proximos-passos.riscos proximos-passos.dependencias
      encerramento.links
      checklist conflitos modelo-dados evidencias evidencias.commits evidencias.arquivos evidencias.testes roteiro
    ]
  }
]

profiles.each do |attributes|
  unknown = attributes[:enabled] - presentation.catalog_keys
  raise ArgumentError, "Perfil #{attributes[:name]}: chaves fora do catálogo: #{unknown.join(', ')}" if unknown.any?

  PresentationProfile.find_or_create_by!(name: attributes[:name]) do |profile|
    profile.delivery = attributes[:delivery]
    profile.description = attributes[:description]
    profile.active = attributes[:active] == true && !PresentationProfile.exists?(active: true)
    profile.selections = (presentation.catalog_keys - Presentation::REQUIRED_SLIDES)
      .index_with { |key| attributes[:enabled].include?(key) }
  end
end
