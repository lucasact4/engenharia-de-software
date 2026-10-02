require "rails_helper"

RSpec.describe Presentation::Selection do
  let(:presentation) { Presentation.load }

  def selection(choices = {}, **options)
    described_class.new(presentation, choices, **options)
  end

  it "uses the catalog defaults when nothing was saved" do
    defaults = selection

    presentation.slides.each do |slide|
      expect(defaults.chosen?(slide.id)).to eq(slide.default)
    end
    expect(defaults.delivery[:id]).to eq(presentation.entrega[:entrega_padrao])
  end

  it "keeps the default second-delivery sequence within its seven-minute limit" do
    defaults = selection

    expect(defaults.limit_seconds).to eq(7 * 60)
    expect(defaults.total_seconds).to be <= defaults.limit_seconds
  end

  it "always shows the cover and the closing slide" do
    all_off = selection(presentation.catalog_keys.index_with(false))

    expect(all_off.visible_slides.map(&:id)).to eq(Presentation::REQUIRED_SLIDES)
    expect(all_off.label(presentation.slide("encerramento"))).to eq("02")
  end

  it "falls back to the catalog default for keys a saved profile does not know yet" do
    saved = selection({ "gestao" => false })

    expect(saved.chosen?("gestao")).to be(false)
    expect(saved.chosen?("gestao.cards")).to eq(presentation.item("gestao.cards").default)
  end

  it "ignores unknown keys and non-boolean values instead of choosing partials" do
    tampered = selection({ "../../layouts/application" => true, "gestao" => "1" })

    expect(tampered.to_h.keys).to match_array(presentation.catalog_keys)
    expect(tampered.chosen?("gestao")).to eq(presentation.slide("gestao").default)
  end

  it "keeps item choices while their slide is hidden" do
    hidden_slide = selection({ "arquitetura" => false, "arquitetura.mudancas" => false })

    expect(hidden_slide.slide_visible?(presentation.slide("arquitetura"))).to be(false)
    expect(hidden_slide.chosen?("arquitetura.mudancas")).to be(false)
    expect(hidden_slide.chosen?("arquitetura.tecnologias")).to be(true)
  end

  it "hides nested items together with their parent item" do
    nested = selection({ "arquitetura.tecnologias" => false, "arquitetura.versoes" => true })

    expect(nested.item_visible?("arquitetura.versoes")).to be(false)
  end

  it "omits a selected slide whose contents were all unchecked" do
    slide = presentation.slide("retrospectiva")
    empty = selection(slide.items.map(&:key).index_with(false).merge("retrospectiva" => true))

    expect(empty.slide_visible?(slide)).to be(false)
    expect(empty.without_content?(slide)).to be(true)
  end

  it "renumbers main slides and appendices over the visible sequence" do
    trimmed = selection({ "conceito-visual" => false, "checklist" => false, "conflitos" => true })

    expect(trimmed.label(presentation.slide("funcionalidades"))).to eq("02")
    expect(trimmed.label(presentation.slide("conflitos"))).to eq("A")
    expect(trimmed.label(presentation.slide("conceito-visual"))).to be_nil
  end

  it "flags estimates above the delivery limit only when the delivery has one" do
    everything = presentation.catalog_keys.index_with(true)

    expect(selection(everything).total_seconds).to be > 7 * 60
    expect(selection(everything).over_limit?).to be(true)
    expect(selection(everything, delivery_id: "primeira").over_limit?).to be(false)
  end


  it "orders the six first-delivery items and eight second-delivery items separately" do
    %w[primeira segunda].each do |delivery_id|
      delivery = presentation.delivery(delivery_id)
      academic = presentation.academic_slide_ids(delivery)
      choices = presentation.catalog_keys.index_with(false).merge(academic.index_with(true))
      academic.each { |id| presentation.slide(id).items.each { |item| choices[item.key] = true } }
      selected = selection(choices, delivery_id: delivery_id)
      expect(selected.visible_main_slides.map(&:id)).to eq([ "capa", *academic, "encerramento" ])
      expect(academic.size).to eq(delivery_id == "primeira" ? 6 : 8)
    end
  end

  describe "profiles saved before Gestão was split" do
    it "inherits the old GitHub and meeting choices in the new slides" do
      old = selection({ "gestao" => true, "gestao.praticas" => true, "gestao.reunioes" => false, "gestao.cards" => true })

      expect(old.chosen?("repositorio")).to be(true)
      expect(old.chosen?("repositorio.praticas")).to be(true)
      expect(old.chosen?("reunioes")).to be(false)
      expect(old.chosen?("reunioes.registros")).to be(false)
      expect(old.chosen?("gestao.cards")).to be(true)
      expect(old.to_h.keys).not_to include("gestao.praticas", "gestao.reunioes")
    end

    it "keeps the new slides hidden when the old Gestão slide was hidden" do
      old = selection({ "gestao" => false, "gestao.praticas" => true, "gestao.reunioes" => true })

      expect(old.slide_visible?(presentation.slide("repositorio"))).to be(false)
      expect(old.slide_visible?(presentation.slide("reunioes"))).to be(false)
    end

    it "prefers the new keys once the profile is saved again" do
      saved = selection({ "gestao" => true, "gestao.reunioes" => true, "reunioes" => false })

      expect(saved.chosen?("reunioes")).to be(false)
    end
  end

  it "names slides after the requirement of the profile delivery" do
    expect(selection(delivery_id: "segunda").slide_title(presentation.slide("conceito-visual"))).to eq("Protótipo com o conceito visual do projeto")
    expect(selection(delivery_id: "primeira").slide_title(presentation.slide("conceito-visual"))).to eq("Conceito visual")
    expect(selection(delivery_id: "primeira").requirement_label(presentation.slide("conceito-visual"))).to eq("Complementar")
  end
end
