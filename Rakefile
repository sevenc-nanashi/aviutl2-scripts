# frozen_string_literal: true

require "syntax_tree/rake_tasks"

task default: %i[build]
task build: %i[prepare_description aulua_build]

$check_mode = false

task "build:dry" do
  $check_mode = :not_updated
  Rake::Task[:prepare_description].invoke
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

script_dirs = Dir.glob("scripts/*").select { |f| File.directory?(f) }

task :prepare_description do
  require "uri"
  puts "Preparing script descriptions in README.md and script files..."

  header_width = 120
  quote_header_width = nil

  base = File.read("README.md")
  replacement =
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
              label =
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
              new_line = "#{indent}┌ #{label}"
              quote_header_width = text_width(label) + 2
              description_lines << new_line
            else
              description_lines << "#{indent}│ #{quote_line.rstrip}"
            end
          else
            description = line if description.nil?
            skip_empty = false
            description_lines << "#{indent}#{line.rstrip}"
          end
        end
      end
      description_lines << ""
      description_lines << "=" * header_width

      readme_lua_path = File.join(script_dir, "readme.lua")
      readme_lua_content =
        description_lines.map { |l| "-- #{l}".strip }.join("\n") + "\n"
      update_file(readme_lua_path, readme_lua_content)

      "- [#{title}](#{url})（[説明書](#{readme_url})）：#{description}"
    end
  unless base.gsub!(
           /(?<=<!-- script-marker-start -->\n).*(?=\n<!-- script-marker-end -->)/m,
           replacement.join("\n")
         )
    raise "Failed to find script marker in README.md"
  end
  update_file("README.md", base)
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
      File.write(path, original[path], mode: "wb")
    else
      puts "No changes for #{path}"
    end
  end
end

desc "デモ用に過去のバージョンもインストールする"
task :install_demo, [:script_dir] do |t, args|
  require "fileutils"
  script_dir = args[:script_dir] || "C:/ProgramData/aviutl2/Script"

  install_root = File.join(script_dir, "sevenc-nanashi_aviutl2-scripts")
  FileUtils.mkdir_p(install_root)
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
                parse_changelog_headers(`git show #{c}:#{script_dir}/README.md`)
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
      .reverse_each
      .chain([%i[current_tree current_tree]])
      .each do |version, commit|
        content =
          if commit == :current_tree
            File.read("scripts/#{filename}")
          else
            `git show #{commit}:scripts/#{filename}`
          end
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
    script_path = File.join(install_root, new_filename)
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

configure = ->(task) { task.source_files = FileList[%w[Rakefile]] }

SyntaxTree::Rake::CheckTask.new(&configure)
SyntaxTree::Rake::WriteTask.new(&configure)
