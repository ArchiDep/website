module ArchiDep
  MD_GRID_COLS_CLASSES = %w[
    md:grid-cols-2
    md:grid-cols-3
    md:grid-cols-4
    md:grid-cols-5
    md:grid-cols-6
    md:grid-cols-7
    md:grid-cols-8
    md:grid-cols-9
    md:grid-cols-10
    md:grid-cols-11
    md:grid-cols-12
  ]

  class ColsTagBlock < Liquid::Block
    Syntax = /(#{Liquid::QuotedFragment}+)?/

    def initialize(tag_name, markup, tokens)
      @attributes = {}

      @attributes["columns"] = "2"

      # Parse parameters
      if markup =~ Syntax
        markup.scan(Liquid::TagAttributes) do |key, value|
          @attributes[key] = value
        end
      else
        raise SyntaxError.new("Bad options given to 'cols' plugin.")
      end

      if @attributes["columns"] !~ /\A\d+\z/
        raise SyntaxError.new("The 'columns' option must be an integer.")
      end
      @columns = @attributes["columns"].to_i
      if @columns < 2 || @columns > 12
        raise SyntaxError.new("The 'columns' option must be between 2 and 12.")
      end

      super
    end

    def render(context)
      text = super
      texts =
        text
          .split(/(<\!--\s*col(?:umn)?(?:\s+[^"'>]+)?\s*-->)/)
          .select { |t| !t.strip.empty? }
      if texts.first !~ /<\!--\s*col(?:umn)?(?:\s+[^"'>]+)?\s*-->/
        texts.unshift("<!-- col -->")
      end

      inner_html = ""

      texts.each_slice(2) do |tuple|
        col, t = tuple
        m = col.match(/<\!--\s*col(?:umn)?(?:\s+([^"'>]+))?\s*-->/)
        inner_html += m ? "<div class=\"#{m[1]}\">" : "<div>"
        inner_html += ArchiDep::Utils.render_markdown(t, context)
        inner_html += "</div>"
      end

      md_grid_cols_class = MD_GRID_COLS_CLASSES[@columns - 2]

      %|<div class="cols grid grid-cols-1 #{md_grid_cols_class} gap-4">
          #{inner_html}
        </div>|
    end
  end
end

Liquid::Template.register_tag("cols", ArchiDep::ColsTagBlock)
