# frozen_string_literal: true

module Admin::UsersHelper
  include Admin::BaseHelper

  # Não expõe documentos pessoais na tabela de resultados da busca.
  def admin_index_visible_attributes
    %w[display_name email_address username registration_status]
  end

  def admin_index_description
    if I18n.locale.to_s == "en"
      "Search by name, business name, mother's name, CPF, or CNPJ. Document searches are exact and accept punctuation."
    else
      "Pesquise por nome, razão social, nome da mãe, CPF ou CNPJ. Para documentos, a busca é exata e aceita pontuação."
    end
  end
end
