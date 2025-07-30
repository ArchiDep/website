module ArchiDep
  class NoteTagBlock < Liquid::Block
    Syntax = /(#{Liquid::TagAttributes})?/

    def initialize(tag_name, markup, tokens)
      @attributes = {}

      @attributes["type"] = "info"
      @attributes["title"] = ""

      # Parse parameters
      if markup =~ Syntax
        markup.scan(Liquid::TagAttributes) do |key, value|
          @attributes[key] = value
        end
      else
        raise SyntaxError.new("Bad options given to 'solution' plugin.")
      end

      super
    end

    def render(context)
      text = super

      type = @attributes["type"]
      icon =
        case type
        when "advanced"
          ":space_invader:"
        when "info"
          render_icon("info-circle", context)
        when "more"
          ":books:"
        when "tip"
          ":gem:"
        when "troubleshooting"
          ":boom:"
        when "warning"
          render_icon("exclamation-triangle", context)
        else
          raise SyntaxError.new("Unknown note type: #{type}")
        end

      title = @attributes["title"]
      title = title.strip unless title.nil?
      if title.nil? or title.empty?
        title =
          case type
          when "advanced"
            "Advanced"
          when "info"
            "Note"
          when "more"
            "More information"
          when "tip"
            "Tip"
          when "troubleshooting"
            "Troubleshooting"
          when "warning"
            "Warning"
          end
      else
        title = title.sub(/^["']/, "").sub(/["']$/, "")
      end

      markdown = ArchiDep::Utils.render_markdown(text, context)

      %|<div class="note note-#{type}">
          <div class="title">
            #{icon}
            <span>#{title}</span>
          </div>
          <div class="content">
            #{markdown}
          </div>
        </div>|
    end

    private

    def render_icon(name, context)
      ArchiDep::Utils.render_icon(name, context)
    end
  end
end

Liquid::Template.register_tag("note", ArchiDep::NoteTagBlock)
