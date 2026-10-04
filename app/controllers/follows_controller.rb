# Seguir/deixar de seguir perfil público (POST/DELETE idempotentes). Seguir não concede acesso
# a nada privado; deixar de seguir funciona mesmo que o perfil tenha saído do ar.
class FollowsController < PortalController
  def create
    person = policy_scope(User, policy_scope_class: PublicProfilePolicy::Scope).find(params[:person_id])
    authorize person, :follow?, policy_class: FollowPolicy
    Social::Interactions.follow(actor: Current.user, user: person)
    redirect_to person_path(person), notice: "Você está seguindo este perfil.", status: :see_other
  end

  def destroy
    skip_authorization # remove só o vínculo da própria sessão
    Social::Interactions.unfollow(actor: Current.user, user: User.new(id: params[:person_id].to_i))
    person = policy_scope(User, policy_scope_class: PublicProfilePolicy::Scope).find_by(id: params[:person_id])
    redirect_to (person ? person_path(person) : follow_ups_path), notice: "Você deixou de seguir este perfil.", status: :see_other
  end
end
