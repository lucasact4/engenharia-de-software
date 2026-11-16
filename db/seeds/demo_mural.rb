# Popula o mural com ocorrências fictícias e completas para a demonstração da entrega final.
# Somente em development: bin/rails db:seed:demo_mural
#
# - Cria a conta "Estudante Demo" (estudante, sem selo de verificação, para a aprovação do passo 6).
#   A senha vem de SGU_DEMO_PASSWORD ou é gerada e guardada em tmp/sgu-demo-credenciais.txt (fora do Git).
# - Cria 8 pessoas fictícias (e-mails @sgu.test) com avatar e perfil público.
# - Cria 12 ocorrências pelos serviços do sistema, com foto ilustrativa gerada aqui (SVG → JPEG),
#   localização nos prédios oficiais do mapa, situação, curtidas, comentários, respostas e seguidores.
# Idempotente: pula pessoas e ocorrências que já existem (e-mail; título + autor).
raise "db:seed:demo_mural roda somente em development" unless Rails.env.development?

require "securerandom"
require "vips"

module DemoMural
  module_function

  DOMAIN = "sgu.test"
  CREDENTIALS_FILE = Rails.root.join("tmp/sgu-demo-credenciais.txt")
  BUILDINGS = JSON.parse(Rails.root.join("public/maps/ufrpe-sede-buildings-v2.geojson").read).fetch("features")

  PEOPLE = {
    ana: { name: "Ana Beatriz Lima", username: "ana_lima", role: "student", color: "#277d6e", bio: "Licenciatura em Computação · 5º período" },
    rafael: { name: "Rafael Albuquerque", username: "rafa_albuquerque", role: "student", color: "#c9861a", bio: "Agronomia · monitor de Solos" },
    claudia: { name: "Profa. Cláudia Menezes", username: "claudia_menezes", role: "professor", color: "#7c3aed", bio: "Departamento de Biologia" },
    joao: { name: "João Pedro Silva", username: "jp_silva", role: "student", color: "#2563eb", bio: "Zootecnia · morador da Casa do Estudante" },
    mariana: { name: "Mariana Costa", username: "mari_costa", role: "student", color: "#db2777", bio: "Engenharia de Pesca" },
    josue: { name: "Josué Ferreira", username: "josue_manutencao", role: "staff", color: "#0891b2", bio: "Equipe de manutenção predial" },
    thiago: { name: "Thiago Nascimento", username: "thiago_n", role: "student", color: "#16a34a", bio: "Ciências Biológicas · atleta da UFRPE" },
    larissa: { name: "Profa. Larissa Moura", username: "larissa_moura", role: "professor", color: "#dc2626", bio: "Departamento de Educação" }
  }.freeze

  # status: received | triaging | in_progress | resolved. hours: há quanto tempo foi publicado.
  OCCURRENCES = [
    { author: :ana, title: "Poste apagado no caminho do RU", category: "services_utilities", severity: "moderate",
      building: "Restaurante Universitário - RU", status: "in_progress", priority: "high", assessed: "moderate", scene: :lamp, hours: 70,
      description: "O poste em frente ao Restaurante Universitário está apagado há três noites. Na volta das aulas do noturno o trecho fica muito escuro.",
      likes: 7, comments: [
        [ :thiago, "Passei lá ontem às 21h e realmente está um breu." ],
        [ :josue, "A manutenção já registrou. A troca da lâmpada está prevista para esta semana.", [ [ :ana, "Obrigada pelo retorno!" ] ] ]
      ] },
    { author: :josue, title: "Vazamento no banheiro do Prédio Central", category: "services_utilities", severity: "high",
      building: "PREDIO CENTRAL", status: "in_progress", priority: "urgent", assessed: "high", scene: :leak, hours: 30,
      description: "Cano rompido no banheiro masculino do térreo. A água está escorrendo para o corredor; a área foi isolada com cone.",
      likes: 5, comments: [
        [ :mariana, "O corredor já está escorregadio, cuidado!" ],
        [ :claudia, "Avisei a turma para usar o banheiro do 1º andar enquanto isso." ]
      ] },
    { author: :claudia, title: "Rampa de acesso quebrada na Biblioteca Central", category: "infrastructure", severity: "high",
      building: "Biblioteca Central", status: "triaging", priority: "high", assessed: "high", scene: :ramp, hours: 52,
      description: "A rampa lateral da Biblioteca Central tem uma rachadura grande e um degrau de uns 5 cm. Quem usa cadeira de rodas não consegue subir sem ajuda.",
      likes: 9, comments: [
        [ :ana, "Isso é urgente: um colega cadeirante usa essa entrada todos os dias." ],
        [ :rafael, "Dá para entrar pela frente enquanto isso, mas a porta é bem pesada.", [ [ :claudia, "Boa dica, vou avisar a turma." ] ] ]
      ] },
    { author: :rafael, title: "Alagamento em frente ao Centro de Ensino Agrícola", category: "climate_environment", severity: "high",
      building: "Centro de Ensino Agrícola I", status: "in_progress", priority: "high", assessed: "moderate", scene: :flood, hours: 20,
      description: "Depois da chuva de hoje a via ficou alagada e a água chega no meio da canela. Os bueiros parecem entupidos.",
      likes: 6, comments: [
        [ :joao, "Também alagou perto da Casa do Estudante." ],
        [ :larissa, "Precisei remarcar a aula prática por causa disso." ]
      ] },
    { author: :joao, title: "Galho prestes a cair na Casa do Estudante", category: "climate_environment", severity: "critical",
      building: "CASA DO ESTUDANTE", status: "triaging", priority: "urgent", assessed: "high", scene: :tree, hours: 8,
      description: "Um galho grande da mangueira ao lado da Casa do Estudante quebrou com o vento e está pendurado sobre a calçada.",
      likes: 11, comments: [
        [ :mariana, "Passei por baixo hoje de manhã sem perceber. Que perigo!" ],
        [ :josue, "Área isolada com fita. A poda já foi solicitada.", [ [ :joao, "Valeu, Josué!" ] ] ]
      ] },
    { author: :mariana, title: "Lixeiras transbordando perto da PRAE", category: "cleaning_sanitation", severity: "moderate",
      building: "PRAE", status: "received", scene: :trash, hours: 5,
      description: "As lixeiras ao lado da PRAE estão cheias desde segunda e o lixo já está no chão. Começou a juntar mosquito.",
      likes: 4, comments: [ [ :thiago, "Na frente do DEFIS está igual." ] ] },
    { author: :thiago, title: "Iluminação fraca no estacionamento do DEFIS", category: "security", severity: "high",
      building: "DEFIS", status: "triaging", priority: "high", assessed: "high", scene: :parking, hours: 36,
      description: "Só um dos refletores do estacionamento do DEFIS funciona. Depois das 19h fica difícil enxergar quem está por perto.",
      likes: 8, comments: [
        [ :larissa, "Saio da aula às 21h e evito estacionar lá por isso." ],
        [ :ana, "Seria bom ter ronda nesse horário também." ]
      ] },
    { author: :larissa, title: "Fila de carros na entrada principal", category: "mobility_traffic", severity: "low",
      building: "ADMINISTRATIVO", status: "received", scene: :traffic, hours: 26,
      description: "Trânsito parado na entrada principal por volta das 7h. O portão libera só uma faixa e os carros ficam enfileirados na avenida.",
      likes: 3, comments: [ [ :rafael, "Hoje levei 20 minutos só para entrar." ] ] },
    { author: :ana, title: "Ar-condicionado pingando no Prédio Ivan Tavares", category: "infrastructure", severity: "low",
      building: "Prédio Professor Ivan Tavares", status: "resolved", priority: "normal", assessed: "low", scene: :ac, hours: 120,
      description: "O ar-condicionado da sala 12 está pingando em cima das carteiras do fundo.",
      likes: 5, comments: [
        [ :josue, "Dreno desentupido e unidade revisada. Pode conferir?", [ [ :ana, "Conferi hoje: parou de pingar. Obrigada!" ] ] ]
      ] },
    { author: :thiago, title: "Bebedouro quebrado na Quadra de Esportes", category: "services_utilities", severity: "moderate",
      building: "QUADRA DE ESPORTES", status: "resolved", priority: "normal", assessed: "moderate", scene: :fountain, hours: 160,
      description: "O bebedouro da quadra não sai água. Nos treinos da tarde todo mundo precisa ir até o DEFIS para beber água.",
      likes: 6, comments: [
        [ :joao, "Já trocaram? Hoje estava funcionando.", [ [ :thiago, "Trocaram ontem, agora está ok." ] ] ]
      ] },
    { author: :claudia, title: "Buraco na calçada do Departamento de Biologia", category: "infrastructure", severity: "moderate",
      building: "Prédio do Departamento de Biologia", status: "received", scene: :hole, hours: 14,
      description: "Há um buraco na calçada da entrada do Departamento de Biologia, perto da escada. Já vi duas pessoas tropeçarem.",
      likes: 5, comments: [ [ :mariana, "Tropecei aí na semana passada." ] ] },
    { author: :mariana, title: "Wi-Fi instável no 2º andar da Biblioteca", category: "services_utilities", severity: "low",
      building: "Biblioteca Central", status: "in_progress", priority: "normal", assessed: "low", scene: :wifi, hours: 44,
      description: "A rede da Biblioteca Central cai a cada poucos minutos no 2º andar, o que atrapalha quem estuda para as provas.",
      likes: 10, comments: [
        [ :ana, "No térreo também está caindo." ],
        [ :rafael, "Disseram que o roteador do 2º andar vai ser trocado." ]
      ] }
  ].freeze

  # Pânicos de exemplo (RF011/RNF001): públicos aparecem no topo do mural; privados só no atendimento.
  PANICS = [
    { author: :thiago, building: "Centro de Ensino Agrícola I", public: true, status: "received",
      description: "Alguém está fazendo assaltos no caminho do Transrural, perto do CEAGRI 2. Dois homens de moto abordando quem passa a pé." },
    { author: :mariana, building: "OFICINA / GALPÃO DE MECÂNICA", public: true, status: "triaging",
      description: "Fumaça saindo do Galpão de Mecânica, com cheiro forte de queimado. Afastem-se da área." },
    { author: :ana, building: "Biblioteca Central", public: false, status: "received",
      description: "Estou passando mal no 2º andar da Biblioteca Central e preciso de ajuda." },
    { author: :joao, building: "CASA DO ESTUDANTE", public: false, status: "in_progress",
      description: "Uma pessoa desconhecida está me seguindo perto da Casa do Estudante." }
  ].freeze

  def run
    admin = User.where(admin: true, deleted_at: nil).order(:id).first or raise "Crie um administrador antes (db:seed)."
    admin_identity(admin)
    @credentials = {}
    student = demo_account(admin, key: "estudante.demo", name: "Estudante Demo", username: "estudante_demo",
                           role: "student", color: "#f2bd57", initials: "ED", bio: "Conta de demonstração da entrega final.")
    demo_account(admin, key: "seguranca.demo", name: "Carlos Andrade", username: "seguranca_demo",
                 role: "security", color: "#d64550", initials: "CA", bio: "Equipe de segurança (conta de demonstração).")
    write_credentials
    people = PEOPLE.to_h { |key, attributes| [ key, person(attributes, admin) ] }
    follow_each_other(people.values + [ student ])

    results = OCCURRENCES.sort_by { |item| -item[:hours] }.map { |item| occurrence(item, people, student, admin) }.tally
    puts "Mural de demonstração: #{results[:created].to_i} criada(s), #{results[:skipped].to_i} já existiam, #{results[:failed].to_i} com erro."
    panics = PANICS.map { |item| panic(item, people, admin) }.tally
    puts "Pânicos de demonstração: #{panics[:created].to_i} criado(s), #{panics[:skipped].to_i} já existiam, #{panics[:failed].to_i} com erro."
    puts "Contas de estudante e de segurança: veja #{CREDENTIALS_FILE.relative_path_from(Rails.root)}"
  end

  # Contas --------------------------------------------------------------------

  def demo_account(admin, key:, name:, username:, role:, color:, initials:, bio:)
    email = "#{key}@#{DOMAIN}"
    user = User.find_by(email_address: email)
    password = ENV["SGU_DEMO_PASSWORD"].presence
    password ||= saved_password(email) if user

    if user.nil? || password.nil? || !user.authenticate(password)
      password ||= "Sgu-#{SecureRandom.alphanumeric(6)}7a!"
      user ||= User.new(email_address: email)
      user.assign_attributes(password: password, password_confirmation: password)
    end
    user.assign_attributes(
      display_name: name, username: username, public_profile: true, deleted_at: nil, bio: bio,
      person_type: "natural", registration_status: "approved",
      registration_role_code: (role if User::REGISTRATION_ROLES.include?(role)),
      registration_reviewed_at: user.registration_reviewed_at || Time.current,
      registration_reviewed_by: user.registration_reviewed_by || admin,
      email_confirmed_at: user.email_confirmed_at || Time.current, email_verified_at: user.email_verified_at || Time.current
    )
    user.save!
    grant_role(user, role)
    attach_avatar(user, color, initials)
    @credentials[email] = [ name, password ]
    user
  end

  # Conta administrativa com cara de perfil oficial: nome, @ e o escudo do SGU como foto.
  def admin_identity(admin)
    admin.display_name ||= "Administração SGU"
    admin.username ||= "admin_sgu" unless User.where.not(id: admin.id).exists?(username: "admin_sgu")
    admin.bio ||= "Conta oficial da equipe que administra o SGU · UFRPE."
    admin.verified_at ||= Time.current
    admin.verified_by ||= admin
    admin.save!
    return if admin.avatar.attached?

    admin.avatar.attach(io: StringIO.new(render_png(ADMIN_AVATAR_SVG)), filename: "avatar-admin.png", content_type: "image/png")
  end

  ADMIN_AVATAR_SVG = <<~SVG.freeze
    <svg xmlns="http://www.w3.org/2000/svg" width="320" height="320" viewBox="0 0 320 320">
      <defs>
        <radialGradient id="bg" cx="30%" cy="25%" r="90%"><stop offset="0" stop-color="#2f8a76"/><stop offset="1" stop-color="#0f2f2a"/></radialGradient>
        <clipPath id="shield"><path d="M14 6H86A10 10 0 0 1 96 16V54C96 81 77 98 50 108C23 98 4 81 4 54V16A10 10 0 0 1 14 6Z"/></clipPath>
      </defs>
      <rect width="320" height="320" fill="url(#bg)"/>
      <circle cx="262" cy="58" r="110" fill="#ffffff" opacity="0.07"/>
      <g transform="translate(70 58) scale(1.8)">
        <path d="M14 6H86A10 10 0 0 1 96 16V54C96 81 77 98 50 108C23 98 4 81 4 54V16A10 10 0 0 1 14 6Z" fill="#153C36" stroke="#F4F7F5" stroke-width="3"/>
        <path d="M4 79C18 71 34 67 50 67S82 71 96 79V54 120H4Z" fill="#226A5C" clip-path="url(#shield)"/>
        <path d="M50 86V50" fill="none" stroke="#F4F7F5" stroke-width="7" stroke-linecap="round"/>
        <path d="M50 66C46 54 37 47 25 46C27 58 36 66 50 66Z" fill="#F4F7F5"/>
        <path d="M50 56C55 42 66 34 80 33C78 48 66 56 50 56Z" fill="#F4F7F5"/>
        <circle cx="50" cy="33" r="6.5" fill="#F2BD57"/>
      </g>
    </svg>
  SVG

  def saved_password(email)
    return unless CREDENTIALS_FILE.exist?

    CREDENTIALS_FILE.read[/e-mail: #{Regexp.escape(email)}\nsenha: (.+)$/, 1]
  end

  def write_credentials
    FileUtils.mkdir_p(CREDENTIALS_FILE.dirname)
    body = @credentials.map { |email, (name, password)| "#{name}\ne-mail: #{email}\nsenha: #{password}\n" }.join("\n")
    File.write(CREDENTIALS_FILE, "Contas de demonstração (somente development; não versionar).\n\n#{body}", perm: 0o600)
  end

  def person(attributes, admin)
    email = "#{attributes[:username]}@#{DOMAIN}"
    user = User.find_or_initialize_by(email_address: email)
    if user.new_record?
      secret = "Sgu-#{SecureRandom.alphanumeric(12)}9b!"
      user.assign_attributes(password: secret, password_confirmation: secret)
    end
    user.assign_attributes(
      display_name: attributes[:name], username: attributes[:username], bio: attributes[:bio], public_profile: true,
      person_type: "natural", registration_status: "approved", registration_role_code: (attributes[:role] if User::REGISTRATION_ROLES.include?(attributes[:role])),
      registration_reviewed_at: user.registration_reviewed_at || Time.current, registration_reviewed_by: user.registration_reviewed_by || admin,
      email_confirmed_at: user.email_confirmed_at || Time.current, email_verified_at: user.email_verified_at || Time.current,
      verified_at: user.verified_at || Time.current, verified_by: user.verified_by || admin, deleted_at: nil
    )
    user.save!
    grant_role(user, attributes[:role])
    initials = attributes[:name].sub(/\AProfa?\.\s*/, "").split.values_at(0, -1).map { |part| part[0] }.join
    attach_avatar(user, attributes[:color], initials)
    user
  end

  def grant_role(user, code)
    role = Role.find_by(code: code)
    user.user_roles.find_or_create_by!(role: role) if role
  end

  def attach_avatar(user, color, initials)
    return if user.avatar.attached?

    svg = <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="320" height="320" viewBox="0 0 320 320">
        <rect width="320" height="320" fill="#{color}"/>
        <circle cx="250" cy="70" r="120" fill="#ffffff" opacity="0.12"/>
        <text x="160" y="196" text-anchor="middle" font-family="DejaVu Sans, sans-serif" font-size="128" font-weight="bold" fill="#ffffff">#{initials}</text>
      </svg>
    SVG
    user.avatar.attach(io: StringIO.new(render_png(svg)), filename: "avatar-#{user.username}.png", content_type: "image/png")
  end

  def follow_each_other(users)
    users.each_with_index do |user, index|
      users.rotate(index + 1).first(3).each do |other|
        Social::Interactions.follow(actor: user, user: other) unless other == user
      rescue StandardError => error
        warn "  seguir #{other.username}: #{error.message}"
      end
    end
  end

  # Ocorrências ---------------------------------------------------------------

  def occurrence(item, people, student, admin)
    author = people.fetch(item[:author])
    # O título é cifrado no banco (RNF004): a comparação é feita já decifrada.
    existing = Alert.occurrence.where(author_id: author.id).find { |alert| alert.title == item[:title] }
    if existing
      refresh_photo(existing, item) if ENV["SGU_DEMO_REFRESH_IMAGES"].present?
      return :skipped
    end

    latitude, longitude = building_point(item[:building])
    published = item[:hours].hours.ago
    attributes = {
      title: item[:title], description: item[:description],
      category_id: Category.find_by!(code: item[:category]).id,
      location_source: "gps", latitude: latitude.round(7).to_s, longitude: longitude.round(7).to_s,
      location_accuracy_meters: 12, location_captured_at: 5.minutes.ago.iso8601,
      reported_severity: item[:severity], requested_visibility: "public_external", share_exact_location: false
    }
    alert = Alerts::CreateOccurrence.call(actor: author, attributes: attributes, photos: [ photo_for(item) ]).alert

    if item[:assessed] || item[:priority]
      Alerts::Assess.call(actor: admin, alert: alert, attributes: { assessed_severity: item[:assessed], priority: item[:priority] }.compact)
    end
    path = { "received" => [], "triaging" => %w[triaging], "in_progress" => %w[triaging in_progress],
             "resolved" => %w[triaging in_progress resolved] }.fetch(item[:status])
    path.each { |status| Alerts::Transition.call(actor: admin, alert: alert.reload, to: status) }

    publication = alert.reload.publication
    if publication && %w[received triaging in_progress].include?(item[:status])
      Publications::ApproveForCampusMap.call(actor: admin, publication: publication)
    end

    backdate(alert, publication, published)
    interact(item, publication.reload, people, student, published) if publication
    puts "  + #{item[:title]} (#{item[:status]})"
    :created
  rescue StandardError => error
    warn "  ! #{item[:title]}: #{error.class}: #{error.message}"
    :failed
  end

  def panic(item, people, admin)
    author = people.fetch(item[:author])
    # A descrição é cifrada no banco (RNF004): a comparação é feita já decifrada.
    return :skipped if Alert.panic.where(author_id: author.id).any? { |existing| existing.description == item[:description] }

    latitude, longitude = building_point(item[:building])
    attributes = {
      description: item[:description], location_source: "gps",
      latitude: latitude.round(7).to_s, longitude: longitude.round(7).to_s,
      location_accuracy_meters: 15, location_captured_at: 1.minute.ago.iso8601, public_warning: item[:public]
    }
    alert = Alerts::CreatePanic.call(actor: author, attributes: attributes, client_request_id: SecureRandom.uuid).alert
    path = { "received" => [], "triaging" => %w[triaging], "in_progress" => %w[triaging in_progress] }.fetch(item[:status])
    path.each { |status| Alerts::Transition.call(actor: admin, alert: alert.reload, to: status) }
    puts "  + pânico #{item[:public] ? 'público' : 'privado'}: #{item[:description].truncate(60)}"
    :created
  rescue StandardError => error
    warn "  ! pânico #{item[:description].truncate(40)}: #{error.class}: #{error.message}"
    :failed
  end

  def photo_for(item)
    { io: StringIO.new(render_jpeg(scene_svg(item[:scene], place_label(item[:building])))),
      filename: "#{item[:scene]}.jpg", content_type: "image/jpeg" }
  end

  # SGU_DEMO_REFRESH_IMAGES=1 troca a foto ilustrativa das ocorrências de demonstração já criadas.
  def refresh_photo(alert, item)
    alert.photos.each(&:purge)
    alert.photos.attach(photo_for(item))
    puts "  ~ foto atualizada: #{item[:title]}"
  end

  PLACE_LABELS = {
    "PREDIO CENTRAL" => "Prédio Central", "CASA DO ESTUDANTE" => "Casa do Estudante", "QUADRA DE ESPORTES" => "Quadra de Esportes",
    "ADMINISTRATIVO" => "Entrada principal", "Prédio Professor Ivan Tavares" => "Prédio Ivan Tavares",
    "Prédio do Departamento de Biologia" => "Departamento de Biologia", "Restaurante Universitário - RU" => "Restaurante Universitário"
  }.freeze

  def place_label(building) = PLACE_LABELS.fetch(building, building)

  def interact(item, publication, people, student, published)
    everyone = people.values + [ student ]
    others = everyone.reject { |user| user.id == publication.author_id }

    others.first(item[:likes]).each_with_index do |user, index|
      Social::Interactions.add_to_publication(actor: user, publication: publication, kind: :like)
      Social::Interactions.add_to_publication(actor: user, publication: publication, kind: :bookmark) if index.even?
    end

    item[:comments].each_with_index do |(who, body, replies), index|
      commenter = people.fetch(who)
      comment = Comments::Create.call(actor: commenter, publication: publication, body: body)
      comment.update_columns(created_at: published + (index + 1) * 47.minutes, updated_at: published + (index + 1) * 47.minutes)
      Social::Interactions.add_to_publication(actor: commenter, publication: publication, kind: :subscription)
      others.sample(2, random: Random.new(comment.id)).each { |user| Social::Interactions.like_comment(actor: user, comment: comment) unless user == commenter }

      Array(replies).each_with_index do |(reply_who, reply_body), reply_index|
        reply = Comments::Create.call(actor: people.fetch(reply_who), publication: publication, body: reply_body, parent: comment)
        at = published + (index + 1) * 47.minutes + (reply_index + 1) * 18.minutes
        reply.update_columns(created_at: at, updated_at: at)
      end
    end
  end

  def backdate(alert, publication, at)
    alert.update_columns(created_at: at, updated_at: [ at + 2.hours, Time.current ].min)
    publication&.update_columns(created_at: at, published_at: at)
  end

  # Ponto dentro do prédio oficial (média dos vértices; volta ao primeiro vértice se cair fora).
  def building_point(name)
    feature = BUILDINGS.find { |item| item.dig("properties", "name") == name } or raise "prédio não encontrado: #{name}"
    geometry = feature.fetch("geometry")
    ring = geometry["type"] == "MultiPolygon" ? geometry["coordinates"].first.first : geometry["coordinates"].first
    longitude = ring.sum { |point| point[0] } / ring.size
    latitude = ring.sum { |point| point[1] } / ring.size
    inside?([ longitude, latitude ], ring) ? [ latitude, longitude ] : [ ring.first[1], ring.first[0] ]
  end

  def inside?(point, ring)
    x, y = point
    ring.each_cons(2).count do |(x1, y1), (x2, y2)|
      ((y1 > y) != (y2 > y)) && x < (x2 - x1) * (y - y1) / (y2 - y1) + x1
    end.odd?
  end

  # Imagens ilustrativas --------------------------------------------------------

  def render_png(svg) = with_svg_loader { Vips::Image.new_from_buffer(svg, "").pngsave_buffer }

  def render_jpeg(svg)
    with_svg_loader { Vips::Image.new_from_buffer(svg, "").flatten(background: [ 255, 255, 255 ]).jpegsave_buffer(Q: 86, strip: true) }
  end

  # O Rails bloqueia leitores "não confiáveis" do libvips (SVG incluso). Aqui o SVG é gerado por este
  # arquivo, então o leitor é liberado só durante a renderização e bloqueado de novo em seguida.
  def with_svg_loader
    Vips.block("VipsForeignLoadSvg", false)
    yield
  ensure
    Vips.block("VipsForeignLoadSvg", true)
  end

  # Quadro 4:5 (1200 × 1500), a proporção do carrossel do mural: céu acima, cena 1200 × 800 no meio
  # e o chão da cena estendido até a etiqueta.
  def scene_svg(scene, place)
    body = send(:"scene_#{scene}")
    top, bottom, ground = SKIES.fetch(scene)
    label = "Imagem ilustrativa · #{place}"
    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="1200" height="1500" viewBox="0 0 1200 1500">
        <defs>
          <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#{top}"/><stop offset="1" stop-color="#{bottom}"/></linearGradient>
        </defs>
        <rect width="1200" height="1200" fill="url(#sky)"/>
        <rect y="1150" width="1200" height="350" fill="#{ground}"/>
        <g transform="translate(0 360)">#{body}</g>
        <g font-family="DejaVu Sans, sans-serif" font-size="30">
          <rect x="40" y="1388" width="#{(label.length * 17.5).round + 56}" height="68" rx="34" fill="#0d2925" opacity="0.85"/>
          <text x="68" y="1433"><tspan font-weight="bold" fill="#f2bd57">Imagem ilustrativa</tspan><tspan fill="#e3efeb"> · #{ERB::Util.html_escape(place)}</tspan></text>
        </g>
      </svg>
    SVG
  end

  # céu (topo, base) e chão estendido abaixo da cena.
  SKIES = {
    lamp: %w[#07142a #1d3557 #1b2a22], leak: %w[#dfe9ee #c9d8df #aebdc4], ramp: %w[#cfe8f5 #f3f9fc #b9b2a5],
    flood: %w[#6f7d88 #b2bec6 #4d7f9f], tree: %w[#8fd3f4 #e2f4fb #6aa84f], trash: %w[#e9e4d6 #d7d0bd #9b9686],
    traffic: %w[#ffcf8a #fde7c4 #4b5563], parking: %w[#0b1424 #1f2d44 #181d23], ac: %w[#efe6d6 #e2d6c1 #b9a98f],
    fountain: %w[#bfe3f7 #eaf6fd #d9774a], hole: %w[#d7ecf7 #f2f8fb #bdb6a8], wifi: %w[#ede3d2 #e0d2bb #b99c75]
  }.freeze

  def scene_lamp
    stars = 26.times.map { |i| %(<circle cx="#{(i * 97) % 1180 + 10}" cy="#{(i * 53) % 260 + 20}" r="#{i % 3 + 1}" fill="#fff" opacity="0.7"/>) }.join
    windows = 12.times.map { |i| %(<rect x="#{680 + (i % 6) * 66}" y="#{420 + (i / 6) * 70}" width="38" height="34" rx="4" fill="#f2bd57" opacity="#{i.even? ? 0.85 : 0.45}"/>) }.join
    <<~SVG
      #{stars}
      <rect x="0" y="600" width="1200" height="200" fill="#1b2a22"/>
      <polygon points="430,600 610,600 900,800 140,800" fill="#3a434b"/>
      <rect x="640" y="360" width="460" height="240" rx="10" fill="#26333c"/>#{windows}
      <rect x="820" y="318" width="100" height="44" rx="8" fill="#277d6e"/><text x="870" y="350" text-anchor="middle" font-family="DejaVu Sans" font-size="28" font-weight="bold" fill="#fff">RU</text>
      <rect x="352" y="250" width="16" height="360" fill="#59646d"/>
      <path d="M360 260 Q360 220 430 220 L470 220" stroke="#59646d" stroke-width="12" fill="none"/>
      <rect x="440" y="214" width="80" height="26" rx="8" fill="#3b444c"/>
      <ellipse cx="480" cy="244" rx="26" ry="10" fill="#6b7177"/>
      <path d="M150 760 L300 640 M1050 760 L940 650" stroke="#000" stroke-width="2" opacity="0.2"/>
      <circle cx="480" cy="300" r="70" fill="#000" opacity="0.25"/>
    SVG
  end

  def scene_leak
    tiles = (0..12).map { |i| %(<line x1="#{i * 100}" y1="0" x2="#{i * 100}" y2="620" stroke="#c4d3da" stroke-width="3"/>) }.join +
            (0..6).map { |i| %(<line x1="0" y1="#{i * 100}" x2="1200" y2="#{i * 100}" stroke="#c4d3da" stroke-width="3"/>) }.join
    drops = [ [ 545, 300 ], [ 560, 380 ], [ 540, 460 ], [ 575, 520 ] ].map { |x, y| %(<path d="M#{x} #{y} q12 22 0 30 q-12 -8 0 -30z" fill="#3d9ad6"/>) }.join
    <<~SVG
      #{tiles}
      <rect x="0" y="620" width="1200" height="180" fill="#aebdc4"/>
      <rect x="0" y="210" width="1200" height="44" fill="#8a9399"/><rect x="520" y="200" width="70" height="64" rx="8" fill="#6d757b"/>
      <path d="M548 254 l10 18 l-8 10" stroke="#3d9ad6" stroke-width="6" fill="none"/>
      #{drops}
      <ellipse cx="600" cy="690" rx="330" ry="48" fill="#4da3d9" opacity="0.6"/>
      <polygon points="920,700 980,500 1040,700" fill="#f97316"/><rect x="900" y="690" width="160" height="22" rx="6" fill="#ea580c"/>
      <rect x="944" y="560" width="72" height="20" fill="#fff"/><rect x="930" y="620" width="100" height="20" fill="#fff"/>
    SVG
  end

  def scene_ramp
    <<~SVG
      <rect x="0" y="140" width="1200" height="480" fill="#e7d8c4"/>
      <rect x="820" y="260" width="200" height="360" rx="8" fill="#8b5e3c"/><circle cx="1000" cy="450" r="8" fill="#e7c48a"/>
      <rect x="0" y="620" width="1200" height="180" fill="#b9b2a5"/>
      <polygon points="120,640 800,470 800,640" fill="#c9c1b3"/><polygon points="120,640 800,470 800,486 160,650" fill="#a39b8d"/>
      <path d="M380 590 l30 -24 l-12 -10 l34 -22 l-10 -14 l40 -26" stroke="#3b3326" stroke-width="7" fill="none" stroke-linecap="round"/>
      <path d="M140 600 L800 430" stroke="#6b6458" stroke-width="10" stroke-linecap="round"/>
      <rect x="1040" y="300" width="110" height="110" rx="14" fill="#2563eb"/>
      <circle cx="1096" cy="326" r="11" fill="#fff"/><path d="M1094 340 v30 h26 l10 24 M1080 356 a26 26 0 1 0 38 30" stroke="#fff" stroke-width="7" fill="none" stroke-linecap="round"/>
      <g transform="rotate(-8 600 700)"><rect x="200" y="690" width="800" height="26" fill="#facc15"/>#{(0..15).map { |i| %(<polygon points="#{210 + i * 50},690 #{235 + i * 50},690 #{220 + i * 50},716 #{195 + i * 50},716" fill="#111"/>) }.join}</g>
    SVG
  end

  def scene_flood
    rain = 60.times.map { |i| x = (i * 41) % 1200; y = (i * 67) % 520; %(<line x1="#{x}" y1="#{y}" x2="#{x - 14}" y2="#{y + 40}" stroke="#e5edf2" stroke-width="3" opacity="0.6"/>) }.join
    <<~SVG
      <rect x="40" y="250" width="320" height="300" fill="#56636d"/><rect x="820" y="210" width="340" height="340" fill="#4d5a63"/>
      <rect x="0" y="540" width="1200" height="260" fill="#55606a"/>
      <rect x="420" y="520" width="300" height="90" rx="30" fill="#c0392b"/><rect x="470" y="470" width="190" height="70" rx="20" fill="#d35445"/>
      <rect x="490" y="482" width="70" height="44" rx="8" fill="#bfe1f2"/><rect x="572" y="482" width="70" height="44" rx="8" fill="#bfe1f2"/>
      <rect x="0" y="580" width="1200" height="220" fill="#4f86a8" opacity="0.88"/>
      <path d="M0 580 q50 -16 100 0 t100 0 t100 0 t100 0 t100 0 t100 0 t100 0 t100 0 t100 0 t100 0 t100 0 t100 0" fill="none" stroke="#a9d3ea" stroke-width="6"/>
      <rect x="980" y="300" width="12" height="300" fill="#7a868e"/><polygon points="986,260 1040,330 932,330" fill="#facc15" stroke="#111" stroke-width="4"/>
      <text x="986" y="320" text-anchor="middle" font-family="DejaVu Sans" font-size="40" font-weight="bold" fill="#111">!</text>
      #{rain}
    SVG
  end

  def scene_tree
    <<~SVG
      <rect x="760" y="300" width="400" height="300" fill="#e3d5bf"/>#{6.times.map { |i| %(<rect x="#{790 + (i % 3) * 120}" y="#{340 + (i / 3) * 110}" width="80" height="70" fill="#9ec4d6"/>) }.join}
      <rect x="0" y="600" width="1200" height="200" fill="#6aa84f"/><rect x="0" y="650" width="1200" height="60" fill="#c9c3b6"/>
      <rect x="300" y="300" width="70" height="330" fill="#7a4e2d"/>
      <circle cx="335" cy="250" r="150" fill="#2f7d32"/><circle cx="220" cy="300" r="110" fill="#388e3c"/><circle cx="450" cy="300" r="110" fill="#2e7d32"/>
      <path d="M440 330 L560 420 L610 560" stroke="#6b4426" stroke-width="26" fill="none" stroke-linecap="round"/>
      <circle cx="620" cy="560" r="62" fill="#3d8b40"/><circle cx="580" cy="600" r="44" fill="#43a047"/>
      <path d="M548 412 l-18 -6 l10 -16" stroke="#f2bd57" stroke-width="5" fill="none"/>
      <polygon points="760,700 800,580 840,700" fill="#f97316"/><rect x="745" y="694" width="110" height="18" rx="5" fill="#ea580c"/>
    SVG
  end

  def scene_trash
    bags = [ [ 360, 330, 60 ], [ 440, 310, 52 ], [ 300, 360, 46 ], [ 720, 340, 58 ], [ 800, 320, 50 ], [ 520, 600, 48 ], [ 640, 620, 40 ] ]
      .map { |x, y, r| %(<circle cx="#{x}" cy="#{y}" r="#{r}" fill="#{x.even? ? '#2f2f33' : '#4a4a52'}"/>) }.join
    flies = 14.times.map { |i| %(<circle cx="#{330 + (i * 37) % 560}" cy="#{180 + (i * 29) % 120}" r="4" fill="#111"/>) }.join
    <<~SVG
      <rect x="0" y="560" width="1200" height="240" fill="#9b9686"/>
      <rect x="250" y="360" width="240" height="260" rx="18" fill="#2e7d32"/><rect x="232" y="340" width="276" height="40" rx="12" fill="#1b5e20"/>
      <rect x="660" y="360" width="240" height="260" rx="18" fill="#607d8b"/><rect x="642" y="340" width="276" height="40" rx="12" fill="#455a64"/>
      #{bags}
      <rect x="930" y="640" width="70" height="44" fill="#fff" transform="rotate(18 965 662)"/><rect x="120" y="660" width="60" height="38" fill="#f2f2f2" transform="rotate(-14 150 679)"/>
      #{flies}
    SVG
  end

  def scene_traffic
    cars = [ [ 80, 560, "#c0392b" ], [ 300, 560, "#2563eb" ], [ 520, 560, "#f2bd57" ], [ 160, 660, "#16a34a" ], [ 380, 660, "#7c3aed" ], [ 600, 660, "#e5e7eb" ] ]
      .map { |x, y, c| %(<g><rect x="#{x}" y="#{y}" width="180" height="62" rx="18" fill="#{c}"/><rect x="#{x + 34}" y="#{y - 30}" width="110" height="40" rx="12" fill="#{c}"/><rect x="#{x + 44}" y="#{y - 22}" width="40" height="26" rx="5" fill="#bfe1f2"/><rect x="#{x + 92}" y="#{y - 22}" width="40" height="26" rx="5" fill="#bfe1f2"/><circle cx="#{x + 40}" cy="#{y + 62}" r="18" fill="#111"/><circle cx="#{x + 140}" cy="#{y + 62}" r="18" fill="#111"/></g>) }.join
    <<~SVG
      <rect x="0" y="500" width="1200" height="300" fill="#4b5563"/>
      #{(0..11).map { |i| %(<rect x="#{i * 110}" y="642" width="60" height="8" fill="#f8fafc"/>) }.join}
      <rect x="860" y="240" width="40" height="300" fill="#334155"/><rect x="1120" y="240" width="40" height="300" fill="#334155"/>
      <rect x="840" y="200" width="340" height="60" rx="10" fill="#277d6e"/><text x="1010" y="242" text-anchor="middle" font-family="DejaVu Sans" font-size="34" font-weight="bold" fill="#fff">UFRPE</text>
      <rect x="900" y="470" width="220" height="14" fill="#e11d48"/><rect x="1000" y="470" width="20" height="14" fill="#fff"/>
      <rect x="780" y="300" width="50" height="130" rx="10" fill="#111827"/><circle cx="805" cy="330" r="15" fill="#ef4444"/><circle cx="805" cy="365" r="15" fill="#3f3f46"/><circle cx="805" cy="400" r="15" fill="#3f3f46"/>
      #{cars}
    SVG
  end

  def scene_parking
    <<~SVG
      <rect x="0" y="480" width="1200" height="320" fill="#20262e"/>
      #{(0..7).map { |i| %(<line x1="#{80 + i * 150}" y1="520" x2="#{40 + i * 160}" y2="800" stroke="#e5e7eb" stroke-width="5" opacity="0.5"/>) }.join}
      <rect x="140" y="160" width="12" height="340" fill="#4b5563"/><rect x="110" y="150" width="72" height="20" rx="6" fill="#374151"/>
      <circle cx="146" cy="176" r="10" fill="#fde68a"/><ellipse cx="146" cy="560" rx="180" ry="50" fill="#fde68a" opacity="0.18"/>
      <rect x="980" y="160" width="12" height="340" fill="#4b5563"/><rect x="950" y="150" width="72" height="20" rx="6" fill="#374151"/><circle cx="986" cy="176" r="10" fill="#52525b"/>
      #{[ [ 300, 560 ], [ 520, 580 ], [ 760, 560 ] ].map { |x, y| %(<rect x="#{x}" y="#{y}" width="170" height="70" rx="20" fill="#111827" stroke="#334155" stroke-width="4"/>) }.join}
      <rect x="0" y="0" width="1200" height="800" fill="#000" opacity="0.25"/>
    SVG
  end

  def scene_ac
    <<~SVG
      <rect x="0" y="620" width="1200" height="180" fill="#b9a98f"/>
      <rect x="380" y="140" width="440" height="150" rx="18" fill="#f8fafc" stroke="#cbd5e1" stroke-width="6"/>
      #{(0..5).map { |i| %(<rect x="410" y="#{226 + i * 9}" width="380" height="4" fill="#94a3b8"/>) }.join}
      <circle cx="770" cy="180" r="8" fill="#22c55e"/>
      <path d="M600 290 q-10 120 -2 330" stroke="#9cc4dc" stroke-width="30" opacity="0.35" fill="none"/>
      #{[ [ 560, 340 ], [ 600, 420 ], [ 580, 500 ] ].map { |x, y| %(<path d="M#{x} #{y} q14 24 0 34 q-14 -10 0 -34z" fill="#3d9ad6"/>) }.join}
      <rect x="500" y="610" width="200" height="110" rx="10" fill="#2563eb"/><ellipse cx="600" cy="612" rx="100" ry="16" fill="#60a5fa"/>
      <rect x="120" y="470" width="220" height="16" fill="#8b5e3c"/><rect x="140" y="486" width="14" height="140" fill="#8b5e3c"/><rect x="306" y="486" width="14" height="140" fill="#8b5e3c"/>
      <rect x="860" y="470" width="220" height="16" fill="#8b5e3c"/><rect x="880" y="486" width="14" height="140" fill="#8b5e3c"/><rect x="1046" y="486" width="14" height="140" fill="#8b5e3c"/>
    SVG
  end

  def scene_fountain
    <<~SVG
      <rect x="0" y="470" width="1200" height="330" fill="#d9774a"/>
      <path d="M0 640 H1200 M600 470 V800" stroke="#fff" stroke-width="8" opacity="0.8"/><circle cx="600" cy="640" r="90" stroke="#fff" stroke-width="8" fill="none" opacity="0.8"/>
      <rect x="0" y="220" width="1200" height="250" fill="#9aa5ad"/>#{(0..9).map { |i| %(<rect x="#{i * 130}" y="220" width="12" height="250" fill="#7d8890"/>) }.join}
      <rect x="440" y="300" width="320" height="380" rx="20" fill="#cbd5e1" stroke="#94a3b8" stroke-width="6"/>
      <rect x="470" y="320" width="260" height="90" rx="40" fill="#e2e8f0"/><circle cx="600" cy="360" r="14" fill="#64748b"/>
      <rect x="500" y="460" width="200" height="70" rx="10" fill="#dc2626" transform="rotate(-6 600 495)"/>
      <text x="600" y="508" text-anchor="middle" font-family="DejaVu Sans" font-size="30" font-weight="bold" fill="#fff" transform="rotate(-6 600 495)">FORA DE USO</text>
    SVG
  end

  def scene_hole
    tiles = (0..12).flat_map { |i| (0..4).map { |j| %(<rect x="#{i * 100 + (j.odd? ? 50 : 0) - 50}" y="#{420 + j * 80}" width="96" height="76" fill="#cfcac0" stroke="#b5afa3" stroke-width="3"/>) } }.join
    <<~SVG
      <rect x="0" y="120" width="1200" height="300" fill="#e8dfcf"/>#{(0..3).map { |i| %(<rect x="#{120 + i * 260}" y="170" width="140" height="120" fill="#9ec4d6"/>) }.join}
      <rect x="0" y="400" width="1200" height="400" fill="#bdb6a8"/>#{tiles}
      <path d="M430 600 q40 -70 140 -60 q120 -10 150 50 q30 70 -80 90 q-150 20 -210 -80z" fill="#2b2620"/>
      <path d="M470 600 q60 -40 130 -36" stroke="#4a4136" stroke-width="10" fill="none"/>
      <polygon points="820,700 860,560 900,700" fill="#f97316"/><rect x="806" y="694" width="108" height="18" rx="5" fill="#ea580c"/>
      <rect x="836" y="610" width="48" height="16" fill="#fff"/>
    SVG
  end

  def scene_wifi
    books = (0..2).flat_map { |row| (0..15).map { |i| %(<rect x="#{70 + i * 44}" y="#{170 + row * 120}" width="36" height="96" fill="#{%w[#277d6e #c9861a #7c3aed #dc2626 #2563eb #0891b2][(i + row) % 6]}"/>) } }.join
    <<~SVG
      <rect x="40" y="140" width="740" height="400" fill="#7a5233"/>#{books}
      <rect x="40" y="270" width="740" height="10" fill="#5c3c24"/><rect x="40" y="390" width="740" height="10" fill="#5c3c24"/>
      <rect x="0" y="560" width="1200" height="240" fill="#b99c75"/>
      <rect x="640" y="520" width="520" height="24" fill="#6b4a2c"/>
      <rect x="760" y="360" width="300" height="170" rx="12" fill="#1f2937"/><rect x="776" y="376" width="268" height="138" rx="6" fill="#e2e8f0"/>
      <rect x="730" y="526" width="360" height="16" rx="6" fill="#374151"/>
      <path d="M850 440 a80 80 0 0 1 120 0 M870 462 a52 52 0 0 1 80 0 M892 484 a22 22 0 0 1 36 0" stroke="#277d6e" stroke-width="10" fill="none" stroke-linecap="round"/>
      <line x1="845" y1="400" x2="975" y2="500" stroke="#dc2626" stroke-width="12" stroke-linecap="round"/>
    SVG
  end
end

DemoMural.run
