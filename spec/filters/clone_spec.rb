# encoding: utf-8

require "logstash/devutils/rspec/spec_helper"
require "logstash/filters/clone"

describe LogStash::Filters::Clone do

  describe "all defaults" do
    type "original"
    config <<-CONFIG
      filter {
        clone {
          clones => {
            "type" => "clone"
            "clone" => "clone1"
          }
        }
      }
    CONFIG

    sample("message" => "hello world", "type" => "original") do
      insist { subject }.is_a? Hash
      insist { subject.length } == 3
      subject.each_with_index do |s,i|
        if i == 0 # last one should be 'original'
          insist { s.get("type") } == "original"
        else if i = 1
          insist { s.get("type")} == "clone"
        else
          insist { s.get("clone")} == "clone1"
        end
        insist { s.get("message") } == "hello world"
      end
    end
  end

  describe "Complex use" do
    config <<-CONFIG
      filter {
        clone {
          clones => {
            "clone" => "nginx-access-clone1"
            "type" => "nginx-access-clone2"
          }
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
      insist { subject[1].get("clone") } == "nginx-access-clone1"
      reject { subject[1].get("tags") }.include? "TESTLOG"
      insist { subject[1].get("tags") }.include? "RABBIT"
      insist { subject[1].get("tags") }.include? "NO_ES"

      insist { subject[2].get("type") } == "nginx-access-clone2"
      reject { subject[2].get("tags") }.include? "TESTLOG"
      insist { subject[2].get("tags") }.include? "RABBIT"
      insist { subject[2].get("tags") }.include? "NO_ES"
    end
  end

  describe "Bug LOGSTASH-1225" do
    ### LOGSTASH-1225: Cannot clone events containing numbers.
    config <<-CONFIG
      filter {
        clone {
          clones => { 'clone1' => 'clone1' }
        }
      }
    CONFIG

    sample("type" => "bug-1225", "message" => "unused", "number" => 5) do
      insist { subject[0].get("number") } == 5
      insist { subject[1].get("number") } == 5
    end
  end

  describe "#register" do
    context "when clones is an empty array" do
      subject { described_class.new("clones" => []) }
      it "logs a warning" do
        expect(subject.logger).to receive(:warn)
        expect { subject.register }.to_not raise_error
      end
    end
    context "when clones is not set" do
      subject { described_class.new }
      it "raises an error" do
        expect { subject.register }.to raise_error(ArgumentError)
      end
    end
  end
end
