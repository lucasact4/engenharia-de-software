# Perfis públicos (opt-in de conta ativa). Mostra apenas nome, usuário, apresentação e
# seguidores públicos; e-mail, papéis, alertas, salvos e atividade privada nunca aparecem.
# Perfil privado, desativado ou inexistente responde 404.
class PublicProfilesController < PortalController
  allow_unauthenticated_access only: %i[index show followers]

  def index
    authorize User, :index?, policy_class: PublicProfilePolicy
    scope = policy_scope(User, policy_scope_class: PublicProfilePolicy::Scope)
    scope = scope.text_search(params[:q], "users.display_name", "users.username")
    @pagy, @people = pagy(scope.order(Arel.sql("COALESCE(users.display_name, users.username)"), :id), limit: 24)
  end

  def show
    @person = find_person
    authorize @person, :show?, policy_class: PublicProfilePolicy
    @followers_count = PublicFollowersQuery.new(@person).count
    @following = Current.user && UserFollow.exists?(follower_id: Current.user.id, followed_id: @person.id)
    @can_follow = Current.user && FollowPolicy.new(Current.user, @person).follow?
  end

  def followers
    @person = find_person
    authorize @person, :show?, policy_class: PublicProfilePolicy
    @pagy, @followers = pagy(PublicFollowersQuery.new(@person).call.order(:display_name, :id), limit: 30)
    @followers_count = PublicFollowersQuery.new(@person).count
  end

  private

    def find_person
      policy_scope(User, policy_scope_class: PublicProfilePolicy::Scope).find(params[:id])
    end
end
