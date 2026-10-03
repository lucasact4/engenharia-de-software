# Edição do próprio perfil (nome, usuário, apresentação e opt-in público) por Users::UpdateProfile.
# Só esses campos são aceitos: e-mail, senha, admin, papéis e desativação nunca passam por aqui.
class ProfilesController < PortalController
  FIELDS = %i[display_name username bio public_profile].freeze

  before_action :set_user

  def show
    authorize @user, :show?, policy_class: ProfilePolicy
    @followers_count = PublicFollowersQuery.new(@user).count
    @following_count = FollowedProfilesQuery.new(@user).call.count
  end

  def edit
    authorize @user, :update?, policy_class: ProfilePolicy
  end

  def update
    authorize @user, :update?, policy_class: ProfilePolicy
    Users::UpdateProfile.call(actor: Current.user, user: @user, attributes: params.fetch(:user, {}).permit(*FIELDS).to_h)
    redirect_to profile_path, notice: "Perfil atualizado.", status: :see_other
  rescue ActiveRecord::RecordInvalid
    render :edit, status: :unprocessable_entity
  end

  private

    def set_user
      @user = User.find(Current.user.id)
    end
end
