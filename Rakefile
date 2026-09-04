# frozen_string_literal: true

require 'rake/testtask'

SCHEMA_DIR = 'tmp/share/glib-2.0/schemas'

desc 'Compile the GSettings schema into tmp/share (on the devshell XDG path)'
task :schema do
  mkdir_p SCHEMA_DIR
  cp 'data/com.github.huluti.Curtail.Rb.gschema.xml', SCHEMA_DIR
  sh 'glib-compile-schemas', SCHEMA_DIR
end

Rake::TestTask.new(test: :schema) do |t|
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

desc 'Run the app headlessly and drive its UI'
task drive: :schema do
  DRIVES.each do |script|
    sh 'env', '-u', 'DISPLAY', '-u', 'WAYLAND_DISPLAY', 'ruby', script
  end
end

desc 'Drive the UI in each of a spread of locales'
task i18n: :schema do
  DRIVE_LANGUAGES.each do |lang|
    sh 'env',
      '-u',
      'DISPLAY',
      '-u',
      'WAYLAND_DISPLAY',
      "CURTAIL_TEST_LANG=#{lang}",
      'ruby',
      'test/drive_i18n.rb'
  end
end

# rxgettext, not GNU xgettext: xgettext delegates Ruby to rxgettext anyway and
# then chokes merging its output back. rxgettext knows `_` and `c_` — the
# gettext gem's own names — without being told.
desc 'Regenerate po/curtail.pot from the Ruby sources'
task :pot do
  sources = File.readlines('po/POTFILES.in')
                .map(&:strip)
                .reject { |line| line.empty? || line.start_with?('#') }

  sh 'rxgettext',
    *sources,
    '--package-name=curtail',
    '--copyright-holder=Hugo Posnic',
    '--output=po/curtail.pot'
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

desc 'Run rubocop'
task :lint do
  sh 'bundle exec rubocop'
end

task default: %i[test drive i18n po lint]
