# encoding: utf-8
require "logstash/filters/base"
require "logstash/namespace"
require "logstash/plugin_mixins/ecs_compatibility_support"

# The clone filter is for duplicating events.
# A clone will be created for each type in the clone list.
# The original event is left unchanged.
# Created events are inserted into the pipeline 
# as normal events and will be processed by the remaining pipeline configuration 
# starting from the filter that generated them (i.e. this plugin).
#
# ECS disabled: set the value of the root-level `type` (undefined in ECS) of each resulting event
# to one of the values provided in its `clones` directive.
# ECS enabled: add a `tags` of each resulting event to one of the values provided in its `clones` directive.
class LogStash::Filters::Clone < LogStash::Filters::Base
  include LogStash::PluginMixins::ECSCompatibilitySupport(:disabled, :v1)

  config_name "clone"

  # A new clone will be created with the given type for each type in this list.
  config :clones, :validate => :array, :required => true

  public

  def initialize(*params)
    super
    @event_enhance_method = method( ecs_select[disabled: :set_event_type, v1: :add_event_tag] )
  end

  def register
    logger.warn("The parameter 'clones' is empty, so no clones will be created.") if @clones.empty?
  end

  public
  def filter(event)
    @clones.each do |type|
      clone = event.clone
      @event_enhance_method.(clone, type)
      filter_matched(clone)
      @logger.debug("Cloned event", :clone => clone, :event => event)

      # Push this new event onto the stack at the LogStash::FilterWorker
      yield clone
    end
  end

  def set_event_type(event, type)
    event.set("type", type)
    event
  end

  def add_event_tag(event, clone_type)
    tags = Array(event.get("tags"))
    tags << clone_type
    event.set("tags", tags)
    event
  end

end # class LogStash::Filters::Clone
