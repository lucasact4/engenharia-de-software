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
end
