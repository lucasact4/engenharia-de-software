require "rails_helper"

RSpec.describe BrandHelper, type: :helper do
  it "renders both theme versions when the background follows the theme" do
    html = Nokogiri::HTML.fragment(helper.sgu_brand(:horizontal, class_name: "h-9"))
    wrapper = html.at_css(".sgu-brand--auto")

    expect(wrapper["role"]).to eq("img")
    expect(wrapper["aria-label"]).to eq("SGU")
    expect(wrapper["class"]).to include("h-9")
    expect(wrapper.css("img").map { |image| image["src"] }).to match([ %r{brand/sgu-logo-horizontal-\h+\.svg}, %r{brand/sgu-logo-horizontal-negativo-\h+\.svg} ])
    expect(wrapper.css("img").map { |image| image["alt"] }).to all(eq(""))
  end

  it "hides a decorative brand from assistive technology" do
    wrapper = Nokogiri::HTML.fragment(helper.sgu_brand(:symbol, alt: "")).at_css(".sgu-brand")

    expect(wrapper["aria-hidden"]).to eq("true")
    expect(wrapper["role"]).to be_nil
  end

  it "uses a single fixed version on surfaces that never change, and swaps dark slides for print" do
    expect(helper.sgu_brand(:vertical, tone: :on_light)).to match(%r{<img[^>]+brand/sgu-logo-vertical-\h+\.svg})
    expect(helper.sgu_brand(:symbol, tone: :on_dark)).to match(%r{brand/sgu-simbolo-negativo-\h+\.svg})
    expect(helper.sgu_brand(:symbol, tone: :dark_surface)).to include("sgu-brand--dark-surface", "sgu-brand__on-light", "sgu-brand__on-dark")
  end

  it "rejects unknown layouts and tones" do
    expect { helper.sgu_brand(:banner) }.to raise_error(KeyError)
    expect { helper.sgu_brand(:symbol, tone: :sepia) }.to raise_error(ArgumentError)
  end

  it "ships the three transparent PNG versions with the same symbol" do
    %w[sgu-simbolo sgu-logo-horizontal sgu-logo-vertical].each do |name|
      [ "", "-negativo" ].each do |suffix|
        image = Vips::Image.new_from_file(Rails.root.join("app/assets/images/brand/#{name}#{suffix}.png").to_s)
        alpha = image[3]
        expect(image.bands).to eq(4)
        expect([ alpha.getpoint(0, 0).first, alpha.getpoint(image.width - 1, image.height - 1).first ]).to eq([ 0.0, 0.0 ])
        expect(alpha.max).to eq(255.0)
      end
    end
  end
end
