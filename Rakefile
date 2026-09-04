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

desc 'Run the app headlessly and drive its UI'
task drive: :schema do
  DRIVES.each do |script|
    sh 'env', '-u', 'DISPLAY', '-u', 'WAYLAND_DISPLAY', 'ruby', script
  end
end

desc 'Run rubocop'
task :lint do
  sh 'bundle exec rubocop'
end

task default: %i[test drive lint]
