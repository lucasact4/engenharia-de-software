# Publicações acompanhadas pela própria pessoa, filtradas pelo que está no ar para ela agora.
class SubscribedPublicationsQuery
  def initialize(viewer)
    @viewer = viewer
  end

  def call
    return Publication.none unless @viewer&.active?

    relation = Publication.where(id: @viewer.publication_subscriptions.select(:publication_id))
    PublicationPolicy::FeedScope.new(@viewer, relation).resolve
  end

  def unavailable_count
    return 0 unless @viewer&.active?

    @viewer.publication_subscriptions.count - call.count
  end
end
