# frozen_string_literal: true

require "syntax_tree/rake_tasks"

task default: %i[build]
task build: [:prepare_description, "build:i18n", :aulua_build]

$check_mode = false

task "build:dry" do
  $check_mode = :not_updated
  Rake::Task[:prepare_description].invoke
  Rake::Task["build:i18n"].invoke
  Rake::Task["aulua_build:dry"].invoke
  if $check_mode == :not_updated
    puts "All files are up to date."
  else
    puts "Some files need to be updated."
    exit 1
  end
end

def update_file(path, new_content)
  content = (File.exist?(path) ? File.read(path) : nil)
  if new_content != content
    if $check_mode == false
      File.write(path, new_content, mode: "wb")
      puts "Updated #{path}"
    else
      puts "File #{path} needs to be updated"
      $check_mode = :updated
    end
  else
    puts "No changes for #{path}"
  end
end

def remove_generated_file(path)
  return unless File.exist?(path)

  if $check_mode == false
    File.delete(path)
    puts "Removed #{path}"
  else
    puts "File #{path} needs to be removed"
    $check_mode = :updated
  end
end

def text_width(text)
  text.each_char.sum do |ch|
    case ch.ord
    when 0x0000..0x001F, 0x007F..0x009F
      0
    when 0x0020..0x1FFF
      1
    when 0x2000..0xFF60
      2
    else
      1
    end
  end
end

def alert_label(type)
  case type
  when "NOTE"
    "ℹ️ Note"
  when "TIP"
    "💡 Tips"
  when "WARNING"
    "⚠️ Warning"
  when "IMPORTANT"
    "❗ Important"
  when "CAUTION"
    "🛑 Caution"
  else
    type.capitalize
  end
end

def render_alert_blocks(text)
  rendered_lines = []
  alert_width = nil

  text.each_line(chomp: true) do |line|
    if alert_width
      if line.match(/\A> ?(?<quote_text>.*)\z/) in { quote_text: }
        rendered_lines << "│ #{quote_text.rstrip.delete_suffix("\\")}"
        next
      end

      rendered_lines << "└#{"─" * (alert_width / 2 + 1)}"
      alert_width = nil
    end

    if line.match(/\A> \[!(?<type>[A-Z]+)\]\s*\z/) in { type: }
      label = alert_label(type)
      rendered_lines << "┌ #{label}"
      alert_width = text_width(label) + 2
    else
      rendered_lines << line
    end
  end

  rendered_lines << "└#{"─" * (alert_width / 2 + 1)}" if alert_width
  rendered_text = rendered_lines.join("\n")
  rendered_text << "\n" if text.end_with?("\n")
  rendered_text
end

script_dirs = Dir.glob("scripts/*").select { |f| File.directory?(f) }

namespace :build do
  desc "i18n.yamlから言語ファイルを生成する"
  task :i18n do
    require "fileutils"
    require "toml-rb"
    require "yaml"

    artifacts = TomlRB.load_file("aviutl2.toml").fetch("artifacts")

    script_dirs.each do |script_dir|
      yaml_path = File.join(script_dir, "i18n.yaml")
      next unless File.exist?(yaml_path)

      script_paths =
        Dir.glob("#{script_dir}.*").select { |path| File.file?(path) }
      artifact_ids =
        artifacts.filter_map do |artifact_id, artifact|
          artifact_id if script_paths.include?(artifact["source"])
        end
      unless artifact_ids.size == 1
        raise "Expected exactly one artifact for #{script_dir}, found #{artifact_ids.size}"
      end
      artifact_id = artifact_ids.first

      translations =
        YAML.safe_load(
          File.read(yaml_path),
          permitted_classes: [],
          permitted_symbols: [],
          aliases: false,
          filename: yaml_path
        )
      output_dir = File.join(script_dir, "i18n")
      FileUtils.mkdir_p(output_dir) if $check_mode == false
      expected_paths =
        translations.map do |language, sections|
          content =
            <<~INI +
            [Language]
            Information=#{language} Language for sevenc-nanashi/aviutl2-scripts / https://github.com/sevenc-nanashi/aviutl2-scripts
            INI
              sections
                .map do |section, values|
                  [
                    "[#{section}]",
                    *values.map do |key, value|
                      "#{key}=#{render_alert_blocks(value).gsub("\n", "\\n")}"
                    end
                  ].join("\n")
                end
                .join("\n\n") + "\n"
          output_path = File.join(output_dir, "#{language}.#{artifact_id}.aul2")
          update_file(output_path, content)
          output_path
        end

      (
        Dir.glob(File.join(output_dir, "*.aul2")) - expected_paths
      ).each { |path| remove_generated_file(path) }
    end
  end
