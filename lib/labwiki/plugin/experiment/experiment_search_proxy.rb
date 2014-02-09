require 'labwiki/plugin/experiment/experiment'

module LabWiki::Plugin::Experiment
  class ExperimentSearchProxy
    def self.instance
      unless proxy = OMF::Web::SessionStore[self.to_s, :proxy]
        proxy = OMF::Web::SessionStore[self.to_s, :proxy] = self.new
      end
      proxy
    end

    def find(pattern, opts)
      opts[:mime_type] = 'text/ruby'
      files = OMF::Web::ContentRepository.find_files(pattern, opts)

      experiments = [
        {url: 'foo:/x1', name: 'exp1', mime_type: 'experiment'},
        {url: 'foo:/x2', name: 'exp2', mime_type: 'experiment'}
      ]

      experiments.concat(files)
    end
  end
end
