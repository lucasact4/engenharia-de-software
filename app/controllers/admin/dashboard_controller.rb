# frozen_string_literal: true

# Visão geral da administração: filas que pedem ação e situação dos catálogos.
class Admin::DashboardController < Admin::ApplicationController
  def index
    authorize :dashboard, :index?
    open = Alert.where(status: AlertQueueFilters::OPEN_STATUSES)
    @counts = {
      open_alerts: open.count,
      open_panics: open.panic.count,
      unassigned: open.where(assigned_to_id: nil).count,
      pending_reviews: Publication.review_pending.count,
      source_review: Publication.needing_source_review.count,
      pending_reports: ContentReport.pending.count,
      active_locations: Location.active.count,
      active_categories: Category.active.count
    }
    render "dashboard"
  end
end
