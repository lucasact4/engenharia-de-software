# Grade de publicações do perfil (próprio ou público), no formato dos cartões do mural.
module ProfileGrid
  extend ActiveSupport::Concern

  GRID_PER_PAGE = 24

  private

    def load_profile_grid(person)
      scope = ProfilePublicationsQuery.new(person, viewer: Current.user).call
      @posts_count = scope.count
      @pagy, records = pagy(scope, limit: GRID_PER_PAGE)
      @grid_cards = PublicationProjection.collection(records, viewer: Current.user)
    end

    # Contadores do cabeçalho do próprio perfil (também usados na aba Salvos).
    def load_own_profile_summary(user)
      @followers_count = PublicFollowersQuery.new(user).count
      @following_count = FollowedProfilesQuery.new(user).call.count
      @posts_count ||= ProfilePublicationsQuery.new(user, viewer: user).call.count
    end
end
