# frozen_string_literal: true

# kettle-jem:freeze
# To retain chunks of comments & code during kettle-jem templating:
# Wrap custom sections with freeze markers (e.g., as above and below this comment chunk).
# kettle-jem will then preserve content between those markers across template runs.
# kettle-jem:unfreeze

# curtail-rb Rakefile v7.1.29 - 2026-10-12
# Ruby 2.3 (Safe Navigation) or higher required
#
# See LICENSE.md for license information.
#
# Copyright (c) 2026 ruby-gtk-project (github.com)
#
# Expected to work in any project that uses Bundler.
#
# Sets up tasks for appraisal2, floss_funding, kettle-jem, kettle-dev, rspec, minitest, rubocop_gradual, reek, yard, and stone_checksums.
#
# rake appraisal:install                      # Install Appraisal gemfiles (initial setup...
# rake appraisal:reset                        # Delete Appraisal lockfiles (gemfiles/*.gemfile.lock)
# rake appraisal:generate                     # Generate Appraisal gemfiles without resolving...
# rake appraisal:update                       # Generate and update Appraisal gemfiles
# rake bench                                  # Run all benchmarks (alias for bench:run)
# rake bench:list                             # List available benchmark scripts
# rake bench:run                              # Run all benchmark scripts (skips on CI)
# rake build:generate_checksums               # Generate both SHA256 & SHA512 checksums i...
# rake bundle:audit:check                     # Checks the Gemfile.lock for insecure depe...
# rake bundle:audit:update                    # Updates the bundler-audit vulnerability d...
# rake ci:act[opt]                            # Run 'act' with a selected workflow
# rake coverage                               # Run specs w/ coverage and open results in...
# rake default                                # Default tasks aggregator
# rake install                                # Build and install curtail-rb-1.0.0.gem in...
# rake install:local                          # Build and install curtail-rb-1.0.0.gem in...
# rake kettle:jem:install                     # Internal target used by `kettle-jem install`
# rake kettle:jem:selftest                    # Self-test: template curtail-rb against itse...
# rake kettle:jem:template                    # Internal target used by scoped `kettle-jem template --only`
# rake reek                                   # Check for code smells
# rake reek:update                            # Run reek and store the output into the RE...
# rake release[remote]                        # Create tag v1.0.0 and build and push kett...
# rake rubocop_gradual                        # Run RuboCop Gradual
# rake rubocop_gradual:autocorrect            # Run RuboCop Gradual with autocorrect (onl...
# rake rubocop_gradual:autocorrect_all        # Run RuboCop Gradual with autocorrect (saf...
# rake rubocop_gradual:check                  # Run RuboCop Gradual to check the lock file
# rake rubocop_gradual:force_update           # Run RuboCop Gradual to force update the l...
# rake rubocop_gradual_debug                  # Run RuboCop Gradual
# rake rubocop_gradual_debug:autocorrect      # Run RuboCop Gradual with autocorrect (onl...
# rake rubocop_gradual_debug:autocorrect_all  # Run RuboCop Gradual with autocorrect (saf...
# rake rubocop_gradual_debug:check            # Run RuboCop Gradual to check the lock file
# rake rubocop_gradual_debug:force_update     # Run RuboCop Gradual to force update the l...
# rake spec                                   # Run RSpec code examples
# rake test                                   # Run tests
# rake yard                                   # Generate YARD Documentation
# rake yard:lint                              # Lint YARD Documentation
#

# simplecov:disable
if !Dir[File.join(__dir__, "*.gemspec")].empty?
  require "bundler/gem_tasks"
end
# simplecov:enable

# Define a base default task early so other files can enhance it.
desc "Default tasks aggregator"
task :default do
  puts "Default task complete."
end

task default: [:test, :lint]

# Without this, a generated docs/ directory makes Rake resolve the bare
# name `docs` as an up-to-date file task, so `rake docs` exits 0 having
# regenerated nothing.
desc "Generate YARD documentation"
task docs: "yard"

# simplecov:disable
### MONOREPO FAMILY TASKS
if Dir.exist?(File.join(__dir__, "gems"))
  def family_gem_dirs
    Dir.glob(
      File.join(
        __dir__,
        "gems",
        "*",
        "*.gemspec",
      ),
    )
      .map { |path| File.dirname(path) }
      .uniq
      .sort_by { |path| File.basename(path) }
  end

  def run_kettle_family(*args)
    sh(
      "bundle",
      "exec",
      "kettle-family",
      *args,
    )
  end

  namespace :family do
    desc "List released Ruby subgems"
    task :list do
      family_gem_dirs.each { |path| puts File.basename(path) }
    end

    desc "Run release readiness checks for the Ruby gem family"
    task :readiness do
      run_kettle_family("check")
    end

    desc "Run tests for the Ruby gem family"
    task :test do
      run_kettle_family("test", "--execute")
    end

    desc "Run lint for the Ruby gem family"
    task :lint do
      run_kettle_family("lint", "--execute")
    end

    desc "Generate YARD docs for the Ruby gem family"
    task :docs do
      run_kettle_family("docs", "--execute")
    end

    desc "Report release state for the Ruby gem family"
    task :release_state do
      run_kettle_family("release-state")
    end

    desc "Run the Ruby gem family release planner"
    task :release do
      run_kettle_family("release")
    end

    desc "Execute the Ruby gem family release"
    task :release_execute do
      run_kettle_family("release", "--execute")
    end
  end
