# Diagramas declarativos; conexões são roteadas pelos corredores entre as entidades.
class PresentationDiagram
  CONTENT_FILE = Rails.root.join("config/presentation/data_diagrams.yml")
  BASE_FONT = 12.0
  HEADER_HEIGHT = 36
  ROW_HEIGHT = 18
  BODY_PADDING = 12

  attr_reader :key, :title, :description, :width, :height, :nodes, :relations, :notes

  def self.load_all
    content = YAML.safe_load_file(CONTENT_FILE)
    content.fetch("diagrams").to_h { |key, definition| [ key, new(key, definition, content) ] }
  end

  def initialize(key, definition, content)
    @key = key
    @title = definition.fetch("title")
    @description = definition.fetch("description")
    @width = definition.fetch("width")
    @height = definition.fetch("height")
    @notes = definition.fetch("notes", [])
    @cardinality_labels = definition["cardinality_labels"] == true
    @nodes = definition.fetch("nodes").map { |node| build_node(node, content.fetch("tables")) }
    @node_index = nodes.index_by { |node| node.fetch("id") }
    validate_layout!

    foreign_keys = content.fetch("foreign_keys").filter_map do |foreign_key|
      source = @node_index[foreign_key.fetch("source")]
      next unless source && !source["reference"] && source["columns"].any? { |column, _| column == foreign_key["column"] }

      foreign_key.merge(
        "kind" => "foreign_key",
        "label" => "#{foreign_key['source']}.#{foreign_key['column']}",
        "source_cardinality" => foreign_key["unique"] ? "0..1" : "0..N",
        "target_cardinality" => foreign_key["required"] ? "1" : "0..1"
      )
    end
    @relations = (foreign_keys + definition.fetch("relations", [])).map do |relation|
      relation.merge("id" => "#{relation.fetch('source')}-#{relation.fetch('column')}-#{relation.fetch('target')}")
    end
    router = Router.new(nodes, relations, width, height, distributed: definition["ports"] == "distributed")
    @relations.each { |relation| relation["points"] = router.route(relation) }
  end

  def node(id)
    @node_index.fetch(id)
  end

  def cardinality_labels? = @cardinality_labels

  # Multiplicidades junto às extremidades: lado de fora da entidade, logo acima da linha.
  def cardinality_marks(relation)
    points = relation.fetch("points")
    [
      [ points[0], points[1], relation["source_cardinality"] ],
      [ points[-1], points[-2], relation["target_cardinality"] ]
    ].filter_map do |(x, y), (next_x, _), text|
      next if text.blank?

      { x: x, y: y, text: text, side: next_x >= x ? "right" : "left" }
    end
  end

  def em(value)
    (value.to_f / BASE_FONT).round(5)
  end

  def segments(relation)
    relation.fetch("points").each_cons(2).map do |from, to|
      {
        x: [ from[0], to[0] ].min, y: [ from[1], to[1] ].min,
        length: (to[0] - from[0]).abs + (to[1] - from[1]).abs,
        vertical: from[0] == to[0]
      }
    end
  end

  private

    def build_node(definition, tables)
      table = definition["table"]
      columns = if table
        available = tables.fetch(table).fetch("columns")
        selected = definition["reference"] ? [ "id" ] : definition["columns"]
        selected ? available.select { |column, _| selected.include?(column) } : available
      else
        []
      end
      lines = definition.fetch("lines", [])
      split = definition.fetch("split", 1)
      rows = ((columns.any? ? columns.size : lines.size) / split.to_f).ceil
      definition.merge(
        "id" => definition["id"] || table, "title" => definition["title"] || table,
        "columns" => columns, "lines" => lines, "split" => split, "rows" => rows,
        "height" => HEADER_HEIGHT + BODY_PADDING + rows * ROW_HEIGHT
      )
    end

    def validate_layout!
      raise ArgumentError, "Entidades repetidas no diagrama #{key}" if @node_index.size != nodes.size

      nodes.each do |node|
        inside = node["x"] >= 0 && node["y"] >= 0 &&
          node["x"] + node["width"] <= width && node["y"] + node["height"] <= height
        raise ArgumentError, "Entidade fora do diagrama #{key}: #{node['id']}" unless inside
      end
      nodes.combination(2).each do |left, right|
        overlap = left["x"] < right["x"] + right["width"] && right["x"] < left["x"] + left["width"] &&
          left["y"] < right["y"] + right["height"] && right["y"] < left["y"] + left["height"]
        raise ArgumentError, "Entidades sobrepostas: #{left['id']} / #{right['id']}" if overlap
      end
    end

  # Caminhos ortogonais evitam atravessar os cartões, inclusive em autorrelações.
  class Router
    STUB = 6
    PADDING = 1.5

    def initialize(nodes, relations, width, height, distributed: false)
      @nodes = nodes.index_by { |node| node.fetch("id") }
      @boxes = nodes.map { |node| [ node["x"], node["y"], node["x"] + node["width"], node["y"] + node["height"] ] }
      @distributed = distributed
      @slots = distributed ? distribute(relations) : {}
      @ports = relations.to_h { |relation| [ relation.fetch("id"), ports(relation) ] }
      all_ports = @ports.values.flatten(1)
      @xs = ([ 8, width - 8 ] + @boxes.flat_map { |box| [ box[0] - STUB, box[2] + STUB ] } +
        all_ports.map { |point| point[0] }).uniq.sort
      @ys = ([ 8, height - 8 ] + @boxes.flat_map { |box| [ box[1] - STUB, box[3] + STUB ] } +
        all_ports.map { |point| point[1] }).uniq.sort
      @neighbors = {}
      @clear = {}
    end

    def route(relation)
      start, finish, source_edge, target_edge = @ports.fetch(relation.fetch("id"))
      source = index(start)
      target = index(finish)
      queue = []
      initial = [ source, nil ]
      best = { initial => 0 }
      previous = {}
      visited = {}
      push(queue, [ distance(start, finish), initial ])
      terminal = nil

      until queue.empty?
        _, state = pop(queue)
        next if visited[state]

        visited[state] = true
        point_index, direction = state
        if point_index == target
          terminal = state
          break
        end
        neighbors(point_index).each do |neighbor, axis, length|
          next_state = [ neighbor, axis ]
          cost = best.fetch(state) + length + (direction && direction != axis ? 4 : 0)
          next if cost >= best.fetch(next_state, Float::INFINITY)

          best[next_state] = cost
          previous[next_state] = state
          push(queue, [ cost + distance(point(neighbor), finish), next_state ])
        end
      end
      raise ArgumentError, "Sem corredor para #{relation['id']}" unless terminal

      path = []
      while terminal
        path.unshift(point(terminal[0]))
        terminal = previous[terminal]
      end
      compact([ source_edge, *path, target_edge ])
    end

    private

      def sides(relation)
        source = @nodes.fetch(relation.fetch("source"))
        target = @nodes.fetch(relation.fetch("target"))
        to_right = source["id"] == target["id"] || target["x"] + target["width"] / 2.0 > source["x"] + source["width"] / 2.0
        source_side = to_right ? 1 : -1
        stacked = @distributed && (target["x"] + target["width"] / 2.0 - source["x"] - source["width"] / 2.0).abs < 1
        # Entidades empilhadas na mesma coluna se ligam pelo mesmo lado, sem cruzar o diagrama.
        target_side = source["id"] == target["id"] || stacked ? source_side : -source_side
        [ source, target, source_side, target_side ]
      end

      # Cada extremidade ganha uma altura própria na lateral da entidade, ordenada pela posição
      # da outra ponta; assim as linhas não se sobrepõem na porta nem nas multiplicidades.
      def distribute(relations)
        ends = relations.flat_map do |relation|
          source, target, source_side, target_side = sides(relation)
          [ [ relation["id"], :source, source, source_side, target ], [ relation["id"], :target, target, target_side, source ] ]
        end
        ends.group_by { |_, _, node, side, _| [ node["id"], side ] }.each_with_object({}) do |(_, group), slots|
          node = group.first[2]
          ordered = group.sort_by { |id, role, _, _, other| [ other["y"] + other["height"] / 2.0, role == :source ? 0 : 1, id ] }
          step = (node["height"] - HEADER_HEIGHT) / ordered.size.to_f
          ordered.each_with_index do |(id, role, *), index|
            slots[[ id, role ]] = (node["y"] + HEADER_HEIGHT + step * (index + 0.5)).round(2)
          end
        end
      end

      def ports(relation)
        source, target, source_side, target_side = sides(relation)
        source_edge = edge(source, source_side, relation["column"], @slots[[ relation["id"], :source ]])
        target_edge = edge(target, target_side, "id", @slots[[ relation["id"], :target ]])
        [
          [ source_edge[0] + source_side * STUB, source_edge[1] ],
          [ target_edge[0] + target_side * STUB, target_edge[1] ],
          source_edge, target_edge
        ]
      end

      def edge(node, side, column, slot = nil)
        column_index = node["columns"].index { |name, _| name == column }
        y = if slot
          slot
        elsif column_index
          node["y"] + HEADER_HEIGHT + BODY_PADDING / 2.0 + (column_index % node["rows"] + 0.5) * ROW_HEIGHT
        else
          node["y"] + HEADER_HEIGHT / 2.0
        end
        [ node["x"] + (side == 1 ? node["width"] : 0), y ]
      end

      def index(point)
        @ys.index(point[1]) * @xs.size + @xs.index(point[0])
      end

      def point(index)
        [ @xs[index % @xs.size], @ys[index / @xs.size] ]
      end

      def neighbors(index)
        @neighbors[index] ||= begin
          x = index % @xs.size
          y = index / @xs.size
          candidates = []
          candidates << [ index - 1, :horizontal ] if x.positive?
          candidates << [ index + 1, :horizontal ] if x < @xs.size - 1
          candidates << [ index - @xs.size, :vertical ] if y.positive?
          candidates << [ index + @xs.size, :vertical ] if y < @ys.size - 1
          candidates.filter_map do |neighbor, axis|
            from = point(index)
            to = point(neighbor)
            next unless clear?(from, to)

            [ neighbor, axis, distance(from, to) ]
          end
        end
      end

      def clear?(from, to)
        @clear[[ from, to ]] ||= @boxes.none? do |left, top, right, bottom|
          if from[1] == to[1]
            from[1] > top - PADDING && from[1] < bottom + PADDING &&
              [ from[0], to[0] ].max > left - PADDING && [ from[0], to[0] ].min < right + PADDING
          else
            from[0] > left - PADDING && from[0] < right + PADDING &&
              [ from[1], to[1] ].max > top - PADDING && [ from[1], to[1] ].min < bottom + PADDING
          end
        end
      end

      def distance(left, right)
        (left[0] - right[0]).abs + (left[1] - right[1]).abs
      end

      def compact(path)
        path.each_with_object([]) do |point, result|
          next if point == result.last
          if result.size >= 2
            before, last = result.last(2)
            result.pop if (before[0] == last[0] && last[0] == point[0]) ||
              (before[1] == last[1] && last[1] == point[1])
          end
          result << point
        end
      end

      def push(heap, entry)
        heap << entry
        index = heap.size - 1
        while index.positive?
          parent = (index - 1) / 2
          break if heap[parent][0] <= entry[0]

          heap[index] = heap[parent]
          index = parent
        end
        heap[index] = entry
      end

      def pop(heap)
        first = heap.first
        last = heap.pop
        return first if heap.empty?

        index = 0
        while (child = index * 2 + 1) < heap.size
          child += 1 if child + 1 < heap.size && heap[child + 1][0] < heap[child][0]
          break if last[0] <= heap[child][0]

          heap[index] = heap[child]
          index = child
        end
        heap[index] = last
        first
      end
  end
end
