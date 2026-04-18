require "spec_helper"
require "time"

RSpec.describe Zephira::Formatter do
  describe ".format" do
    described_class::FORMAT_STRINGS.each do |key, value|
      it "replaces ##{key}## with #{value}" do
        input = "This is ###{key.upcase}##text##FORMAT_CLEAR##."
        expected_output = "This is #{value}text\e[0m."

        expect(described_class.format(input)).to eq(expected_output)
      end
    end

    it "replaces unknown format strings with \e[0m" do
      input = "This is ##UNKNOWN##text##FORMAT_CLEAR##."
      expected_output = "This is \e[0mtext\e[0m."

      expect(described_class.format(input)).to eq(expected_output)
    end

    it "indents the string correctly" do
      input = "This is a test.\nThis is another line."
      expected_output = "    This is a test.\n    This is another line."

      expect(described_class.format(input, indent: 4)).to eq(expected_output)
    end
  end

  describe ".available_formats" do
    it "returns a list of available format strings" do
      formats = described_class.available_formats

      expect(formats).to be_a(Array)
      expect(formats).to include("##COLOR_RED## for red text")
      expect(formats).to include("##COLOR_GREEN## for green text")
      expect(formats).to include("##COLOR_GREY## for grey text")
      expect(formats).to include("##FORMAT_BOLD## for bold text")
      expect(formats).to include("##FORMAT_ITALIC## for italic text")
      expect(formats).to include("##FORMAT_UNDERLINED## for underlined text")
      expect(formats).to include("##FORMAT_STRIKETHROUGH## for strikethrough text")
      expect(formats).to include("##FORMAT_BOLD_ITALIC## for bold italic text")
      expect(formats).to include("##FORMAT_BOLD_UNDERLINED## for bold underlined text")
      expect(formats).to include("##FORMAT_ITALIC_UNDERLINED## for italic underlined text")
      expect(formats).to include("##FORMAT_BOLD_STRIKETHROUGH## for bold strikethrough text")
      expect(formats).to include("##FORMAT_ITALIC_STRIKETHROUGH## for italic strikethrough text")
      expect(formats).to include("##FORMAT_UNDERLINED_STRIKETHROUGH## for underlined strikethrough text")
      expect(formats).to include("##FORMAT_CLEAR## to clear all formatting")
    end
  end

  describe ".color" do
    it "returns the string wrapped in the correct ANSI escape code for a given color" do
      expect(described_class.color(:red, "Foo")).to eq("\e[31mFoo\e[0m")
      expect(described_class.color(:green, "Bar")).to eq("\e[32mBar\e[0m")
      expect(described_class.color(:grey, "Baz")).to eq("\e[90mBaz\e[0m")
    end

    it "returns the color code by itselef if no string is provided" do
      expect(described_class.color(:red)).to eq("\e[31m")
      expect(described_class.color(:green)).to eq("\e[32m")
      expect(described_class.color(:grey)).to eq("\e[90m")
    end

    it "raises an error for an invalid color" do
      expect { described_class.color(:invalid_color) }.to raise_error(ArgumentError)
    end
  end

  describe ".style" do
    it "returns the styled string" do
      expect(described_class.style(:bold, "foo")).to eq("\e[1mfoo\e[0m")
      expect(described_class.style(:italic, "bar")).to eq("\e[3mbar\e[0m")
      expect(described_class.style(:underlined, "baz")).to eq("\e[4mbaz\e[0m")
    end

    it "returns the style code by itself if no string is provided" do
      expect(described_class.style(:bold)).to eq("\e[1m")
      expect(described_class.style(:italic)).to eq("\e[3m")
      expect(described_class.style(:underlined)).to eq("\e[4m")
    end

    it "raises an error for an invalid style" do
      expect { described_class.style(:foo) }.to raise_error(ArgumentError)
    end
  end
end
