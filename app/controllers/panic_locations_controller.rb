class PanicLocationsController < PortalController
  before_action :load_alert

  def show
    authorize @alert, :read_panic_location?
    response.headers["Cache-Control"] = "no-store, private"
    latest = @alert.latest_panic_position unless @alert.panic_tracking_stopped?
    recent = latest && latest.fetch("captured_at") >= 30.seconds.ago.to_i * 1000
    render json: { stopped: @alert.panic_tracking_stopped?,
                   position: recent ? latest : (@alert.initial_gps_position unless @alert.panic_tracking_stopped?),
                   source: recent ? "live" : ("initial" unless @alert.panic_tracking_stopped?) }
  end

  def update
    authorize @alert, :update_panic_location?
    point = position_params
    return head :unprocessable_entity unless point

    accepted = @alert.with_lock do
      next false if @alert.panic_tracking_stopped?

      previous = @alert.latest_panic_position
      if !previous || point[:captured_at] > previous.fetch("captured_at")
        @alert.update_columns(panic_latest_position: point.stringify_keys)
      end
      true
    end
    head(accepted ? :no_content : :gone)
  end

  def destroy
    authorize @alert, :stop_panic_location?
    @alert.with_lock do
      unless @alert.panic_tracking_stopped_at?
        @alert.end_panic_tracking
        @alert.save!
        AuditEvent.record!(actor: Current.user, action: "alert.panic_tracking_stopped", subject: @alert)
      end
    end
    redirect_back fallback_location: alert_path(@alert), allow_other_host: false,
                  notice: "Acompanhamento de localização encerrado.", status: :see_other
  end

  private

    def load_alert
      @alert = policy_scope(Alert).where(kind: "panic").find(params[:id])
    end

    def position_params
      latitude = Float(params[:latitude], exception: false)
      longitude = Float(params[:longitude], exception: false)
      milliseconds = Integer(params[:captured_at], exception: false)
      return unless latitude&.between?(-90, 90) && longitude&.between?(-180, 180)
      return unless milliseconds&.between?(1.hour.ago.to_i * 1000, 1.minute.from_now.to_i * 1000)

      { latitude: latitude, longitude: longitude, captured_at: milliseconds }
    end
end
