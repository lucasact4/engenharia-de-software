# Cria somente os perfis ausentes. Reorganizar perfis existentes é uma ação explícita.
presentation = Presentation.load
profiles = [
  {
    name: "Primeira entrega", delivery: "primeira",
    description: "Seis itens da primeira entrega na ordem do enunciado.",
    enabled: %w[
      requisitos requisitos.funcionais requisitos.nao-funcionais requisitos.criterios requisitos.documento
      arquitetura arquitetura.tecnologias arquitetura.versoes arquitetura.diagrama arquitetura.mudancas
      casos-de-uso
      gestao gestao.trello gestao.cards gestao.ambientes
      proximos-passos proximos-passos.marco proximos-passos.passos proximos-passos.riscos proximos-passos.dependencias
      retrospectiva retrospectiva.pontos retrospectiva.acoes retrospectiva.licoes
      encerramento.links
    ]
  },
  {
    name: "Segunda entrega — Status Report 2", delivery: "segunda", active: true,
    description: "Cinco itens da segunda entrega e três itens do status report, na ordem do enunciado.",
    enabled: %w[
      conceito-visual conceito-visual.landing conceito-visual.login conceito-visual.mobile conceito-visual.paleta conceito-visual.notas
      funcionalidades funcionalidades.repositorio funcionalidades.criterios funcionalidades.funcionalidade-1 funcionalidades.funcionalidade-2
      retrospectiva retrospectiva.imagem
      modelo-conceitual modelo-conceitual.diagrama modelo-conceitual.situacao modelo-conceitual.distincao
      reunioes reunioes.registros
      evolucao evolucao.linha-do-tempo evolucao.observacoes
      proximos-passos proximos-passos.marco proximos-passos.passos proximos-passos.riscos proximos-passos.dependencias
      status-report status-report.aprendizados status-report.acoes status-report.registro
      encerramento.links
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
