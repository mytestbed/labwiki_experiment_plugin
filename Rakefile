require 'rake/testtask'
require 'fileutils'
#require "bundler/gem_tasks"

task :default => :test

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.pattern = "test/*_spec.rb"
  t.verbose = true
end

desc "Create an iWidget - host, url, width[640], height[480]"
task :create_iwidget, :host, :url, :width, :height do |t, args|
  host = args[:host]
  url = args[:url]
  width = args[:width] || '440'
  height = args[:height] || '800'
  unless host && url
    abort "Missing parameters 'host', or 'url'"
  end
  top_dir = File.dirname(__FILE__)
  tmpl_dir = File.join(top_dir, 'iwidget')

  wdgt_top_dir = File.join(top_dir, 'build')
  unless File.writable?(wdgt_top_dir)
    Dir.mkdir(wdgt_top_dir)
  end

  wdgt_name = url.gsub(/[_:\.\/]/, '_') + '.wdgt'
  wdgt_dir = File.join(wdgt_top_dir, wdgt_name)
  puts "Creating #{wdgt_dir}"
  FileUtils.cp_r tmpl_dir, wdgt_dir

  config_in = File.join(tmpl_dir, 'config.js.in')
  unless File.readable?(config_in)
    abort "Can't find template file '#{config_in}'."
  end
  tmpl = File.read(config_in)
  s = tmpl.gsub('%HOST%', host).gsub('%URL%', url).gsub('%WIDTH%', width).gsub('%HEIGHT%', height)
  File.open(File.join(wdgt_dir, 'config.js'), 'w') do |f|
    f.write(s)
  end




end

#.wdgt
