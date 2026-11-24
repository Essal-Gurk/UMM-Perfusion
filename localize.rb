require 'csv'
require 'fileutils'
require 'json'

# Pipe-separated UTF-8 keeps all translations for a key on one line.
base_languages = %w[en fr de es it pt ja zh-Hans]
extra_languages = %w[tr ar]
languages = base_languages + extra_languages
rows = CSV.read('Translations.psv', col_sep: '|', headers: true, encoding: 'UTF-8')
abort 'Unexpected translation columns' unless rows.headers == ['key', *base_languages]
catalog = {}
rows.each do |row|
  key = row['key']
  abort "Missing or duplicate key: #{key}" if key.nil? || key.empty? || catalog.key?(key)
  catalog[key] = base_languages.to_h do |locale|
    value = row[locale]
    abort "Missing translation: #{key} (#{locale})" if value.nil? || value.strip.empty?
    [locale, value]
  end
end
extra_rows = CSV.read('Translations-extra.psv', col_sep: '|', headers: true, encoding: 'UTF-8')
abort 'Unexpected additional translation columns' unless extra_rows.headers == ['key', *extra_languages]
seen = []
extra_rows.each do |row|
  key = row['key']
  abort "Unknown or duplicate additional key: #{key}" unless catalog.key?(key) && !seen.include?(key)
  seen << key
  extra_languages.each do |locale|
    value = row[locale]
    abort "Missing translation: #{key} (#{locale})" if value.nil? || value.strip.empty?
    catalog.fetch(key)[locale] = value
  end
end
abort "Missing additional translations: #{(catalog.keys - seen).join(', ')}" unless catalog.keys.sort == seen.sort

signature = ->(value) { value.scan(/%\d+\$@/).sort }
catalog.each do |key, translations|
  expected = signature.call(translations.fetch('en'))
  translations.each do |locale, value|
    abort "Placeholder mismatch: #{key} (#{locale})" unless signature.call(value) == expected
  end
end

sources = Dir['Sources/*.swift'].map { |path| File.read(path, encoding: 'UTF-8') }.join("\n")
keys = sources.scan(/(?:\bL\(|\bMapDefinition\(|\bkey: )"([\w.]+)"/).flatten.uniq
missing = keys - catalog.keys
abort "Add all ten translations for: #{missing.sort.join(', ')}" unless missing.empty?

resources = ARGV.fetch(0)
languages.each do |locale|
  directory = File.join(resources, "#{locale}.lproj")
  FileUtils.mkdir_p(directory)
  File.open(File.join(directory, 'Localizable.strings'), 'w:UTF-8') do |file|
    catalog.each do |key, translations|
      file.puts "#{key.to_json} = #{translations.fetch(locale).to_json};"
    end
  end
end
