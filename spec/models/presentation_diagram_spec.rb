require "rails_helper"

RSpec.describe PresentationDiagram do
  subject(:diagrams) { described_class.load_all }

  it "covers the current columns and every physical foreign key" do
    content = YAML.safe_load_file(described_class::CONTENT_FILE)
    connection = ActiveRecord::Base.connection
    tables = connection.tables - %w[schema_migrations ar_internal_metadata]
    expect(content.fetch("tables").keys).to match_array(tables)
    tables.each do |table|
      expect(content["tables"][table]["columns"].map(&:first)).to match_array(connection.columns(table).map(&:name))
    end

    declared = content.fetch("foreign_keys")
    actual = tables.flat_map do |table|
      connection.foreign_keys(table).map do |foreign_key|
        column = foreign_key.column.to_s
        {
          "source" => table, "target" => foreign_key.to_table, "column" => column,
          "required" => !connection.columns(table).find { |field| field.name == column }.null,
          "unique" => connection.indexes(table).any? { |index| index.unique && index.columns == [ column ] }
        }
      end
    end
    expect(declared).to match_array(actual)
  end

  it "routes connections without entering any entity" do
    diagrams.each_value do |diagram|
      diagram.relations.each do |relation|
        points = relation.fetch("points")
        expect(points.size).to be >= 2
        points.each_cons(2).with_index do |(from, to), index|
          expect(from[0] == to[0] || from[1] == to[1]).to be(true), "segmento diagonal em #{relation['id']}"
          diagram.nodes.each do |node|
            next if index.zero? && node["id"] == relation["source"]
            next if index == points.size - 2 && node["id"] == relation["target"]

            intersects = if from[1] == to[1]
              from[1] > node["y"] && from[1] < node["y"] + node["height"] &&
                [ from[0], to[0] ].max > node["x"] && [ from[0], to[0] ].min < node["x"] + node["width"]
            else
              from[0] > node["x"] && from[0] < node["x"] + node["width"] &&
                [ from[1], to[1] ].max > node["y"] && [ from[1], to[1] ].min < node["y"] + node["height"]
            end
            expect(intersects).to be(false), "#{relation['id']} atravessa #{node['id']}"
          end
        end
      end
    end
  end

  it "distinguishes optional unique sources, self references and polymorphic links" do
    source = diagrams["social"].relations.find { |relation| relation["column"] == "alert_id" && relation["source"] == "publications" }
    expect(source).to include("source_cardinality" => "0..1", "target_cardinality" => "0..1")
    expect(diagrams["social"].relations).to include(include("source" => "comments", "target" => "comments", "column" => "parent_id"))
    expect(diagrams["infrastructure"].relations).to include(include("kind" => "polymorphic", "source" => "active_storage_attachments"))
    expect(diagrams["infrastructure"].nodes.map { |node| node["table"] }).to include("sessions", "presentation_profiles")
  end

  describe "conceptual model" do
    let(:diagram) { diagrams.fetch("conceptual") }

    it "keeps every concept and relation of the model, with the explanatory note outside the canvas" do
      expect(diagram.nodes.map { |node| node["id"] }).to match_array(%w[role person interactions audit category location alert photo report publication comment])
      expect(diagram.relations.size).to eq(20)
      expect(diagram.notes.join).to include("Dimensões distintas", "Premissas provisórias")
      expect(diagram.relations.find { |relation| relation.values_at("source", "target") == %w[photo alert] }).to include("source_cardinality" => "0..5", "target_cardinality" => "1")
      expect(diagram.relations.find { |relation| relation.values_at("source", "target") == %w[publication alert] }).to include("source_cardinality" => "0..1", "target_cardinality" => "0..1")
    end

    it "gives each connection its own port and labels both multiplicities at the ends" do
      ports = diagram.relations.flat_map { |relation| relation["points"].values_at(0, -1) }
      expect(ports.uniq.size).to eq(ports.size)

      diagram.relations.each do |relation|
        marks = diagram.cardinality_marks(relation)
        expect(marks.map { |mark| mark[:text] }).to eq([ relation["source_cardinality"], relation["target_cardinality"] ])
        expect(marks.map { |mark| [ mark[:x], mark[:y] ] }).to eq(relation["points"].values_at(0, -1))
      end
    end

    it "fits a wide canvas so the slide does not need to scroll at 1920×1080" do
      expect(diagram.height.to_f / diagram.width).to be < 0.45
    end
  end

  it "keeps the physical diagrams on column ports without multiplicity labels" do
    diagrams.except("conceptual").each_value { |diagram| expect(diagram).not_to be_cardinality_labels }
  end
end
