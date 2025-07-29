module ArchiDep
  class CalloutTagBlock < Liquid::Block
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
        raise SyntaxError.new("Bad options given to 'callout' plugin.")
      end

      super
    end

    def render(context)
      text = super

      callout_theme_class = "callout-#{@attributes["type"]}"
      callout_class = "callout #{callout_theme_class}"

      %|<div class="#{callout_class}">
        <svg class="icon" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor">
          <path fill-rule="evenodd" d="M9.401 3.003c1.155-2 4.043-2 5.197 0l7.355 12.748c1.154 2-.29 4.5-2.599 4.5H4.645c-2.309 0-3.752-2.5-2.598-4.5L9.4 3.003ZM12 8.25a.75.75 0 0 1 .75.75v3.75a.75.75 0 0 1-1.5 0V9a.75.75 0 0 1 .75-.75Zm0 8.25a.75.75 0 1 0 0-1.5.75.75 0 0 0 0 1.5Z" clip-rule="evenodd" />
        </svg>

        <div class="content">
          #{
        context.registers[:site].find_converter_instance(
          Jekyll::Converters::Markdown
        ).convert(text)
      }
        </div>
      </div>|
    end
  end
end

Liquid::Template.register_tag("callout", ArchiDep::CalloutTagBlock)