end
# simplecov:enable

# External gems that define tasks - add here!
begin
  require "kettle/dev"
  unless Kettle::Dev::RUNNING_AS == "rake"
    Kettle::Dev.install_tasks
  end
rescue LoadError
  warn("NOTE: kettle-dev isn't installed, or is disabled for #{RUBY_VERSION} in the current environment")
end

### TEMPLATING TASKS
# These tasks are installed for the `kettle-jem` executable. Run full templating
# through `kettle-jem install`; use `kettle-jem template --only PATH` only for
# scoped file updates. The executable prepares the environment and then
# delegates here when rake orchestration is needed.
kettle_jem_selftest_unavailable_note = nil
begin
  require "kettle/jem"
  if Kettle::Jem.respond_to?(:install_tasks)
    Kettle::Jem.install_tasks
  else
    kettle_jem_selftest_unavailable_note = "NOTE: kettle-jem #{Kettle::Jem::Version::VERSION} does not provide rake tasks in this environment"
  end
rescue LoadError
  kettle_jem_selftest_unavailable_note = "NOTE: kettle-jem isn't installed, or is disabled for #{RUBY_VERSION} in the current environment"
end

if kettle_jem_selftest_unavailable_note
  desc("(stub) kettle:jem:selftest is unavailable")
  task("kettle:jem:selftest") do
    warn(kettle_jem_selftest_unavailable_note)
  end
end

### RELEASE TASKS
# Setup stone_checksums
begin
  require "stone_checksums"
rescue LoadError
  desc("(stub) build:generate_checksums is unavailable")
  task("build:generate_checksums") do
    warn("NOTE: stone_checksums isn't installed, or is disabled for #{RUBY_VERSION} in the current environment")
  end
end
require 'rake/testtask'

# The gems derivation's own `rake` binstub runs `Bundler.setup`, which
# leaves this process's env auto-routing every child ruby process this
# Rakefile shells out to — rxgettext and rubocop among them — through
# Bundler too: RUBYOPT auto-requires bundler/setup, and rubygems treats
# BUNDLE_GEMFILE's mere presence the same way even without that. Either
# one resolves against nix/Gemfile, the app's runtime-only bundle, and
# neither rxgettext nor rubocop is in it, so each breaks with "is not
# currently included in the bundle" the moment it's reached. Clearing
# all of this here is the one point that protects every `sh` call below.
ENV.delete('RUBYOPT')
ENV.delete('BUNDLE_GEMFILE')
ENV.delete('BUNDLE_FROZEN')
ENV.delete('BUNDLE_IGNORE_CONFIG')
ENV.delete('BUNDLE_BIN_PATH')
ENV.delete('BUNDLER_SETUP')
ENV.delete('BUNDLER_VERSION')

SCHEMA_DIR = 'tmp/share/glib-2.0/schemas'

desc 'Compile the GSettings schema into tmp/share (on the devshell XDG path)'
task :schema do
  mkdir_p SCHEMA_DIR
  cp 'data/com.github.huluti.Curtail.Rb.gschema.xml', SCHEMA_DIR
  sh 'glib-compile-schemas', SCHEMA_DIR
end

Rake::TestTask.new(test: [:schema, :mo]) do |t|
  t.libs = %w[lib test]
  t.test_files = FileList['test/**/*_test.rb']
  t.warning = false
end

DRIVES = FileList['test/drive_*.rb']

# Four languages with different catalogue coverage: fr and zh_CN are close to
# complete, de is partial, es carries the placeholder subtitle the others
# retired. Between them they exercise translated, partly-translated and
# fallen-back paths.
DRIVE_LANGUAGES = %w[fr es de zh_CN].freeze

# Not `env -u DISPLAY -u WAYLAND_DISPLAY`: this devshell's GTK4 has no
# backend that inits without a real display connection to render against
# offscreen — stripping both leaves `Gtk::InitError: failed to initialize
# GTK` instead of the "no Xvfb needed" headless rendering the ruby-gtk-
# testing skill describes. The devshell banner's `xvfb-run -a` is what
# supplies that connection; these tasks lean on it rather than fight it.
desc 'Run the app headlessly and drive its UI'
task drive: [:schema, :mo, :merge_data] do
  DRIVES.each do |script|
    sh 'ruby', script
  end
end

