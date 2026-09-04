# frozen_string_literal: true

require_relative 'paths'

module CurtailRb
  # Upstream links against gettext. There is no gettext binding in the Ruby
  # GTK stack — GLib::GetText exposes only bindtextdomain, and its `_` mixin
  # needs the gettext gem, which is not in the dependency set — so this reads
  # the same `po/*.po` files upstream ships, directly. That also means no
  # msgfmt step: the catalogue the translators wrote is the catalogue that
  # ships.
  #
  # Lookups fall back to the untranslated string, which is what gettext does
  # and what upstream itself relies on: its .pot is stale against its own
  # sources in a dozen places, so several strings show in English everywhere.
  module I18n
    # gettext keys a contextual message as "contextmsgid".
    CONTEXT_SEPARATOR = ""

    module_function

    # Translate, falling back to the untranslated string. Named `_` so call
    # sites read the way gettext's do.
    def _(text)
      catalogue.fetch(text, text)
    end

    # Upstream's C_() form: the same message, disambiguated by context, used
    # for the shortcuts dialog where "General" and "Preferences" may need
    # different translations from the same words elsewhere. Named `p_` because
    # that is what rxgettext recognises, so these strings land in the template
    # without the extractor needing to be told about them.
    def p_(context, text)
      catalogue.fetch("#{context}#{CONTEXT_SEPARATOR}#{text}", text)
    end

    # gettext's "extract now, translate later" marker: it returns the string
    # untouched, and exists so a literal sitting in a constant is still visible
    # to the extractor. The `_()` at the point of use does the actual lookup.
    # Capital N_ because that is the name gettext reserves for it — a lowercase
    # `n_` means ngettext, and rxgettext would demand a plural form.
    def N_(text) = text


    def catalogue = @catalogue ||= load_catalogue

    # Reset between tests, or after changing the environment.
    def reset!
      @catalogue = nil
      @language = nil
    end

    # The first locale from the environment that we actually ship a catalogue
    # for. `C` and `POSIX` mean "no translation", so they resolve to nothing.
    def language
      @language ||= candidates.find { |lang| linguas.include?(lang) }
    end

    # Each locale contributes both its full form and its bare language, so a
    # `pt_PT` desktop still finds `pt` when `pt_PT.po` is not shipped.
    def candidates
      locales.flat_map { |locale| [locale, locale.split('_').first] }
             .reject { |lang| %w[C POSIX].include?(lang) }
             .uniq
    end

    def locales
      %w[LANGUAGE LC_ALL LC_MESSAGES LANG]
        .filter_map { |var| ENV.fetch(var, nil) }
        .reject(&:empty?)
        .flat_map { |value| value.split(':') }
        .map { |value| value.split(/[.@]/).first }
    end

    # The languages upstream ships, read from the same LINGUAS file its build
    # reads, so adding a catalogue is dropping in the .po and one line there.
    def linguas
      @linguas ||= File.readlines(
        File.join(Paths.po_dir, 'LINGUAS'),
        encoding: 'UTF-8',
      )
                       .map(&:strip)
                       .reject { |line| line.empty? || line.start_with?('#') }
    end

    def po_path(lang) = File.join(Paths.po_dir, "#{lang}.po")

    # A catalogue that cannot be read is not worth taking the app down for —
    # English is a working fallback, a crashed launch is not.
    def load_catalogue
      case language
      when nil then {}
      else parse_po(po_path(language))
      end
    rescue StandardError => e
      warn("Could not load the #{language} catalogue: #{e.message}")
      {}
    end

    # A deliberately small PO parser: msgctxt/msgid/msgstr with continuation
    # lines. There are no plurals in this catalogue, and fuzzy entries are
    # dropped the way gettext drops them.
    def parse_po(path)
      {}.tap do |catalogue|
        entry = new_entry

        # PO files are UTF-8 regardless of the runtime locale. Without this,
        # a process started under LC_ALL=C reads them as US-ASCII and the
        # first accented character raises from the regexes below.
        File.foreach(path, encoding: 'UTF-8') do |line|
          entry = consume(catalogue, entry, line.chomp)
        end

        store(catalogue, entry)
      end
    end

    def new_entry
      { msgctxt: nil, msgid: +'', msgstr: +'', field: nil, fuzzy: false }
    end

    def consume(catalogue, entry, line)
      case line
      when /\A#,.*\bfuzzy\b/ then entry.merge(fuzzy: true)
      when /\A#/ then entry
      when /\A\s*\z/
        store(catalogue, entry)
        new_entry
      when /\Amsgctxt\s+"(.*)"\z/
        start_entry(catalogue, entry).merge(
          field:   :msgctxt,
          msgctxt: unescape(Regexp.last_match(1)),
        )
      when /\Amsgid\s+"(.*)"\z/
        start_entry(catalogue, entry).merge(
          field: :msgid,
          msgid: unescape(Regexp.last_match(1)),
        )
      when /\Amsgstr\s+"(.*)"\z/
        entry.merge(field: :msgstr, msgstr: unescape(Regexp.last_match(1)))
      when /\A"(.*)"\z/ then append(entry, Regexp.last_match(1))
      else entry
      end
    end

    # A bare msgctxt or msgid after a completed pair starts the next entry,
    # since PO files are not required to separate entries with a blank line.
    # msgctxt always comes first, so it must not clobber a msgid mid-entry.
    def start_entry(catalogue, entry)
      case entry[:field]
      when :msgstr
        store(catalogue, entry)
        new_entry
      else entry
      end
    end

    def append(entry, text)
      case entry[:field]
      when nil then entry
      else entry.merge(entry[:field] => entry[entry[:field]] + unescape(text))
      end
    end

    def store(catalogue, entry)
      usable = !entry[:fuzzy] && !entry[:msgid].empty? &&
               !entry[:msgstr].empty?

      case usable
      when true then catalogue[key_for(entry)] = entry[:msgstr]
      end
    end

    def key_for(entry)
      case entry[:msgctxt]
      when nil then entry[:msgid]
      else "#{entry[:msgctxt]}#{CONTEXT_SEPARATOR}#{entry[:msgid]}"
      end
    end

    def unescape(text)
      text.gsub(/\\(.)/) do
        case Regexp.last_match(1)
        when 'n' then "\n"
        when 't' then "\t"
        else Regexp.last_match(1)
        end
      end
    end
  end
end
