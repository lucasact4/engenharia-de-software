# Ocorrências que podem virar fonte de uma nova publicação: compatíveis com alguma audiência
# editorial (Publication.compatible_sources_for), sem publicação derivada e dentro do acesso
# de quem edita. Pânicos e alertas bloqueados nunca aparecem.
class PublicationSourcesQuery
  LIMIT = 50

  def initialize(viewer, term: nil)
    @viewer = viewer
    @term = term.to_s.strip
  end

  def call
    compatible = Publication.compatible_sources_for("internal").or(Publication.compatible_sources_for("public_external"))
    relation = AlertPolicy::Scope.new(@viewer, compatible).resolve
      .where.not(id: Publication.where.not(alert_id: nil).select(:alert_id))
    relation = relation.text_search(@term, "alerts.protocol", "alerts.title")
    relation.recent_first.limit(LIMIT)
  end
end
