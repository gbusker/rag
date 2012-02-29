require 'open3'
require 'yaml'
require 'term/ansicolor'
require 'thread'
require 'fileutils'
require 'tempfile'

$m_stdout = Mutex.new
$m_db = Mutex.new
$i_db = 0

Dir["lib/graders/feature_grader/*.rb"].each { |file| load file }
$CUKE_RUNNER = File.join(File.expand_path('lib/graders/feature_grader'), 'cuke_runner')

def log(*args)
  $m_stdout.synchronize { puts *args }
end

# +AutoGrader+ that scores using cucumber features
class FeatureGrader < AutoGrader

  class ScenarioMatcher
    attr_reader :regex

    # [+"match"+] +String+ regular expression for matching +cucumber+ output
    def initialize(h, config={})
      raise(ArgumentError, "no regex") unless @regex = h["match"]

      @config = config
      @regex = /#{@regex}/
    end

    # [+str+] _String_ to match against
    def match?(str)
      !!(str =~ @regex)
    end
  end

  attr_accessor :features_archive, :description
  attr_reader   :features

  # Grade the features contained in the +.tar.gz+ archive _features_archive_,
  # using the reference solution _app_.
  #
  # +grading_rules+ is a +Hash+ of
  # [+:description+] +String+ location of grading description [TODO document format]
  #
  # :call-seq:
  #   new(features_archive, grading_rules, app) -> FeatureGrader

  def initialize(features_archive, grading_rules={})
    @features = []

    unless @features_archive = features_archive and File.file? @features_archive and File.readable? @features_archive
      raise ArgumentError, "Unable to find features archive #{@features_archive.inspect}"
    end

    unless @description = grading_rules[:description] and File.file? @description and File.readable? @description
      raise ArgumentError, "Unable to find description file #{@description.inspect}"
    end

    $config = {:mt => grading_rules[:mt] || true} # TODO merge all the configs

    @temp = TempArchiveFile.new(@features_archive)
  end

  def grade!
    begin
      load_description

      ENV['RAILS_ENV'] = 'test'

      start_time = Time.now

      score = Feature.total(@features)   # TODO integrate Score
      @raw_score, @raw_max = score.points, score.max

      log "Completed in #{Time.now-start_time} seconds.".yellow  # TODO remove this
    ensure
      @temp.destroy if @temp
    end
  end

  private

  def load_description
    puts "Loading #{@description}..."
    y = YAML::load_file(@description)

    # This does some hacky stuff to get references to work properly
    config = {
      :temp => @temp
    }

    { "scenarios" => ScenarioMatcher,
      "features"  => Feature
    }.each_pair do |label,klass|
      y[label].each {|h| h[:object] = klass.new(h, config)}
    end

    objectify = lambda {|arr| arr.collect! {|h| h[:object]}}
    featurize = lambda do |f|
      %w( failures ).each do |attr|
        f[attr].collect! {|h| h.is_a?(Hash) ? h[:object] : h} if f.has_key?(attr)
      end

      f["if_pass"].collect! {|h| featurize.call(h); Feature.new(h, config)} if f.has_key?("if_pass")
    end

    y["features"].each {|h| featurize.call(h)}

    @features = y["features"].collect {|h| h[:object]}
  end

end

class HW3Grader < FeatureGrader
end
