# frozen_string_literal: true

require 'rails_helper'

describe DesignManagement::Design do
  describe 'relations' do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:issue) }
    it { is_expected.to have_many(:design_versions) }
    it { is_expected.to have_many(:versions) }
  end

  describe 'validations' do
    subject(:design) { build(:design) }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:issue) }
    it { is_expected.to validate_presence_of(:filename) }
    it { is_expected.to validate_uniqueness_of(:filename).scoped_to(:issue_id) }

    it "validates that the file is an image" do
      design.filename = "thing.txt"

      expect(design).not_to be_valid
      expect(design.errors[:filename].first)
        .to match /Only these extensions are supported/
    end
  end

  describe "#new_design?" do
    set(:versions) { create(:design_version) }
    set(:design) { create(:design, versions: [versions]) }

    it "is false when there are versions" do
      expect(design.new_design?).to be_falsy
    end

    it "is true when there are no versions" do
      expect(build(:design).new_design?).to be_truthy
    end

    it "does not cause extra queries when versions are loaded" do
      design.versions.map(&:id)

      expect { design.new_design? }.not_to exceed_query_limit(0)
    end

    it "causes a single query when there versions are not loaded" do
      design.reload

      expect { design.new_design? }.not_to exceed_query_limit(1)
    end
  end

  describe "#full_path" do
    it "builds the full path for a design" do
      design = build(:design, filename: "hello.jpg")
      expected_path = "#{DesignManagement.designs_directory}/issue-#{design.issue.iid}/hello.jpg"

      expect(design.full_path).to eq(expected_path)
    end
  end
end
