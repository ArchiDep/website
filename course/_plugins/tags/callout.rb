module ArchiDep
  class CalloutTagBlock < Liquid::Block
    SYNTAX = /(#{Liquid::TagAttributes})?/
    TYPES = %w[danger warning]

    def initialize(tag_name, markup, tokens)
      @attributes = {}

      @attributes["type"] = "danger"

      # Parse parameters
      if markup =~ SYNTAX
        markup.scan(Liquid::TagAttributes) do |key, value|
          @attributes[key] = value
        end
      else
        raise SyntaxError.new("Bad options given to 'callout' plugin.")
      end

      @type = @attributes["type"]
      unless TYPES.include?(@type)
        raise SyntaxError.new("Unknown callout type: #{@type}")
      end

      @icon =
        case @type
        when "danger"
          "exclamation-circle"
        when "warning"
          "exclamation-triangle"
        else
          raise SyntaxError.new("Unknown callout type: #{@type}")
        end

      @animate = @attributes["animate"] == "true"

      super
    end

    def render(context)
      text = super

      callout_class = "callout callout-#{@type}"
      callout_class += " animate" if @animate
      icon_html = render_icon(@icon, context, class: "icon")
      markdown = ArchiDep::Utils.render_markdown(text, context)

      %|<div class="#{callout_class}">
          #{icon_html}

          <div class="content">
            #{markdown}
          </div>
        </div>|
    end

    private

    def render_icon(name, context, options = {})
      ArchiDep::Utils.render_icon(name, context, options)
    end
  end
end

Liquid::Template.register_tag("callout", ArchiDep::CalloutTagBlock)
