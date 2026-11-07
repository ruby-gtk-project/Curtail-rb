# frozen_string_literal: true

# rxgettext (the Ruby gettext extractor `rake pot` drives for the sources in
# po/POTFILES.in) only understands Ruby. xgettext itself needs a different
# frontend per format for the rest of POTFILES.in — intltool-extract for the
# desktop entry and the GSettings schema, itstool for the AppStream metainfo
# — and none of those ship as Ruby-reachable gems here. This is that missing
# frontend: a small, format-specific scanner for exactly the three data files
# POTFILES.in lists, each simple and fixed enough in shape that a full XML/
# desktop-entry parser would be more machinery than the job needs.
#
# It mirrors what intltool-extract/itstool actually pull out of each format:
#   - the .desktop entry's Name, Comment and Keywords values (never Icon,
#     Exec or any other key — those are never translatable);
#   - every <summary> and <description> text in the GSettings schema;
#   - the AppStream metainfo's top-level <summary> and the <p> paragraphs
#     inside its <description> (never a `translate="no"` element, such as
#     <name> or <developer><name>).
#
# `write_pot` renders the result as gettext .pot entries so `rake pot` can
# `msgcat` them together with rxgettext's Ruby-sourced output into one
# po/curtail.pot.
module CurtailRb
  module DataStringExtractor
    Entry = Struct.new(:msgid, :locations, :comment)

    module_function

    # sources: the data file paths, as listed in po/POTFILES.in.
    def extract(sources)
      sources.flat_map do |path|
        case File.basename(path)
        when /\.desktop\z/ then extract_desktop(path)
        when /\.gschema\.xml\z/ then extract_gschema(path)
        when /\.metainfo\.xml\z/ then extract_metainfo(path)
        else raise "no data-string extractor for #{path}"
        end
      end
    end

    def write_pot(sources, output_path)
      File.write(output_path, render(deduplicate(extract(sources))))
    end

    def render(entries)
      entries.map { |entry| render_entry(entry) }.join("\n")
    end

    # The same string can be marked up in more than one data file — the
    # desktop entry's Comment and the metainfo's summary are both "Compress
    # your images" — and a .pot, unlike rxgettext's own output, is not
    # allowed to repeat a msgid: msgcat (which `rake pot` merges this
    # against) treats that as a fatal error rather than quietly unioning
    # it. This does that union itself, by msgid, keeping each one's first
    # comment and merging every entry's locations onto it in file order.
    def deduplicate(entries)
      entries.each_with_object({}) do |entry, by_msgid|
        existing = by_msgid[entry.msgid]

        if existing
          existing.locations.concat(entry.locations)
        else
          by_msgid[entry.msgid] = entry.dup.tap { |copy| copy.locations = entry.locations.dup }
        end
      end.values
    end

    def render_entry(entry)
      String.new.tap do |out|
        if entry.comment
          out << "#. #{entry.comment}\n"
        end
        out << "#: #{entry.locations.join(' ')}\n"
        out << "msgid #{pot_quote(entry.msgid)}\n"
        out << "msgstr \"\"\n"
      end
    end

    # gettext's own escaping for a msgid string.
    def pot_quote(text)
      escaped = text.gsub('\\', '\\\\\\\\').gsub('"', '\\"')
      "\"#{escaped}\""
    end

    # Translatable desktop-entry keys, per the Desktop Entry Specification —
    # Icon, Exec and the rest are never localised.
    TRANSLATABLE_DESKTOP_KEYS = %w[Name GenericName Comment Keywords].freeze
    DESKTOP_KEY_LINE = /\A(#{TRANSLATABLE_DESKTOP_KEYS.join('|')})=(.*)\z/

    def extract_desktop(path)
      comment = nil

      File.readlines(path, encoding: 'UTF-8').each_with_index.filter_map do |raw_line, index|
        line = raw_line.chomp
        case line
        when /\A#\s*(.+?)\s*\z/
          comment = Regexp.last_match(1)
          nil
        when DESKTOP_KEY_LINE
          value = Regexp.last_match(2)
          entry = Entry.new(value, ["#{path}:#{index + 1}"], comment)
          comment = nil
          entry
        else
          comment = nil
          nil
        end
      end
    end

    # The schema's only translatable elements are each key's <summary> and
    # <description>, and in this schema both are always single-line.
    def extract_gschema(path)
      File.readlines(path, encoding: 'UTF-8').each_with_index.filter_map do |line, index|
        match = line.match(%r{\A\s*<(summary|description)>(.*)</\1>\s*\z})

        if match
          Entry.new(match[2], ["#{path}:#{index + 1}"], nil)
        end
      end
    end

    # The metainfo's translatable text is the top-level <summary> and each
    # <p> paragraph inside <description> — never a `translate="no"` element,
    # such as <name> or <developer><name>, and never anything inside
    # <releases>, whose own text is marked `translate="no"` too.
    #
    # A <p> here is written across several lines, with its leading `>`
    # pushed onto its own continuation line to keep rubocop/qlty happy about
    # trailing whitespace, so this is a small state machine rather than a
    # single-line regex like the schema's.
    def extract_metainfo(path)
      state = { in_description: false, paragraph_start: nil, paragraph_lines: nil }

      [].tap do |entries|
        File.readlines(path, encoding: 'UTF-8').each_with_index do |raw_line, index|
          consume_metainfo_line(
            entries,
            state,
            path,
            raw_line.chomp,
            index + 1,
          )
        end
      end
    end

    def consume_metainfo_line(entries, state, path, line, lineno)
      case line
      when %r{\A\s*<summary>(.*)</summary>\s*\z}
        entries << Entry.new(Regexp.last_match(1), ["#{path}:#{lineno}"], nil)
      when %r{\A\s*<description>\s*\z}
        state[:in_description] = true
      when %r{\A\s*</description>\s*\z}
        state[:in_description] = false
      when /\A\s*<p\s*\z/
        if state[:in_description]
          state[:paragraph_start] = lineno
          state[:paragraph_lines] = []
        end
      else
        if state[:in_description] && state[:paragraph_lines]
          consume_metainfo_paragraph_line(
            entries,
            state,
            path,
            line,
          )
        end
      end
    end

    def consume_metainfo_paragraph_line(entries, state, path, line)
      if line.include?('</p>')
        state[:paragraph_lines] << line.sub('</p>', '')
        entries << Entry.new(
          normalize_paragraph(state[:paragraph_lines].join(' ')),
          ["#{path}:#{state[:paragraph_start]}"],
          nil,
        )
        state[:paragraph_lines] = nil
      else
        state[:paragraph_lines] << line
      end
    end

    def normalize_paragraph(text)
      text.sub(/\A\s*>/, '').gsub(/\s+/, ' ').strip
    end
  end
end
