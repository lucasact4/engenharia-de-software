module MuralHelper
  MURAL_CATEGORY_ICONS = {
    "infrastructure" => "building-2", "security" => "shield",
    "climate_environment" => "cloud-rain", "mobility_traffic" => "bus",
    "services_utilities" => "wrench", "cleaning_sanitation" => "trash",
    "other" => "tag"
  }.freeze

  # Ação de publicação para quem não entrou: mesmo botão de quem está logado, mas leva à tela de
  # entrada/criação de conta e depois volta para a publicação.
  def guest_action_link(card, label, css = nil, anchor: nil, &block)
    return_to = publication_path(card[:id], locale: nil, anchor: anchor)
    link_to new_session_path(locale: nil, return_to: return_to), class: [ "social-icon-button", css ],
            aria: { label: label }, title: label, rel: "nofollow", data: { turbo_frame: "_top" }, &block
  end

  # Liga/desliga uma categoria mantendo as demais e os outros filtros da busca.
  def mural_category_toggle_path(category_id, selected_ids)
    ids = selected_ids.include?(category_id) ? selected_ids - [ category_id ] : selected_ids + [ category_id ]
    mural_categories_path(ids)
  end

  def mural_categories_path(ids)
    query = request.query_parameters.except("page", "pesquisa", "category_id", "category_ids")
    query["category_ids"] = ids.sort if ids.any?
    publications_path(query)
  end

  def mural_category_icon(category, css = "size-7")
    sgu_icon(MURAL_CATEGORY_ICONS.fetch(category.code, "tag"), css)
  end

  # Foto da conta (o dono sempre vê a própria, mesmo com perfil privado) ou iniciais.
  def account_avatar(user, css, name: nil)
    label = name || user.display_name.presence || user.username.presence || user.email_address
    tag.span(class: css, aria: { hidden: true }) do
      if user.avatar.attached?
        image_tag(profile_photo_path(user), alt: "", class: "size-full rounded-full object-cover", loading: "lazy")
      else
        initials_for(label)
      end
    end
  end

  def account_handle(user)
    user.username.present? ? "@#{user.username}" : user.email_address.to_s.split("@").first
  end

  def mural_nav_link(label, path, glyph, active: false, css: nil, short_label: nil, profile: false)
    link_to path, class: [ "mural-nav-link", css ], data: { tooltip: label },
                  aria: { label: label, current: ("page" if active) } do
      visual = if profile && Current.user
        account_avatar(Current.user, "mural-nav-avatar")
      else
        sgu_icon(glyph, "size-6")
      end
      text = if short_label
        safe_join([ tag.span(label, class: "mural-label-long"), tag.span(short_label, class: "mural-label-short") ])
      else
        label
      end
      safe_join([ visual, tag.span(text, class: "mural-nav-label") ])
    end
  end
end
