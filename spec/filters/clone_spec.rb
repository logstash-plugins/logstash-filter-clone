# encoding: utf-8

require "logstash/devutils/rspec/spec_helper"
require "logstash/filters/clone"

describe LogStash::Filters::Clone do

  describe "all defaults" do
    type "original"
    config <<-CONFIG
      filter {
        clone {
          clones => ["clone", "clone", "clone"]
        }
      }
    CONFIG

    sample("message" => "hello world", "type" => "original") do
      insist { subject }.is_a? Array
      insist { subject.length } == 4
      subject.each_with_index do |s,i|
        if i == 0 # last one should be 'original'
          insist { s.get("type") } == "original"
        else
          insist { s.get("type")} == "clone"
        end
        insist { s.get("message") } == "hello world"
      end
    end
  end

  describe "Complex use" do
    config <<-CONFIG
      filter {
        clone {
          clones => ["nginx-access-clone1", "nginx-access-clone2"]
          add_tag => ['RABBIT','NO_ES']
          remove_tag => ["TESTLOG"]
        }
      }
    CONFIG

    sample("type" => "nginx-access", "tags" => ["TESTLOG"], "message" => "hello world") do
      insist { subject }.is_a? Array
      insist { subject.length } == 3

      insist { subject[0].get("type") } == "nginx-access"
      #Initial event remains unchanged
      insist { subject[0].get("tags") }.include? "TESTLOG"
      reject { subject[0].get("tags") }.include? "RABBIT"
      reject { subject[0].get("tags") }.include? "NO_ES"
      #All clones go through filter_matched
      insist { subject[1].get("type") } == "nginx-access-clone1"
      reject { subject[1].get("tags") }.include? "TESTLOG"
      insist { subject[1].get("tags") }.include? "RABBIT"
      insist { subject[1].get("tags") }.include? "NO_ES"

      insist { subject[2].get("type") } == "nginx-access-clone2"
      reject { subject[2].get("tags") }.include? "TESTLOG"
      insist { subject[2].get("tags") }.include? "RABBIT"
      insist { subject[2].get("tags") }.include? "NO_ES"
    end
  end

  describe "clone_array_name" do
    config <<-CONFIG
      filter {
        clone {
          clone_array_name => "clones"
        }
      }
    CONFIG

    sample("type" => "nginx-access", "tags" => ["TESTLOG"], "message" => "hello world", "clones" => ["1","2","3"]) do
      insist { subject }.is_a? Array
      insist { subject.length } == 4

      insist { subject[0].get("type") } == "nginx-access"
      #Initial event remains unchanged
      insist { subject[0].get("tags") }.include? "TESTLOG"
      #All clones go through filter_matched
      insist { subject[1].get("type") } == "1"
      insist { subject[2].get("type") } == "2"
      insist { subject[3].get("type") } == "3"
    end
  end

  describe "Bug LOGSTASH-1225" do
    ### LOGSTASH-1225: Cannot clone events containing numbers.
    config <<-CONFIG
      filter {
        clone {
          clones => [ 'clone1' ]
        }
      }
    CONFIG

    sample("type" => "bug-1225", "message" => "unused", "number" => 5) do
      insist { subject[0].get("number") } == 5
      insist { subject[1].get("number") } == 5
    end
  end


end