desc 'Drive the UI in each of a spread of locales'
task i18n: [:schema, :mo, :merge_data] do
  DRIVE_LANGUAGES.each do |lang|
    sh 'env',
      "CURTAIL_TEST_LANG=#{lang}",
      'ruby',
      'test/drive_i18n.rb'
  end
end

# rxgettext, not GNU xgettext: xgettext delegates Ruby to rxgettext anyway and
# then chokes merging its output back. rxgettext knows `_` and `c_` — the
# gettext gem's own names — without being told. It only understands Ruby,
# though, so the three data files in po/POTFILES.in go through
# extract_data_strings.rb instead, and msgcat merges the two results into
# one po/curtail.pot. `--use-first` only matters for the one msgid both
# sides extract ("Compress your images", from both the desktop entry and
# the metainfo) — msgcat keeps that msgid's single empty msgstr either way
# and unions the `#:` location comments regardless of which side wins.
desc 'Regenerate po/curtail.pot from the Ruby sources and the translatable data files'
task :pot do
  sources = File.readlines('po/POTFILES.in')
                .map(&:strip)
                .reject { |line| line.empty? || line.start_with?('#') }

  ruby_sources = sources.select { |source| source.end_with?('.rb') }
  data_sources = sources - ruby_sources

  sh 'rxgettext',
    *ruby_sources,
    '--package-name=curtail',
    '--copyright-holder=Hugo Posnic',
    '--output=po/curtail.ruby.pot'

  require_relative 'po/extract_data_strings'
  CurtailRb::DataStringExtractor.write_pot(data_sources, 'po/curtail.data.pot')

  sh 'msgcat',
    '--use-first',
    'po/curtail.ruby.pot',
    'po/curtail.data.pot',
    '--output=po/curtail.pot'
ensure
  rm_f 'po/curtail.ruby.pot'
  rm_f 'po/curtail.data.pot'
end

desc 'Merge the regenerated template into every catalogue'
task merge: :pot do
  FileList['po/*.po'].each do |catalogue|
    sh 'msgmerge', '--update', '--backup=none', catalogue, 'po/curtail.pot'
  end
end

desc 'Check every shipped catalogue parses as gettext expects'
task :po do
  FileList['po/*.po'].each { |catalogue| sh 'msgfmt', '--check', '-o', '/dev/null', catalogue }
end

LOCALE_DIR = 'tmp/share/locale'

# The GSettings schema's own <summary>/<description> text is translated by
# GLib calling `dgettext("curtail", …)` from C, independently of
# CurtailRb::I18n (which only covers the strings this app's own Ruby calls
# `_()` on) — and dgettext only ever reads a compiled .mo, never a .po. The
# devshell points NLSPATH here (see flake.nix) so that lookup finds these
# without installing anything outside the working tree.
desc 'Compile every po/*.po to a .mo, for GLib\'s own gettext lookups'
task :mo do
  FileList['po/*.po'].each do |catalogue|
    lang = File.basename(catalogue, '.po')
    mo_dir = File.join(LOCALE_DIR, lang, 'LC_MESSAGES')
    mkdir_p mo_dir
    sh 'msgfmt', catalogue, '--output-file', File.join(mo_dir, 'curtail.mo')
  end
end

MERGED_DESKTOP = 'tmp/share/applications/com.github.huluti.Curtail.Rb.desktop'
MERGED_METAINFO = 'tmp/share/metainfo/com.github.huluti.Curtail.Rb.metainfo.xml'

# The equivalent, for the desktop entry and the metainfo, of what Meson's
# i18n.merge_file does at upstream's build time: msgfmt reads the catalogues
# directly (no .mo needed) and writes a copy of each template with a
# Name[xx]=/Comment[xx]= line, or an xml:lang block, added per shipped
# language. flake.nix's package build does the same into $out/share; this
# is that step for the devshell and `rake drive`, onto the same tmp/share
# XDG path `rake schema` already uses.
desc 'Merge translations into the desktop entry and metainfo in tmp/share'
task :merge_data do
  mkdir_p File.dirname(MERGED_DESKTOP)
  sh 'msgfmt',
    '--desktop',
    '--template=data/com.github.huluti.Curtail.Rb.desktop',
    '-d',
    'po',
    '-o',
    MERGED_DESKTOP

  mkdir_p File.dirname(MERGED_METAINFO)
  sh 'msgfmt',
    '--xml',
    '--template=data/com.github.huluti.Curtail.Rb.metainfo.xml',
    '-d',
    'po',
    '-o',
    MERGED_METAINFO
end

desc 'Run rubocop'
task :lint do
  # Not `bundle exec rubocop`: BUNDLE_GEMFILE here is nix/Gemfile, the
  # runtime-only bundle bundlerEnv builds the devshell's gems from, which
  # carries no rubocop and isn't meant to. Rubocop comes from the devshell
  # directly (flake.nix), so a plain `rubocop` is what finds it.
  sh 'rubocop'
end
