require 'rake'
require 'erb'
require 'grit'

PKG_RELEASE=ENV['PKG_RELEASE'] || 1

def list_patches
  Dir["SOURCES/*.patch"].sort.map {|f| f.gsub("SOURCES/", "")}
end

def printable_patch_list(ls=nil)
  ls||=list_patches
  result, = ls.inject([[], 0]) do |acc, value|
    ls_so_far, idx = acc
    [ls_so_far << "Patch#{idx}: #{value}", idx + 1]
  end
  result.join("\n")
end

def rpm_dirs
  %w{BUILD BUILDROOT RPMS SOURCES SPECS SRPMS}
end

def pkg_version
  db_version
end

def pkg_rel
  PKG_RELEASE
end

def pkg_name
  'condor-wallaby-base-db'
end

def pkg_spec
  pkg_name() + ".spec"
end

def pkg_source
  "#{pkg_dir}.tar.gz"
end

def pkg_dir
  "#{pkg_name}-#{pkg_version}"
end

def db_file
  'condor-base-db.snapshot'
end

def db_version_file
  "DB_VERSION"
end

def db_version
  File.read(db_version_file).chomp()
end

def db_patch_dir
  "patches"
end

def commit_version
  new_version = pkg_version
  message = "bumping DB_VERSION from #{@old_version} to #{new_version}"
  sh "git commit -m '#{message}' #{db_version_file}"
  sh "git tag v#{new_version}"
  sh "git push origin master v#{new_version}" 
end

desc "bump the minor version number"
task :bump_minor do
  @old_version = db_version
  ver = @old_version.split(".")
  sh "sed -i 's/#{ver[0]}.#{ver[1]}/#{ver[0]}.#{ver[1].to_i.next}/' #{db_version_file}"
  commit_version
end

desc "bump the major version number"
task :bump_major do
  @old_version = db_version
  ver = @old_version.split(".")
  sh "sed -i 's/#{ver[0]}.#{ver[1]}/#{ver[0].to_i.next}.0/' #{db_version_file}"
  commit_version
end

def package_prefix
  "#{pkg_name}-#{pkg_version}"
end

def pristine_name
  "#{package_prefix}.tar.gz"
end

desc "upload a pristine tarball for the current release to fedorahosted"
task :upload_pristine => [:pristine] do
  raise "Please set FH_USERNAME" unless ENV['FH_USERNAME']
  sh "scp #{pristine_name} #{ENV['FH_USERNAME']}@fedorahosted.org:grid"
end

desc "generate a pristine tarball for the tag corresponding to the current version"
task :pristine do
  sh "git archive --format=tar v#{pkg_version} --prefix=#{package_prefix}/ | gzip -9nv > #{pristine_name}"
end

desc "create RPMs"
task :rpms => [:make_rpmdirs, :pristine, :spec_patches, :gen_spec] do
  FileUtils.cp pristine_name, 'SOURCES'
  FileUtils.cp pkg_spec, 'SPECS'
  sh "rpmbuild --define=\"_topdir \${PWD}\" -ba SPECS/#{pkg_spec}"
end

task :spec_patches do
  numbered_files = ENV['SIMPLE_GIT_PATCH_NAMES'] ? "--numbered-files" : ""
  sh "git format-patch #{numbered_files} -o SOURCES v#{pkg_version}"
end

desc "Generate the specfile"
task :gen_spec do
  File.open(pkg_spec, "w") do |f|
    f.write(ERB.new(File.read("#{pkg_spec}.in")).result(binding))
  end
end

desc "Generate the database file"
task :gen_db_file do
  File.open(db_file, "w") do |f|
    f.write(ERB.new(File.read("#{db_file}.in")).result(binding))
  end
end

desc "Make dirs for building RPM"
task :make_rpmdirs => :clean do
  FileUtils.mkdir pkg_dir
  FileUtils.mkdir rpm_dirs
end

desc "Cleanup after an RPM build"
task :clean do
  FileUtils.rm_r [pkg_dir, rpm_dirs, pkg_spec, pristine_name, db_file], :force => true
end

task :default => :gen_db_file
