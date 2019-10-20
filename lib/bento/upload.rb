require "bento/common"

class UploadRunner
  include Common

  attr_reader :md_json

  def initialize(opts)
    @md_json = opts.md_json
  end

  def error_unless_logged_in
    warn("You cannot upload files to vagrant cloud unless the vagrant CLI is logged in. Run 'vagrant cloud auth login' first.") unless logged_in?
  end

  def start
    error_unless_logged_in

    banner("Starting uploads...")
    time = Benchmark.measure do
      files = md_json ? [md_json] : metadata_files
      files.each do |md_file|
        upload_box(md_file)
      end
    end
    banner("Uploads finished in #{duration(time.real)}.")
  end


  #
  # Upload all the boxes defined in the passed metadata file
  #
  # @param [String] md_file The path to the metadata file
  #
  #
  def upload_box(md_file)
    md_data = box_metadata(md_file)

    md_data['providers'].each_pair do |prov, prov_data|
      banner("Uploading bento/#{md_data['name']} version:#{md_data['version']} provider:#{prov}...")

      upload_cmd = "vagrant cloud publish bento/#{md_data['name']} #{md_data['version']} #{prov} builds/#{prov_data['file']} --description '#{box_desc(md_data['name'])}' --short-description '#{box_desc(md_data['name'])}' --version-description '#{ver_desc(md_data, prov)}' --force --release"
      shellout(upload_cmd)

      slug_name = lookup_slug(md_data['name'])
      next if slug_name.nil?
      banner("Uploading slug bento/#{slug_name} from #{md_data['name']} version:#{md_data['version']} provider:#{prov}...")
      upload_cmd = "vagrant cloud publish bento/#{slug_name} #{md_data['version']} #{prov} builds/#{prov_data['file']} --description '#{slug_desc(slug_name)}' --short-description '#{slug_desc(slug_name)}' --version-description '#{ver_desc(md_data, prov)}' --force --release"
      shellout(upload_cmd)
    end
  end

  #
  # Given a box name return a slug name or nil
  #
  # @return [String, NilClass] The slug name or nil
  #
  def lookup_slug(name)
    builds_yml["slugs"].each_pair do |slug, match_string|
      return slug if name.start_with?(match_string)
    end
  end

  def box_desc(name)
    "#{name.tr("-", " ").capitalize} Vagrant box created with Bento by Chef"
  end

  def slug_desc(name)
    "#{name.tr("-", " ").capitalize}.x Vagrant box created with Bento by Chef. This box will be updated with the latest releases of #{name.tr("-", " ").capitalize} as they become available"
  end

  def ver_desc(md_data, provider)
    "#{md_data['name'].tr("-", " ").capitalize} Vagrant box version #{md_data['version']} created with Bento by Chef. Tool version: #{provider}: #{md_data['providers'][provider]['version']}, packer: #{md_data['packer']}, vagrant: #{md_data['vagrant']}"
  end
end
