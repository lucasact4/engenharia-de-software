class GoogleSessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ create callback ]
  rate_limit to: 12, within: 1.minute, only: %i[ create connect ], with: -> { redirect_to new_session_path, alert: t("authentication.sessions.rate_limited"), status: :see_other }

  def create
    return redirect_to edit_profile_path, status: :see_other if authenticated?

    begin_google_sign_in
  end

  def connect
    password = params[:password]
    return failure(:invalid_password) unless password.is_a?(String) && password.bytesize <= 72 && Current.user.authenticate(password)

    begin_google_sign_in
  end

  def callback
    response.headers["Cache-Control"] = "no-store"
    response.headers["Referrer-Policy"] = "no-referrer"
    attempt = session.delete(:google_sign_in)
    resume_session
    return failure(:invalid_callback) unless valid_attempt?(attempt)

    I18n.locale = attempt.fetch("locale")
    return failure(:cancelled) if params[:error] == "access_denied"
    return failure(:unavailable) if params[:error].in?(%w[temporarily_unavailable server_error]) || !GoogleSignIn.configured?
    return failure(:invalid_response) if params.key?(:error)
    return failure(:invalid_response) unless params[:code].is_a?(String) && params[:code].present? && params[:code].bytesize <= 4096

    subject = GoogleSignIn.exchange(code: params[:code], nonce: attempt.fetch("nonce"), verifier: attempt.fetch("verifier"))
    Current.user ? connect_account(subject) : sign_in_account(subject)
  rescue GoogleSignIn::InvalidResponse
    failure(:invalid_response)
  rescue GoogleSignIn::Unavailable
    failure(:unavailable)
  end

  def destroy
    Current.user.with_lock { Current.user.update!(google_subject: nil) }
    session.delete(:google_sign_in)
    redirect_to edit_profile_path, notice: t("authentication.google.disconnected"), status: :see_other
  end

  private

    def begin_google_sign_in
      return failure(:unavailable) unless GoogleSignIn.configured?

      attempt = {
        "state" => SecureRandom.urlsafe_base64(32),
        "nonce" => SecureRandom.urlsafe_base64(32),
        "verifier" => SecureRandom.urlsafe_base64(48),
        "expires_at" => 10.minutes.from_now.to_i,
        "session_id" => Current.session&.id,
        "locale" => I18n.locale.to_s
      }
      session[:google_sign_in] = attempt
      response.headers["Cache-Control"] = "no-store"
      url = GoogleSignIn.authorization_url(state: attempt.fetch("state"), nonce: attempt.fetch("nonce"), verifier: attempt.fetch("verifier"))
      redirect_to url, allow_other_host: true, status: :see_other
    end

    def valid_attempt?(attempt)
      attempt && attempt.fetch("expires_at") > Time.current.to_i &&
        attempt.fetch("session_id") == Current.session&.id &&
        params[:state].is_a?(String) && ActiveSupport::SecurityUtils.secure_compare(attempt.fetch("state"), params[:state])
    end

    def connect_account(subject)
      user = Current.user
      linked = user.with_lock do
        if user.active? && (user.google_subject.nil? || user.google_subject == subject)
          user.update!(google_subject: subject)
        end
      end
      return failure(:link_failed) unless linked

      redirect_to edit_profile_path, notice: t("authentication.google.connected"), status: :see_other
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      failure(:link_failed)
    end

    def sign_in_account(subject)
      user = User.active.find_by(google_subject: subject)
      return failure(:not_linked) unless user

      return_to = session[:return_to_after_authenticating]
      user.with_lock do
        return failure(:not_linked) unless user.active? && user.google_subject == subject

        reset_session
        session[:return_to_after_authenticating] = return_to if return_to
        start_new_session_for(user)
      end
      redirect_to after_authentication_url, status: :see_other
    end

    def failure(message)
      redirect_to(Current.user ? edit_profile_path : new_session_path,
                  alert: t("authentication.google.#{message}"), status: :see_other)
    end
end
