module ArchiDep
  class MarkdownTagBlock < Liquid::Block
    Syntax = /(#{Liquid::QuotedFragment}+)?/

    def initialize(tag_name, markup, tokens)
      @attributes = {}

      @attributes["type"] = ""

      # Parse parameters
      if markup =~ Syntax
        markup.scan(Liquid::TagAttributes) do |key, value|
          @attributes[key] = value
        end
      else
        raise SyntaxError.new("Bad options given to 'markdown' plugin.")
      end

      super
    end

    def render(context)
      text = super
      markdown = ArchiDep::Utils.render_markdown(text, context)

      %|<div class="markdown">
          #{markdown}
        </div>|
    end
  end
end

Liquid::Template.register_tag("markdown", ArchiDep::MarkdownTagBlock)
