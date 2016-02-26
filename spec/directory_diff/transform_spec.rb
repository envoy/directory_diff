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
          ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil],
          ['Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil]
        ])).to eq([
          [:insert, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil],
          [:insert, 'Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil]
        ])
      end
    end

    context 'the new version is an empty directory' do
      let(:current_directory) do
        [
          ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil],
          ['Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil]
        ]
      end

      it 'returns :delete ops' do
        expect(transform.into([])).to eq([
          [:delete, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil],
          [:delete, 'Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil]
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
          ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil],
          ['Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil]
        ]
      end

      it 'returns :noops ops' do # reordered to show order doesn't matter
        expect(transform.into([
          ['Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil],
          ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil]
        ])).to eq([
          [:noop, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil],
          [:noop, 'Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil]
        ])
      end
    end

    context 'the new version has updates to the records' do
      let(:current_directory) do
        [
          ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil],
          ['Adolfo Builes', 'adolfo@envoy.com', '415-232-4232', nil],
          ['Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil]
        ]
      end

      it 'returns :update op for an update in name' do
        new_directory = [
          ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil],
          ['Adolfito Builes', 'adolfo@envoy.com', '415-232-4232', nil],
          ['Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil]
        ]

        expect(transform.into(new_directory)).to eq([
          [:noop, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil],
          [:update, 'Adolfito Builes', 'adolfo@envoy.com', '415-232-4232', nil],
          [:noop, 'Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil]
        ])
      end

      it 'returns :update op for an update in phone number' do
        new_directory = [
          ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil],
          ['Adolfo Builes', 'adolfo@envoy.com', '415-232-4232', nil],
          ['Matthew Johnston', 'matthew@envoy.com', '555-555-5555', nil]
        ]

        expect(transform.into(new_directory)).to eq([
          [:noop, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil],
          [:noop, 'Adolfo Builes', 'adolfo@envoy.com', '415-232-4232', nil],
          [:update, 'Matthew Johnston', 'matthew@envoy.com', '555-555-5555', nil]
        ])
      end

      it 'returns a single :update op for an update in both name and phone number' do
        new_directory = [
          ['Kamalcito Mahyuddin', 'kamal@envoy.com', '555-555-5555', nil],
          ['Adolfo Builes', 'adolfo@envoy.com', '415-232-4232', nil],
          ['Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil]
        ]

        expect(transform.into(new_directory)).to eq([
          [:update, 'Kamalcito Mahyuddin', 'kamal@envoy.com', '555-555-5555', nil],
          [:noop, 'Adolfo Builes', 'adolfo@envoy.com', '415-232-4232', nil],
          [:noop, 'Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil]
        ])
      end
    end

    context 'there are duplicate emails in new' do
      context 'which dont exist in current' do
        let(:current_directory) { [] }

        it 'returns a single insert for the last one' do
          new_directory = [
            ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil],
            ['Adolfo Builes', 'adolfo@envoy.com', '415-232-4232', nil],
            ['Adolfo Dupe', 'adolfo@envoy.com', '415-441-3232', nil]
          ]

          expect(transform.into(new_directory)).to eq([
            [:insert, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil],
            [:insert, 'Adolfo Dupe', 'adolfo@envoy.com', '415-441-3232', nil]
          ])
        end
      end

      context 'which exists in current' do
        let(:current_directory) do
          [
            ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil],
            ['Adolfo Builes', 'adolfo@envoy.com', '415-232-4232', nil],
            ['Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil]
          ]
        end

        it 'returns noop if last one is unchanged' do
          new_directory = [
            ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil],
            ['Adolfo Updated', 'adolfo@envoy.com', '415-232-4232', nil],
            ['Adolfo Builes', 'adolfo@envoy.com', '415-232-4232', nil],
            ['Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil]
          ]

          expect(transform.into(new_directory)).to eq([
            [:noop, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil],
            [:noop, 'Adolfo Builes', 'adolfo@envoy.com', '415-232-4232', nil],
            [:noop, 'Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil]
          ])
        end

        it 'returns update if last one has updates' do
          new_directory = [
            ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil],
            ['Adolfo Builes', 'adolfo@envoy.com', '415-232-4232', nil],
            ['Adolfo Updated', 'adolfo@envoy.com', '415-232-4232', nil],
            ['Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil]
          ]

          expect(transform.into(new_directory)).to eq([
            [:noop, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil],
            [:update, 'Adolfo Updated', 'adolfo@envoy.com', '415-232-4232', nil],
            [:noop, 'Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil]
          ])
        end
      end
    end

    context 'with assistants' do
      context 'and current directory is empty' do
        let(:current_directory) { [] }

        context 'new directory has assistant email, but no assistant record' do
          it 'does not return an :insert op for the assistant, and nils out the assistant' do
            expect(transform.into([
              ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'adolfo@envoy.com']
            ])).to eq([
              [:insert, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil]
            ])
          end
        end

        context 'new directory has assistant email, and assistant record comes after' do
          it 'returns an :insert op for the assistant before the employee' do
            expect(transform.into([
              ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'adolfo@envoy.com'],
              ['Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', nil]
            ])).to eq([
              [:insert, 'Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', nil],
              [:insert, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'adolfo@envoy.com']
            ])
          end
        end
      end

      context 'and current directory contains an employee without assistant' do
        let(:current_directory) do
          [
            ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil]
          ]
        end

        context 'new directory has assistant email, but no assistant record' do
          it 'returns a :noop op for the assistant, and nils out the assistant, when nothing else changed' do
            expect(transform.into([
              ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'adolfo@envoy.com']
            ])).to eq([
              [:noop, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil]
            ])
          end

          it 'returns an :update op, nils out the assistant, when some other attr changed' do
            expect(transform.into([
              ['Kamal Changed', 'kamal@envoy.com', '415-935-3143', 'adolfo@envoy.com']
            ])).to eq([
              [:update, 'Kamal Changed', 'kamal@envoy.com', '415-935-3143', nil]
            ])
          end
        end

        context 'new directory has assistant email, and assistant record comes after' do
          it 'returns an :insert op for the assistant before the employee' do
            expect(transform.into([
              ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'adolfo@envoy.com'],
              ['Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', nil]
            ])).to eq([
              [:insert, 'Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', nil],
              [:update, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'adolfo@envoy.com']
            ])
          end
        end
      end

      # context 'and current directory contains an employee with assistant' do
      #   context 'and assistant is missing in new directory'
      # end

      # context 'and current directory contains just the assistant' do
      # end

      # context 'assistant email does not exist in the new directory' do
      #   context 'and there are duplicate assistant records' do
      #     it 'picks the last assistant'
      #   end
      # end
      # context 'assistant email does not exist in current directory' do
      #   context 'and there are duplicate assistant records' do
      #     it 'picks the last assistant'
      #   end
      # end

      # context 'employee with no assistant in current is set an assistant in new'
      # context 'employee with no assistant in current is set an assistant in new but it doesnt exist'
      # context 'employee with assistant in current is set the same assistant in new'
      # context 'employee with assistant in current is set the same assistant but it doesnt exist'
      # context 'employee with assistant in current is set a different assistant in new'
      # context 'employee with assistant in current is set a different assistant in new but it doesnt exist'
      # context 'employee with assistant in current is not set an assistant in new'
    end
  end
end
