# encoding: utf-8
require "logstash/filters/base"
require "logstash/namespace"

# The clone filter is for creating copy of the original event. 
# *The original event is left unchanged,* all modifier such as `add_field` or `add_tag`
# will be applied to the newly created copy.
#
# The default configuration will create an exact copy of the event
# [source, ruby]
# filter {
#   clone {}
# }
#
# You can manipulate the copy using the `add_field`, `add_tag` configurations.
# Following configuration will add a `clone` tag to the copy event.
# [source, ruby]
# filter {
#   clone {
#     add_tag => "clone"
#   }
# }
#
# In case you need to create several copies of the original event, you must set 
# `mode => "multiple"` and specifies an identifier for each copy. 
# By default this identifier is stored in the `type` field, 
# but you can use a different field specifying the `clone_field` setting. 
#
# For example, following configuration will create 3 copies of the original event
# [source,ruby]
# filter {
#   clone {
#     mode => "multiple"
#     clones => ["clone1","clone2","clone3"]
#   }
# }
#
class LogStash::Filters::Clone < LogStash::Filters::Base

  config_name "clone"
  
  # How this filter should operate
  # * 'single' => create an exact copy
  # * 'multiple' => create several copies using identifiers from the `clones` config
  config :mode, :validate => ["single", "multiple"], :default => "single"
  
  # In `multiple` mode, specify which event field to use for storing the copy identifier
  config :clone_field, :validate => :string, :default => "type"
  
  # In `multiple` mode, a new clone will be created for each identifier in this list.
  config :clones, :validate => :array, :default => []

  public
  def register
    # Nothing to do
    if @mode == "single" && clones.length > 0
      #TODO WARN that the mode setting should be correctly set
      @mode = "multiple"
    elsif @mode == "multiple" && clones.length == 1
      #TODO WARN That the "simple" mode could be use with the add_field config
    elsif @mode == "multiple" && clones.length == 0
      #TODO WARN That this filter is doing nothing 
    end
  end

  public
  def filter(event)
    if @mode == "multiple"
      @clones.each do |identifier|
        yield clone(event,identifier)
      end
   else
     yield clone(event,nil)
   end
  end
  
  def clone(event, identifier)
    clone = event.clone
    if identifier
      clone[@clone_field] = identifier
    end
    filter_matched(clone)
    @logger.debug? && @logger.debug("Cloned event", :clone => clone, :event => event)
    return clone
  end

end # class LogStash::Filters::Clone
