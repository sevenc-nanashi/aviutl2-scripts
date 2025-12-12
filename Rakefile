# frozen_string_literal: true

task default: [:prepare_description, :build]

task :prepare_description do
  require "uri"
  puts "Preparing script descriptions in README.md and script files..."

  header_width = 120

  base = File.read("README.md")
  scripts = { "ドット絵変形.anm2" => "./scripts/ドット絵変形/main.lua" }
  replacement =
    scripts.map do |name, script|
      puts "Processing #{name}..."
      content = File.read(script)
      original_content = content.dup
      description = content.match(/-- =+\n-- (.+?)\n/)[1].strip

      url =
        "https://aviutl2-scripts-download.sevenc7c.workers.dev/#{URI.encode_www_form_component(name)}"
      maybe_replaced =
        content.gsub!(/-- =+\n((?:--(?: .+?)?\n)*)-- .+?\n-- =+\n/) { <<~LUA }
        -- #{"=" * header_width}
        #{$1.rstrip}
        -- #{url}
        -- #{"=" * header_width}
        LUA
      raise "Failed to find script marker in #{script}" unless maybe_replaced
      if content == original_content
        puts "No changes made to #{script}."
      else
        puts "Updating script file #{script} with download URL..."
        File.write(script, content, mode: "wb")
      end
      "- [#{name}](#{url})：#{description}"
    end
  unless base.gsub!(
           /(?<=<!-- script-marker-start -->\n).*(?=\n<!-- script-marker-end -->)/m,
           replacement.join("\n")
         )
    raise "Failed to find script marker in README.md"
  end
  File.write("README.md", base, mode: "wb")
  puts "Done."
end

task :build do
  sh "aulua build"
end

desc "デモ用に過去のバージョンもインストールする"
task :install_demo, [:script_dir] do |t, args|
  require "fileutils"
  script_dir = args[:script_dir] || "C:/ProgramData/aviutl2/Script"

  install_root = File.join(script_dir, "sevenc-nanashi_aviutl2-scripts")
  FileUtils.mkdir_p(install_root)
  revisions = {
    "ドット絵変形.anm2" => {
      "v3.0": "2dc44cd",
      "v2.1": "d31c227",
      "v2.0": "4f848b5",
      "v1.0": "4a8d9bb"
    }
  }
  revisions.each do |filename, revs|
    final_content = []
    revs.each do |version, commit|
      content = `git show #{commit}:scripts/#{filename}`
      final_content << "@#{version}"
      unless content.sub!(/--label:(.+)/) {
               "--label:[sevenc-nanashi/aviutl2-scripts]\\#{$1}\\#{filename}"
             }
        content = "--label:#{filename}\n" + content
      end
      final_content << content
    end
    new_filename = "@#{filename}"
    script_path = File.join(install_root, new_filename)
    puts "Writing #{script_path}"
    File.write(script_path, final_content.join("\n"), mode: "wb")
  end
end
