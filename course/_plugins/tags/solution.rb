module ArchiDep
  class SolutionTagBlock < Liquid::Block
    Syntax = /(#{Liquid::QuotedFragment}+)?/

    def initialize(tag_name, markup, tokens)
      @attributes = {}

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

      %|<div class="solution collapse screen:collapse-arrow print:collapse-open border border-neutral hover:bg-primary/25">
          <input type="checkbox" />
          <div class="collapse-title font-semibold">
            <div class="flex items-center gap-2">
              :key:
              <span>Solution</span>
            </div>
          </div>
          <div class="collapse-content">
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

Liquid::Template.register_tag("solution", ArchiDep::SolutionTagBlock)
