require 'spec_helper'

describe DirectoryDiff::Transform do
  describe '#into' do
    let(:transform) { DirectoryDiff::Transform.new(current_directory) }
    let(:current_directory) { [] }

    it 'requires an argument' do
      expect { transform.into }.to raise_error(ArgumentError)
    end

    it 'requires an enumerable' do
      expect { transform.into(1) }.to raise_error
      expect { transform.into([]) }.not_to raise_error
    end

    context 'the current version is an empty directory' do
      let(:current_directory) { [] }

      it 'returns :insert ops for each row' do
        expect(transform.into([
          ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143'],
          ['Matthew Johnston', 'matthew@envoy.com', '415-441-3232']
        ])).to eq([
          [:insert, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143'],
          [:insert, 'Matthew Johnston', 'matthew@envoy.com', '415-441-3232']
        ])
      end
    end

    context 'the new version is an empty directory' do
      let(:current_directory) do
        [
          ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143'],
          ['Matthew Johnston', 'matthew@envoy.com', '415-441-3232']
        ]
      end

      it 'returns :delete ops' do
        expect(transform.into([])).to eq([
          [:delete, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143'],
          [:delete, 'Matthew Johnston', 'matthew@envoy.com', '415-441-3232']
        ])
      end
    end

    context 'both versions are empty' do
      let(:current_directory) { [] }

      it 'returns no ops' do
        expect(transform.into([])).to eq([])
      end
    end

    context 'the current version is exactly the same as the new directory' do
      let(:current_directory) do
        [
          ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143'],
          ['Matthew Johnston', 'matthew@envoy.com', '415-441-3232']
        ]
      end

      it 'returns :noops ops' do # reordered to show order doesn't matter
        expect(transform.into([
          ['Matthew Johnston', 'matthew@envoy.com', '415-441-3232'],
          ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143']
        ])).to eq([
          [:noop, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143'],
          [:noop, 'Matthew Johnston', 'matthew@envoy.com', '415-441-3232']
        ])
      end
    end

    context 'the new version has updates to the records' do
      let(:current_directory) do
        [
          ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143'],
          ['Adolfo Builes', 'adolfo@envoy.com', '415-232-4232'],
          ['Matthew Johnston', 'matthew@envoy.com', '415-441-3232']
        ]
      end

      it 'returns :update op for an update in name' do
        new_directory = current_directory.clone
        new_directory[1][0] = 'Adolfito Builes'

        expect(transform.into(new_directory)).to eq([
          [:noop, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143'],
          [:update, 'Adolfito Builes', 'adolfo@envoy.com', '415-232-4232'],
          [:noop, 'Matthew Johnston', 'matthew@envoy.com', '415-441-3232']
        ])
      end

      it 'returns :update op for an update in phone number' do
        new_directory = current_directory.clone
        new_directory[0][2] = '555-555-5555'

        expect(transform.into(new_directory)).to eq([
          [:noop, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143'],
          [:noop, 'Adolfo Builes', 'adolfo@envoy.com', '415-232-4232'],
          [:update, 'Matthew Johnston', 'matthew@envoy.com', '555-555-5555']
        ])
      end

      it 'returns a single :update op for an update in both name and phone number' do
        new_directory = current_directory.clone
        new_directory[2][0] = 'Kamalcito Mahyuddin'
        new_directory[2][2] = '555-555-5555'

        expect(transform.into(new_directory)).to eq([
          [:update, 'Kamalcito Mahyuddin', 'kamal@envoy.com', '555-555-5555'],
          [:noop, 'Adolfo Builes', 'adolfo@envoy.com', '415-232-4232'],
          [:noop, 'Matthew Johnston', 'matthew@envoy.com', '415-441-3232']
        ])
      end
    end

    context 'there are duplicate emails in new' do
      context 'which dont exist in current' do
        it 'returns a single insert for the last one'
      end

      context 'which exists in current' do
        it 'returns noop if last one is unchanged'
        it 'returns update if last one has updates'
      end
    end

    context 'assistant support' do
      context 'assistant email does not exist in the new directory' do
        context 'and there are duplicate assistant records' do
          it 'picks the last assistant'
        end
      end
      context 'assistant email does not exist in current directory' do
        context 'and there are duplicate assistant records' do
          it 'picks the last assistant'
        end
      end
      context 'employee with no assistant in current is set an assistant in new'
      context 'employee with no assistant in current is set an assistant in new but it doesnt exist'
      context 'employee with assistant in current is set the same assistant in new'
      context 'employee with assistant in current is set the same assistant but it doesnt exist'
      context 'employee with assistant in current is set a different assistant in new'
      context 'employee with assistant in current is set a different assistant in new but it doesnt exist'
      context 'employee with assistant in current is not set an assistant in new'
    end
  end
end
