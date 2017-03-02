# encoding: utf-8
require "logstash/filters/base"
require "logstash/namespace"

# The clone filter is for duplicating events.
# A clone will be made for each type in the clone list.
# The original event is left unchanged.
class LogStash::Filters::Clone < LogStash::Filters::Base

  config_name "clone"

  # A new clone will be created with the given type for each type in this list.
  config :clones, :validate => :array, :default => []
  # if you want to dynamically specify the list of clones based on a field in the event
  config :clone_array_name, :validate => :string

  public
  def register
    # Nothing to do
  end

  public
  def filter(event)
    if @clone_array_name
      clones = event.get(@clone_array_name);
    else
      clones = @clones;
    end
    clones.each do |type|
      clone = event.clone
      clone.set("type", type)
      filter_matched(clone)
      @logger.debug("Cloned event", :clone => clone, :event => event)

      # Push this new event onto the stack at the LogStash::FilterWorker
      yield clone
    end
  end

end # class LogStash::Filters::Clone
