# frozen_string_literal: true

task default: [:prepare_description]

task :prepare_description do
  require "uri"

  header_width = 80

  base = File.read("README.md")
  scripts = Dir.glob("./scripts/*.*2")
  replacement =
    scripts.map do |script|
      filename = File.basename(script)
      content = File.read(script)
      description = content.match(/-- =+\n-- (.+?)\n/)[1].strip

      url = "https://aviutl2-scripts-download.sevenc7c.workers.dev/#{URI.encode_www_form_component(filename)}"
      unless content.gsub!(
               /-- =+\n-- .+?\n-- .+?\n-- =+/,
               <<~LUA
               -- #{'=' * header_width}
               -- #{description}
               -- #{url}
               -- #{'=' * header_width}
               LUA
             )
        raise "Failed to find script marker in README.md"
      end
      File.write(script, content)
      "- [#{filename}](#{url})：#{description}"
    end
  unless base.gsub!(
           /(?<=<!-- script-marker-start -->\n).*(?=\n<!-- script-marker-end -->)/m,
           replacement.join("\n")
         )
    raise "Failed to find script marker in README.md"
  end
  File.write("README.md", base)
end
