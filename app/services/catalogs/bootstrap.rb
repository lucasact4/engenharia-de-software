module Catalogs
  # Insere apenas códigos ausentes; preserva catálogos editados e itens desativados.
  class Bootstrap
    ROLES = [
      [ "security", "Segurança", "Equipe de segurança do campus (premissa provisória de acesso a pânico)." ],
      [ "coordination", "Coordenação", "Coordenação responsável pela triagem de ocorrências comuns (premissa provisória)." ],
      [ "professor", "Professor", "Docente. Não concede poderes administrativos." ],
      [ "student", "Estudante", "Discente. Não concede poderes administrativos." ],
      [ "staff", "Funcionário", "Servidor técnico ou terceirizado. Não concede poderes administrativos." ],
      [ "visitor", "Visitante", "Pessoa visitante. Não concede poderes administrativos." ],
      [ "resident", "Morador", "Morador do entorno ou residência estudantil. Não concede poderes administrativos." ]
    ].freeze

    CATEGORIES = [
      [ "infrastructure", "Infraestrutura", "Prédios, iluminação, calçadas, acessibilidade e instalações.", false ],
      [ "security", "Segurança", "Situações de risco à integridade de pessoas ou ao patrimônio.", false ],
      [ "climate_environment", "Clima e ambiente", "Alagamentos, quedas de árvores, calor extremo e questões ambientais.", false ],
      [ "mobility_traffic", "Mobilidade e trânsito", "Vias, estacionamento, transporte e circulação no campus.", false ],
      [ "services_utilities", "Serviços e utilidades", "Água, energia, internet e outros serviços.", false ],
      [ "cleaning_sanitation", "Limpeza e saneamento", "Lixo, esgoto, banheiros e limpeza de áreas comuns.", false ],
      [ "other", "Outro", "Assunto que não se encaixa nas demais categorias; exige explicação.", true ]
    ].freeze

    def self.call
      now = Time.current
      roles = Role.insert_all(
        ROLES.each_with_index.map do |(code, name, description), index|
          { code:, name:, description:, active: true, position: (index + 1) * 10, created_at: now, updated_at: now }
        end,
        unique_by: :code
      )
      categories = Category.insert_all(
        CATEGORIES.each_with_index.map do |(code, name, description, requires_details), index|
          { code:, name:, description:, requires_details:, active: true, position: (index + 1) * 10,
            created_at: now, updated_at: now }
        end,
        unique_by: :code
      )
      { roles: roles.rows.size, categories: categories.rows.size }
    end
  end
end
