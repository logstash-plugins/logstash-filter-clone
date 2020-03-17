# encoding: utf-8
require "logstash/devutils/rspec/spec_helper"
require "logstash/filters/clone"

describe LogStash::Filters::Clone do

  describe "#filter" do
    subject { described_class.new(settings) }
    let(:event) { LogStash::Event.new(input) }
    before(:each) do
      subject.register
    end
    describe "all defaults" do
      let(:input) { { "message" => "hello world", "type" => "original" } }
      let(:settings) { { "clones" => ["clone", "clone", "clone"] } }

      it "should generate new clones + current event" do
        events = [event]
        subject.filter(event) {|e| events << e }
        expect(events.length).to eq(4)
        events.each_with_index do |s,i|
          if i == 0 # last one should be 'original'
            expect(s.get("type")).to eq("original")
          else
            expect(s.get("type")).to eq("clone")
          end
          expect(s.get("message")).to eq("hello world")
        end
      end
    end

    describe "Complex use" do
      let(:settings) do
        { "clones" => ["nginx-access-clone1", "nginx-access-clone2"],
          "add_tag" => ['RABBIT','NO_ES'],
          "remove_tag" => ["TESTLOG"]
        }
      end
      let(:input) { { "type" => "nginx-access", "tags" => ["TESTLOG"], "message" => "hello world" } }

      it "works as expected" do
        events = [event]
        subject.filter(event) {|e| events << e }
        expect(events.length).to eq(3)

        expect(events[0].get("type")).to eq("nginx-access")
        #Initial event remains unchanged
        expect(events[0].get("tags")).to include("TESTLOG")
        expect(events[0].get("tags")).to_not include("RABBIT")
        expect(events[0].get("tags")).to_not include("NO_ES")
        #All clones go through filter_matched
        expect(events[1].get("type")).to eq("nginx-access-clone1")
        expect(events[1].get("tags")).to_not include("TESTLOG")
        expect(events[1].get("tags")).to include("RABBIT")
        expect(events[1].get("tags")).to include("NO_ES")

        expect(events[2].get("type")).to eq("nginx-access-clone2")
        expect(events[2].get("tags")).to_not include("TESTLOG")
        expect(events[2].get("tags")).to include("RABBIT")
        expect(events[2].get("tags")).to include("NO_ES")
      end
    end

    describe "Bug LOGSTASH-1225" do
      ### LOGSTASH-1225: Cannot clone events containing numbers.
      let(:settings) { { "clones" => [ 'clone1' ] } }
      let(:input) { { "type" => "bug-1225", "message" => "unused", "number" => 5 } }

      it "clones events containing numbers" do
        events = [event]
        subject.filter(event) {|e| events << e }
        expect(events[0].get("number")).to eq(5)
        expect(events[1].get("number")).to eq(5)
      end
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
