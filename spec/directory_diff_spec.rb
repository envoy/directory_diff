require 'spec_helper'

describe DirectoryDiff do
  it 'has a version number' do
    expect(DirectoryDiff::VERSION).not_to be nil
  end

  describe '#transform' do
    it 'requires an argument' do
      expect { DirectoryDiff.transform }.to raise_error(ArgumentError)
    end

    it 'requires an enumerable' do
      expect { DirectoryDiff.transform(1) }.to raise_error(ArgumentError)
      expect { DirectoryDiff.transform([]) }.not_to raise_error
    end

    it 'responds to #into' do
      expect(DirectoryDiff.transform([]).respond_to?(:into)).to be_truthy
    end
  end
end
