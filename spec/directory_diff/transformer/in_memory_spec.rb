require "spec_helper"

describe DirectoryDiff::Transformer::InMemory do
  it_behaves_like "a directory transformer" do
    let(:source_directory) { current_directory }
    let(:target_directory) { new_directory }
  end
end
