shared_examples "a directory transformer" do |processor|
  describe '#into' do
    subject do
      DirectoryDiff.transform(source_directory)
        .into(target_directory, options.merge(processor: processor))
    end
    let(:options) { {} }

    context 'the current version is an empty directory' do
      let(:current_directory) { [] }
      let(:new_directory) do
        [
          ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil, 'foo'],
          ['Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil],
          ['Adolfo Builes', 'adolfo@envoy.com', nil, nil]
        ]
      end

      it 'returns :insert ops for each row and passes through extra fields untouched' do
        expect(subject).to eq([
          [:insert, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil, 'foo'],
          [:insert, 'Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil],
          [:insert, 'Adolfo Builes', 'adolfo@envoy.com', nil, nil]
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
      let(:new_directory) { [] }

      it 'returns :delete ops' do
        expect(subject).to eq([
          [:delete, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil],
          [:delete, 'Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil]
        ])
      end
    end

    context 'both versions are empty' do
      let(:current_directory) { [] }
      let(:new_directory) { [] }

      it 'returns no ops' do
        expect(subject).to eq([])
      end
    end

    context 'the current version is exactly the same as the new directory except for the extra field' do
      let(:current_directory) do
        [
          ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil],
          ['Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil]
        ]
      end
      let(:new_directory) do
        [
          ['Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil, 'foo'],
          ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil]
        ]
      end

      it 'returns :noops ops' do # reordered to show order follows csv
        expect(subject).to eq([
          [:noop, 'Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil, 'foo'],
          [:noop, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil]
        ])
      end
    end

    context 'the current version is exactly the same as the new directory' do
      let(:current_directory) do
        [
          ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil],
          ['Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil]
        ]
      end
      let(:new_directory) do
        [
          ['Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil],
          ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil]
        ]
      end

      it 'returns :noops ops' do # reordered to show order follows csv
        expect(subject).to eq([
          [:noop, 'Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil],
          [:noop, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil]
        ])
      end

      context "when skip_noop option is passed in" do
        let(:options) { { skip_noop: true } }

        it 'returns empty array' do
          expect(subject).to eq([])
        end
      end
    end

    context 'the current version is exactly the same as the new directory (but with different casing on emails)' do
      let(:current_directory) do
        [
          ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil],
          ['Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil]
        ]
      end
      let(:new_directory) do
        [
          ['Matthew Johnston', 'Matthew@envoy.com', '415-441-3232', nil],
          ['Kamal Mahyuddin', 'Kamal@envoy.com', '415-935-3143', nil]
        ]
      end

      it 'returns :noops ops' do # reordered to show order follows csv
        expect(subject).to eq([
          [:noop, 'Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil],
          [:noop, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil]
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

      context "in the name field" do
        let(:new_directory) do
          [
            ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil],
            ['Adolfito Builes', 'adolfo@envoy.com', '415-232-4232', nil],
            ['Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil]
          ]
        end

        it 'returns :update op' do
          expect(subject).to eq([
            [:noop, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil],
            [:update, 'Adolfito Builes', 'adolfo@envoy.com', '415-232-4232', nil],
            [:noop, 'Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil]
          ])
        end
      end

      context "in the phone number field" do
        let(:new_directory) do
          [
            ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil],
            ['Adolfo Builes', 'adolfo@envoy.com', '415-232-4232', nil],
            ['Matthew Johnston', 'matthew@envoy.com', '555-555-5555', nil]
          ]
        end

        it 'returns :update op' do
          expect(subject).to eq([
            [:noop, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil],
            [:noop, 'Adolfo Builes', 'adolfo@envoy.com', '415-232-4232', nil],
            [:update, 'Matthew Johnston', 'matthew@envoy.com', '555-555-5555', nil]
          ])
        end
      end

      context "in both name and phone number fields" do
        let(:new_directory) do
          [
            ['Kamalcito Mahyuddin', 'kamal@envoy.com', '555-555-5555', nil],
            ['Adolfo Builes', 'adolfo@envoy.com', '415-232-4232', nil],
            ['Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil]
          ]
        end

        it 'returns a single :update op for an update in both name and phone number' do
          expect(subject).to eq([
            [:update, 'Kamalcito Mahyuddin', 'kamal@envoy.com', '555-555-5555', nil],
            [:noop, 'Adolfo Builes', 'adolfo@envoy.com', '415-232-4232', nil],
            [:noop, 'Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil]
          ])
        end
      end
    end

    context 'there are duplicate emails in new' do
      context 'which dont exist in current' do
        let(:current_directory) { [] }
        let(:new_directory) do
          [
            ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil],
            ['Adolfo Builes', 'adolfo@envoy.com', '415-232-4232', nil],
            ['Adolfo Dupe', 'adolfo@envoy.com', '415-441-3232', nil]
          ]
        end

        it 'returns a single insert for the last one' do
          expect(subject).to eq([
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

        context "when the last one is unchanged" do
          let(:new_directory) do
            [
              ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil],
              ['Adolfo Updated', 'adolfo@envoy.com', '415-232-4232', nil],
              ['Adolfo Builes', 'adolfo@envoy.com', '415-232-4232', nil],
              ['Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil]
            ]
          end

          it 'returns noop if last one is unchanged' do
            expect(subject).to eq([
              [:noop, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil],
              [:noop, 'Adolfo Builes', 'adolfo@envoy.com', '415-232-4232', nil],
              [:noop, 'Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil]
            ])
          end
        end

        context "when the last one has updates" do
          let(:new_directory) do
            [
              ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil],
              ['Adolfo Builes', 'adolfo@envoy.com', '415-232-4232', nil],
              ['Adolfo Updated', 'adolfo@envoy.com', '415-232-4232', nil],
              ['Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil]
            ]
          end

          it 'returns update if last one has updates' do
            expect(subject).to eq([
              [:noop, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil],
              [:update, 'Adolfo Updated', 'adolfo@envoy.com', '415-232-4232', nil],
              [:noop, 'Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil]
            ])
          end
        end
      end
    end

    context 'with assistant' do
      context 'and current directory is empty' do
        let(:current_directory) { [] }

        context 'new directory has assistant email, but no assistant record' do
          let(:new_directory) do
            [
              ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'adolfo@envoy.com']
            ]
          end

          it 'does not return an :insert op for the assistant, and nils out the assistant' do
            expect(subject).to eq([
              [:insert, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil]
            ])
          end
        end

        context 'new directory has circular reference' do
          let(:new_directory) do
            [
              ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'adolfo@envoy.com'],
              ['Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', 'matthew@envoy.com'],
              ['Matthew Johnston', 'matthew@envoy.com', '415-441-3232', 'kamal@envoy.com']
            ]
          end

          it 'returns an :insert op for kamal, adolfo and matthew' do
            expect(subject).to eq([
              [:insert, 'Matthew Johnston', 'matthew@envoy.com', '415-441-3232', 'kamal@envoy.com'],
              [:insert, 'Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', 'matthew@envoy.com'],
              [:insert, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'adolfo@envoy.com']
            ])
          end
        end

        context 'new directory has assistant email, and assistant record comes after' do
          let(:new_directory) do
            [
              ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'adolfo@envoy.com'],
              ['Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', nil]
            ]
          end

          it 'returns an :insert op for the assistant before the employee' do
            expect(subject).to eq([
              [:insert, 'Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', nil],
              [:insert, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'adolfo@envoy.com']
            ])
          end
        end

        context 'new directory has assistant email, and assistant record comes before' do
          let(:new_directory) do
            [
              ['Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', nil],
              ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'adolfo@envoy.com']
            ]
          end

          it 'returns an :insert op for the assistant before the employee' do
            expect(subject).to eq([
              [:insert, 'Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', nil],
              [:insert, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'adolfo@envoy.com']
            ])
          end
        end

        context 'new directory has same email as assistant email' do
          let(:new_directory) do
            [
              ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'kamal@envoy.com']
            ]
          end

          it 'does not return multiple :insert op for the same employee, and nils out the assistant' do
            expect(subject).to eq([
              [:insert, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil]
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
          context "and no change to employee record" do
            let(:new_directory) do
              [
                ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'adolfo@envoy.com']
              ] 
            end

            it 'returns a :noop op for the employee, and nils out the assistant' do
              expect(subject).to eq([
                [:noop, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil]
              ])
            end
          end

          context "and employee record changed" do
            let(:new_directory) do
              [
                ['Kamal Changed', 'kamal@envoy.com', '415-935-3143', 'adolfo@envoy.com']
              ] 
            end

            it 'returns an :update op, nils out the assistant, when some other attr changed' do
              expect(subject).to eq([
                [:update, 'Kamal Changed', 'kamal@envoy.com', '415-935-3143', nil]
              ])
            end
          end
        end

        context 'new directory has assistant email, and assistant record comes after' do
          let(:new_directory) do
            [
              ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'adolfo@envoy.com'],
              ['Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', nil]
            ] 
          end

          it 'returns an :insert op for the assistant before the employee' do
            expect(subject).to eq([
              [:insert, 'Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', nil],
              [:update, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'adolfo@envoy.com']
            ])
          end
        end
      end

      context 'and current directory contains an employee with assistant' do
        let(:current_directory) do
          [
            ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'adolfo@envoy.com'],
            ['Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', nil]
          ]
        end

        context 'new directory doesnt set assistant email in last column' do
          context 'and assistant is still included' do
            let(:new_directory) do
              [
                ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil],
                ['Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', nil]
              ] 
            end

            it 'returns :noop, because assistant column only sets, doesnt delete' do
              expect(subject).to eq([
                [:noop, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil],
                [:noop, 'Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', nil]
              ])
            end
          end

          context 'but assistant is no longer included' do
            let(:new_directory) do
              [
                ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil]
              ]
            end

            it 'returns :noop for kamal' do
              expect(subject).to eq([
                [:noop, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil],
                [:delete, 'Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', nil]
              ])
            end
          end
        end

        context 'new directory sets a new assistant in last column' do
          context 'and assistant is still included' do
            let(:new_directory) do
              [
                ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'matthew@envoy.com'],
                ['Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', nil],
                ['Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil]
              ] 
            end

            it 'returns :update for kamal, :noop for assistant, :insert for new assistant' do
              expect(subject).to eq([
                [:insert, 'Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil],
                [:update, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'matthew@envoy.com'],
                [:noop, 'Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', nil]
              ])
            end
          end

          context 'and assistant is no longer included' do
            let(:new_directory) do
              [
                ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'matthew@envoy.com'],
                ['Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil]
              ] 
            end

            it 'returns :update for kamal, :delete for old assistant, :insert for new assistant' do
              expect(subject).to eq([
                [:insert, 'Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil],
                [:update, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'matthew@envoy.com'],
                [:delete, 'Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', nil]
              ])
            end
          end
        end

        context 'new directory sets a same email in last column' do
          let(:new_directory) do
            [
              ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'kamal@envoy.com'],
              ['Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', nil]
            ] 
          end

          it 'returns noop for kamal, assistant' do
            expect(subject).to eq([
              [:noop, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil],
              [:noop, 'Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', nil]
            ])
          end
        end

        context 'new directory sets same assistant email in last column' do
          let(:new_directory) do
            [
              ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'adolfo@envoy.com'],
              ['Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', nil]
            ] 
          end

          it 'returns noop for kamal, assistant' do
            expect(subject).to eq([
              [:noop, 'Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', nil],
              [:noop, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'adolfo@envoy.com']
            ])
          end
        end
      end
    end

    context 'with multiple assistants' do
      context 'and current directory is empty' do
        let(:current_directory) { [] }

        context 'new directory has assistant emails, but no assistant records' do
          let(:new_directory) do
            [
              ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'adolfo@envoy.com,tristan@envoy.com']
            ]
          end

          it 'does not return an :insert op for the assistants, and nils out the assistant' do
            expect(subject).to eq([
              [:insert, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil]
            ])
          end
        end

        context 'new directory has assistant emails, but no assistant records for one assistant' do
          let(:new_directory) do
            [
              ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'adolfo@envoy.com,tristan@envoy.com'],
              ['Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', nil]
            ] 
          end

          it 'returns an :insert op for employee and assistants, and sets the assistant that does exist' do
            expect(subject).to eq([
              [:insert, 'Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', nil],
              [:insert, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'adolfo@envoy.com']
            ])
          end
        end

        context 'new directory has circular reference' do
          let(:new_directory) do
            [
              ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'adolfo@envoy.com,matthew@envoy.com'],
              ['Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', 'matthew@envoy.com'],
              ['Matthew Johnston', 'matthew@envoy.com', '415-441-3232', 'kamal@envoy.com']
            ] 
          end

          it 'returns an :insert op for kamal, adolfo, and matthew' do
            expect(subject).to eq([
              [:insert, 'Matthew Johnston', 'matthew@envoy.com', '415-441-3232', 'kamal@envoy.com'],
              [:insert, 'Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', 'matthew@envoy.com'],
              [:insert, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'adolfo@envoy.com,matthew@envoy.com']
            ])
          end
        end

        context 'new directory has assistant emails, and assistant records come after' do
          let(:new_directory) do
            [
              ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'adolfo@envoy.com,matthew@envoy.com'],
              ['Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', nil],
              ['Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil]
            ] 
          end

          it 'returns an :insert op for the assistants before the employee' do
            expect(subject).to eq([
              [:insert, 'Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', nil],
              [:insert, 'Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil],
              [:insert, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'adolfo@envoy.com,matthew@envoy.com']
            ])
          end
        end

        context 'new directory has assistant emails, and assistant records come before' do
          let(:new_directory) do
            [
              ['Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', nil],
              ['Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil],
              ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'adolfo@envoy.com,matthew@envoy.com']
            ] 
          end

          it 'returns an :insert op for the assistants before the employee' do
            expect(subject).to eq([
              [:insert, 'Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', nil],
              [:insert, 'Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil],
              [:insert, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'adolfo@envoy.com,matthew@envoy.com']
            ])
          end
        end

        context 'new directory has same email as assistant emails' do
          let(:new_directory) do
            [
              ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'kamal@envoy.com,kamal@envoy.com']
            ] 
          end

          it 'does not return multiple :insert op for the same employee, and nils out the assistants' do
            expect(subject).to eq([
              [:insert, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil]
            ])
          end
        end
      end

      context 'and current directory contains an employee without assistants' do
        let(:current_directory) do
          [
            ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil]
          ]
        end

        context 'new directory has assistant emails, but no assistant records' do
          context "when employee record is unchanged" do
            let(:new_directory) do
              [
                ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'adolfo@envoy.com,matthew@envoy.com']
              ]
            end

            it 'returns a :noop op for the assistants, and nils out the assistants, when nothing else changed' do
              expect(subject).to eq([
                [:noop, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil]
              ])
            end
          end

          context "when employee record is changed" do
            let(:new_directory) do
              [
                  ['Kamal Changed', 'kamal@envoy.com', '415-935-3143', 'adolfo@envoy.com,matthew@envoy.com']
              ]
            end

            it 'returns an :update op, nils out the assistants, when some other attr changed' do
              expect(subject).to eq([
                [:update, 'Kamal Changed', 'kamal@envoy.com', '415-935-3143', nil]
              ])
            end
          end
        end

        context 'new directory has assistant emails, but no assistant records for one assistant' do
          let(:new_directory) do
            [
              ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'adolfo@envoy.com,tristan@envoy.com'],
              ['Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', nil]
            ]
          end

          it 'returns an :update op for employee and :insert for assistant, and sets the assistant that does exist' do
            expect(subject).to eq([
              [:insert, 'Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', nil],
              [:update, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'adolfo@envoy.com']
            ])
          end
        end

        context 'new directory has assistant emails, and assistant records come after' do
          let(:new_directory) do
            [
              ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'adolfo@envoy.com,matthew@envoy.com'],
              ['Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', nil],
              ['Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil]
            ]
          end

          it 'returns an :insert op for the assistant before the employee' do
            expect(subject).to eq([
              [:insert, 'Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', nil],
              [:insert, 'Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil],
              [:update, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'adolfo@envoy.com,matthew@envoy.com']
            ])
          end
        end
      end

      context 'and current directory contains an employee with assistants' do
        let(:current_directory) do
          [
            ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'adolfo@envoy.com,matthew@envoy.com'],
            ['Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', nil],
            ['Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil]
          ]
        end

        context 'new directory doesnt set assistant emails in last column' do
          context 'and assistants are still included' do
            let(:new_directory) do
              [
                ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil],
                ['Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', nil],
                ['Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil]
              ]
            end

            it 'returns :noop, because assistants column only sets, doesnt delete' do
              expect(subject).to eq([
                [:noop, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil],
                [:noop, 'Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', nil],
                [:noop, 'Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil]
              ])
            end
          end

          context 'but assistants are no longer included' do
            let(:new_directory) do
              [
                ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil]
              ]
            end

            it 'returns :noop for kamal' do
              expect(subject).to eq([
                [:noop, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil],
                [:delete, 'Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', nil],
                [:delete, 'Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil]
              ])
            end
          end
        end

        context 'new directory sets new assistants in last column' do
          context 'and assistants are still included' do
            let(:new_directory) do
              [
                ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'matthew@envoy.com,tristan@envoy.com'],
                ['Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', nil],
                ['Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil],
                ['Tristan Dunn', 'tristan@envoy.com', '415-441-3235', nil]
              ] 
            end

            it 'returns :update for kamal, :noop for assistants, :insert for new assistant' do
              expect(subject).to eq([
                [:noop, 'Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil],
                [:insert, 'Tristan Dunn', 'tristan@envoy.com', '415-441-3235', nil],
                [:update, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'matthew@envoy.com,tristan@envoy.com'],
                [:noop, 'Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', nil]
              ])
            end
          end

          context 'and assistants are no longer included' do
            let(:new_directory) do
              [
                ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'tristan@envoy.com,dog@envoy.com'],
                ['Tristan Dunn', 'tristan@envoy.com', '415-441-3235', nil],
                ['Dog Milo', 'dog@envoy.com', '415-441-3239', nil]
              ] 
            end

            it 'returns :update for kamal, :delete for old assistants, :insert for new assistants' do
              expect(subject).to eq([
                [:insert, 'Tristan Dunn', 'tristan@envoy.com', '415-441-3235', nil],
                [:insert, 'Dog Milo', 'dog@envoy.com', '415-441-3239', nil],
                [:update, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'tristan@envoy.com,dog@envoy.com'],
                [:delete, 'Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', nil],
                [:delete, 'Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil]
              ])
            end
          end
        end

        context 'new directory sets same emails in last column' do
          let(:new_directory) do
            [
              ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'kamal@envoy.com'],
              ['Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', nil],
              ['Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil]
            ]
          end

          it 'returns noop for kamal, assistants' do
            expect(subject).to eq([
              [:noop, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', nil],
              [:noop, 'Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', nil],
              [:noop, 'Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil]
            ])
          end
        end

        context 'new directory sets same assistant emails in last column' do
          let(:new_directory) do
            [
              ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'adolfo@envoy.com,matthew@envoy.com'],
              ['Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', nil],
              ['Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil]
            ] 
          end

          it 'returns noop for kamal, assistants' do
            expect(subject).to eq([
              [:noop, 'Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', nil],
              [:noop, 'Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil],
              [:noop, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'adolfo@envoy.com,matthew@envoy.com']
            ])
          end
        end

        context 'new directory sets a subset of assistant emails in last column' do
          let(:new_directory) do
            [
              ['Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'adolfo@envoy.com'],
              ['Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', nil],
              ['Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil]
            ] 
          end

          it 'returns noop for kamal, assistants' do
            expect(subject).to eq([
              [:noop, 'Adolfo Builes', 'adolfo@envoy.com', '415-935-3143', nil],
              [:update, 'Kamal Mahyuddin', 'kamal@envoy.com', '415-935-3143', 'adolfo@envoy.com'],
              [:noop, 'Matthew Johnston', 'matthew@envoy.com', '415-441-3232', nil],
            ])
          end
        end
      end
    end
  end
end
