module ArchiDep
  class Generator < Jekyll::Generator
    def generate(site)
      course_docs = site.collections["course"].docs

      progress_docs = site.collections["progress"].docs
      done_chapters = progress_docs.flat_map { |doc| doc.data["done"] || [] }
      due_chapters =
        progress_docs
          .flat_map { |doc| doc.data["due"] || [] }
          .reject { |ch| done_chapters.include?(ch) }
      next_chapters =
        progress_docs
          .flat_map { |doc| doc.data["next"] || [] }
          .reject do |ch|
            done_chapters.include?(ch) || due_chapters.include?(ch)
          end

      course_docs.each do |item|
        m =
          %r{/([1-9])(\d\d)-([^/]+)/(exercise.md|slides.md|slides/slides.md|subject.md)\z}.match(
            item.path
          )
        throw %/Invalid filename format for item: "#{item.path}"/ unless m

        section = Integer(m[1])
        section_chapter = Integer(m[2])
        slug = m[3]
        course_type =
          if m[4] == "slides/slides.md"
            "slides"
          else
            m[4].sub(/\.md\z/, "")
          end

        item.data["section"] = section
        item.data["section_chapter"] = section_chapter

        chapter_num = section * 100 + section_chapter
        item.data["num"] = chapter_num
        item.data["progress"] = case chapter_num
        when *done_chapters
          "done"
        when *due_chapters
          "due"
        when *next_chapters
          "next"
        else
          "future"
        end

        base_permalink = "/course/#{chapter_num}-#{slug}/"
        item.data["permalink"] = if course_type == "slides"
          "#{base_permalink}/slides/"
        else
          base_permalink
        end

        item.data["course_type"] = course_type
        item.data["layout"] = course_type
        item.data["toc"] = course_type == "exercise" || course_type == "subject"

        if course_type == "slides"
          link_references =
            item
              .content
              .split("\n")
              .reverse
              .map { |line| line.strip }
              .reject { |line| line.empty? }
              .take_while { |line| line.match?(/\A\[[^\]]+\]: ?.+\z/) }
              .map do |line|
                m = line.match(/\A\[([^\]]+)\]: ?(.+)\z/)
                {reference: m[1], url: m[2]}
              end
              .reverse
          unless link_references.empty?
            item.content = link_references.reduce(item.content) do |content, link_reference|
              content.gsub(
                /\]\[#{link_reference[:reference]}\]/,
                "](#{link_reference[:url]})"
              )
            end
          end
        end
      end

      course_docs.each do |doc|
        if doc.data["course_type"] == "subject"
          num = doc.data["num"]
          slides_doc =
            course_docs.filter do |item|
              item.data["num"] == num && item.data["course_type"] == "slides"
            end
          if slides_doc.length >= 2
            raise "Multiple slides documents found for subject #{num}"
          elsif slides_doc.length == 1
            doc.data["slides"] = slides_doc[0]
            slides_doc[0].data["subject"] = doc
          end
        end
      end

      sections = site.data["course"]["sections"]
      sections.each_with_index do |section, i|
        # Attach the items in section to the section
        section_docs =
          course_docs.select { |item| item.data["section"] == i + 1 }
        section["items"] = section_docs.reject do |item|
          item.data["course_type"] == "slides" &&
            course_docs.any? do |subject|
              subject.data["course_type"] == "subject" &&
                subject.data["num"] == item.data["num"]
            end
        end

        section_num = (i + 1) * 100
        section["num"] = section_num
        section["progress"] = case section_num
        when *done_chapters
          "done"
        end
      end

      home_page_doc = site.pages.find { |doc| doc.data["layout"] == "home" }

      last_done =
        progress_docs
          .reverse
          .find { |doc| doc.data["done"] }
          &.data
          &.[]("done") || []
      previous_chapters =
        course_docs.select do |doc|
          doc.data["course_type"] == "subject" &&
            last_done.include?(doc.data["num"])
        end
      home_page_doc.data["previous_chapters"] = previous_chapters

      last_due =
        progress_docs.reverse.find { |doc| doc.data["due"] }&.data&.[]("due") ||
          []
      next_due_exercises =
        course_docs.select do |doc|
          doc.data["course_type"] == "exercise" &&
            last_due.include?(doc.data["num"])
        end
      home_page_doc.data["next_due_exercises"] = next_due_exercises

      next_chapter_nums =
        progress_docs
          .reverse
          .find { |doc| doc.data["next"] }
          &.data
          &.[]("next") || []
      next_chapters =
        course_docs.select do |doc|
          doc.data["subject"] == nil &&
            next_chapter_nums.include?(doc.data["num"])
        end
      home_page_doc.data["next_chapters"] = next_chapters

      site.pages << JsonPage.new(
        site,
        {
          "sections" =>
            site.data["course"]["sections"].each_with_index.map do |section, i|
              {
                "title" => section["title"],
                "num" => section["num"],
                "progress" => section["progress"],
                "docs" =>
                  section["items"].map do |item|
                    item
                      .data
                      .merge({ "url" => item.url })
                      .select do |k, v|
                        %w[
                          course_type
                          num
                          progress
                          section
                          section_chapter
                          slides
                          title
                          url
                        ].include?(k)
                      end
                  end
              }
            end
        }
      )

      # Prototype for adding digest to static files
      # site.static_files.each do |file|
      #   dests = file.instance_variable_get(:@destination) || {}
      #   dests[site.dest] = "#{file.destination(site.dest)}.test"
      #   file.instance_variable_set(:@destination, dests)
      # end
    end
  end

  class JsonPage < Jekyll::Page
    def initialize(site, data)
      @site = site
      @base = site.source
      @dir = "/"
      @content = JSON.pretty_generate(data)
      @data = {}

      # All pages have the same filename, so define attributes straight away.
      @basename = "archidep"
      @ext = ".json"
      @name = "archidep.json"
    end
  end
end

Jekyll::Hooks.register :documents, :pre_render do |doc, payload|
  return unless /\.md$/.match(doc.basename)

  # make some local variables for convenience
  site = doc.site
  liquid_options = site.config["liquid"]

  # create a template object
  template = site.liquid_renderer.file(doc.path).parse(doc.content)

  # the render method expects this information
  info = {
    registers: {
      site: site,
      page: payload["page"]
    },
    strict_filters: liquid_options["strict_filters"],
    strict_variables: liquid_options["strict_variables"]
  }

  # render the content into a new property
  doc.data["raw_markdown"] = template.render!(payload, info)
end
