class PwaController < ActionController::Base
  skip_after_action :verify_same_origin_request, only: :service_worker

  def service_worker
    response.headers["Service-Worker-Allowed"] = "/"
    render "pwa/service-worker", formats: :js, layout: false, content_type: "application/javascript"
  end
end