end

task :prepare_description do
  require "uri"
  puts "Preparing script descriptions in README.md and script files..."

  header_width = 120
  quote_header_width = nil

  scripts =
    script_dirs.sort.map do |script_dir|
      readme_path = File.join(script_dir, "README.md")
      raise "Missing README.md in #{script_dir}" unless File.exist?(readme_path)
      readme_content = File.read(readme_path)
      lines = readme_content.lines.map(&:chomp)

      title_line = lines.shift
      title = title_line.sub(/\A#+\s*/, "").strip
      url =
        "https://aviutl2-scripts-download.sevenc7c.workers.dev/#{URI.encode_www_form_component(title)}"
      readme_url =
        "https://github.com/sevenc-nanashi/aviutl2-scripts/blob/main/scripts/#{
          URI.encode_www_form_component(File.basename(script_dir))
        }/README.md"

      description_lines = []
      description_lines << "=" * header_width
      description_lines << "最新版をダウンロード：#{url}"
      description_lines << "説明書をブラウザで読む：#{readme_url}"
      description_lines << ""
      skip_empty = true
      current_level = 0
      description = nil
      lines.each do |line|
        # コメントは消す
        line.gsub!(/<!--.*?-->/, "")
        # URLの周りの<>は消す
        line.gsub!(%r{<(?<url>https?://[^ >]+)>}) { Regexp.last_match[:url] }

        indent = "  " * current_level
        if !line.start_with?("> ") && quote_header_width
          description_lines << "#{indent}└#{"─" * (quote_header_width / 2 + 1)}"
          quote_header_width = nil
        end
        if line.start_with?("#")
          line.match(/\A(?<level>#+) (?<text>.*)/) => { level:, text: }
          if level.size == 1
            unless line == "# 更新履歴"
              raise "Unexpected top-level header in #{readme_path}: #{line}"
            end
            current_level = 0
            header = "--< #{text.strip} >"
            current_width = text_width(header)
            header += "-" * (header_width - current_width)
            description_lines << header
            description_lines << ""
            skip_empty = true
            next
          end
          current_level = level.size - 1
          description_lines << "#{"  " * (current_level - 1)}[ #{text.strip} ]"
          skip_empty = true
        elsif line.start_with?("----")
          current_level = 0
        else
          next if skip_empty && line.strip.empty?
          if line.start_with?("> ")
            quote_line = line.sub(/\A> /, "")
            if quote_line.match(/\[!(?<type>[A-Z]+)\]/) in { type: }
              label = alert_label(type)
              new_line = "#{indent}┌ #{label}"
              quote_header_width = text_width(label) + 2
              description_lines << new_line
            else
              description_lines << "#{indent}│ #{quote_line.rstrip.delete_suffix("\\")}"
            end
          else
            description = line if description.nil?
            skip_empty = false
            description_lines << "#{indent}#{line.rstrip.delete_suffix("\\")}"
          end
        end
      end
      description_lines << ""
      description_lines << "=" * header_width

      readme_lua_path = File.join(script_dir, "readme.lua")
      readme_lua_content =
        description_lines.map { |l| "-- #{l}".strip }.join("\n") + "\n"
      update_file(readme_lua_path, readme_lua_content)

      readme_en_path = File.join(script_dir, "README.en.md")
      readme_en_content = File.read(readme_en_path)
      en_title_line = readme_en_content.lines.first.sub(/\A#+\s*/, "").strip
      en_description =
        readme_en_content.lines[1..]
          .find { |line| !line.strip.empty? }
          &.strip || ""

      # "- #{title}（[au2pkg](#{url}?type=au2pkg)、[スクリプト本体](#{url}?type=script)、[説明書](#{readme_url})）：#{description}"
      {
        title:,
        title_en: en_title_line,
        url:,
        readme_url:,
        description:,
        description_en: en_description
      }
    end

  base_ja = File.read("README.md")
  replacement_ja =
    scripts.map do |script|
      "- #{script[:title]}（[au2pkg](#{script[:url]}?type=au2pkg)、[スクリプト本体](#{script[:url]}?type=script)、[説明書](#{script[:readme_url]})）：#{script[:description]}"
    end
  unless base_ja.gsub!(
           /(?<=<!-- script-marker-start -->\n).*(?=\n<!-- script-marker-end -->)/m,
           replacement_ja.join("\n")
         )
    raise "Failed to find script marker in README.md"
  end
  update_file("README.md", base_ja)

  base_en = File.read("README.en.md")
  replacement_en =
    scripts.map do |script|
      "- #{script[:title_en]} ([au2pkg](#{script[:url]}?type=au2pkg), [script](#{script[:url]}?type=script), [readme](#{script[:readme_url]})): #{script[:description_en]}"
    end
  unless base_en.gsub!(
           /(?<=<!-- script-marker-start -->\n).*(?=\n<!-- script-marker-end -->)/m,
           replacement_en.join("\n")
         )
    raise "Failed to find script marker in README.en.md"
  end
  update_file("README.en.md", base_en)

  puts "Done."
end

task :aulua_build do
  sh "aulua build"
end

task "aulua_build:dry" do
  original =
    Dir
      .glob("./scripts/*.*")
      .to_h { |path| [path, File.read(path, mode: "rb")] }
  Rake::Task[:aulua_build].invoke
  updated =
    Dir
      .glob("./scripts/*.*")
      .to_h { |path| [path, File.read(path, mode: "rb")] }
  updated.each do |path, content|
    if original[path] != content
      puts "File #{path} needs to be updated"
      $check_mode = :updated
      if original[path]
        File.write(path, original[path], mode: "wb")
      else
        File.delete(path)
      end
    else
      puts "No changes for #{path}"
    end
  end
end

desc "デモ用のスクリプトを生成する"
task :demo do |t, args|
  require "fileutils"
  install_dir = "./demo"

  FileUtils.mkdir_p(install_dir)
  script_dirs.each do |script_dir|
    puts "Processing #{script_dir}..."
    final_content = []
    readme_commits = [
      *`git log --pretty="%H" -- #{script_dir}/README.md`.lines
        .map(&:chomp)
        .reverse,
      :current_tree
    ]
    partial_versions =
      parse_changelog_headers(File.read("#{script_dir}/README.md"))
    filename =
      File.read("#{script_dir}/README.md").lines.first.sub(/\A#+\s*/, "").strip
    versions =
      partial_versions.to_h do |version, commit|
        if commit
          puts "  Using override commit #{commit} for version #{version}"
          next version, commit
        end

        version_commit =
          readme_commits.bsearch do |c|
            if c == :current_tree
              true
            else
              versions_in_commit =
                parse_changelog_headers(
                  `git show #{c}:#{script_dir}/README.md`.force_encoding(
                    "UTF-8"
                  )
                )
              versions_in_commit.key?(version)
            end
          end
        unless version_commit
          raise "Could not find commit for version #{version} in #{script_dir}"
        end
        puts "  Found commit #{version_commit} for version #{version}"
        [version, version_commit]
      end
    versions
      .each
      .chain([%i[current_tree current_tree]])
      .each do |version, commit|
        content =
          if commit == :current_tree
            File.read("scripts/#{filename}", mode: "rb")
          else
            `git show #{commit}:scripts/#{filename}`
          end.force_encoding("UTF-8")
        final_content << if version == :current_tree
          "@current"
        else
          "@v#{version}"
        end
        unless content.sub!(/--label:(.+)/) {
                 "--label:[sevenc-nanashi/aviutl2-scripts]\\#{$1}\\#{filename}"
               }
          content = "--label:#{filename}\n" + content
        end
        final_content << content
      end
    new_filename = "@#{filename}"
    script_path = File.join(install_dir, new_filename)
    update_file(script_path, final_content.join("\n"))
  end
end

def parse_changelog_headers(content)
  headers = {}
  content
    .lines
    .drop_while { |line| line.chomp != "# 更新履歴" }
    .each do |line|
      if line.match(/^## v(?<version>[0-9\.]+)/) in { version: }
        override =
          line.match(/<!-- commit-override: (?<commit>[0-9a-f]{7,40}) -->/)
        headers[version] = override ? override[:commit] : nil
      end
    end
  headers
end

clang_format_files = Dir.glob("**/*.hlsl")
task "clang_format" do
  sh "clang-format -i -- #{clang_format_files.join(" ")}"
end
task "clang_format:dry" do
  sh "clang-format -i --dry-run --fail-on-incomplete-format -Werror -- #{clang_format_files.join(" ")}"
end

task "new_script" do
  require "fileutils"
  puts "Creating new script..."
  print "Enter script name: "
  script_name = STDIN.gets.chomp
  if script_name.empty?
    puts "Script name cannot be empty."
    exit 1
  end
  unless script_name.match?(/\.[a-z]{3}2\z/)
    puts "Script name must end with .xxx2"
    exit 1
  end
  print "Enter script ID: "
  script_id = STDIN.gets.chomp
  unless script_id.match?(/\-[a-z]{3}2\z/)
    puts "Script ID must end with -xxx2"
    exit 1
  end
  demo_script_id = script_id.sub(/\-[a-z]{3}2\z/, "-demo\\0")
  if script_name[-4..-2] != demo_script_id[-4..-2]
    puts "Script name and script ID must have the same extension"
    exit 1
  end
  i18n_english_id = script_id.sub(/\-[a-z]{3}2\z/, "\\0-i18n-en")
  i18n_default_id = script_id.sub(/\-[a-z]{3}2\z/, "\\0-i18n-ja")
  script_dir_name = File.basename(script_name, ".*")
  script_dir = File.join("scripts", script_dir_name)
  if Dir.exist?(script_dir)
    puts "Directory #{script_dir} already exists."
    exit 1
  end
  FileUtils.mkdir_p(script_dir)
  readme_path = File.join(script_dir, "README.md")
  File.write(readme_path, <<~MARKDOWN)
    # #{script_name}

    # 更新履歴

    ## v1.0（#{Time.now.strftime("%Y/%m/%d").gsub("/0", "/")}）

    - 初版リリース
  MARKDOWN
  script_path = File.join(script_dir, "main.lua")
  File.write(script_path, <<~LUA)
  --label:

  ---$include "./readme.lua"
  LUA

  aviutl2_toml = File.read("aviutl2.toml")
  aviutl2_toml += <<~TOML

    [artifacts.#{script_id}]
    build.group = "aulua"
    source = "scripts/#{script_name}"
    destination = "Script/#{script_name}"

    [artifacts.#{demo_script_id}]
    build.group = "aulua"
    source = "demo/@#{script_name}"
    destination = "Script/@#{script_name}"

    [artifacts.#{i18n_default_id}]
    source = "#{script_dir}/i18n/Default.#{script_id}.aul2"
    destination = "Language/Default.#{script_id}.aul2"

    [artifacts.#{i18n_english_id}]
    source = "#{script_dir}/i18n/English.#{script_id}.aul2"
    destination = "Language/English.#{script_id}.aul2"
  TOML
  File.write("aviutl2.toml", aviutl2_toml)

  aulua = File.read("aulua.yaml")
  aulua += <<-YAML
  - name: #{script_name}
    sources:
      - path: #{script_dir}/main.lua
  YAML
  File.write("aulua.yaml", aulua)

  puts "Created new script in #{script_dir}."
end

configure = ->(task) { task.source_files = FileList[%w[Rakefile]] }

SyntaxTree::Rake::CheckTask.new(&configure)
SyntaxTree::Rake::WriteTask.new(&configure)
