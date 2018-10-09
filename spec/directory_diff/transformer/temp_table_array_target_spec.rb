require "spec_helper"

describe DirectoryDiff::Transformer::TempTable, "target directory coming in as array" do
  it_behaves_like "a directory transformer", :temp_table do
    let(:source_directory) { current_directory_relation }
    let(:target_directory) { new_directory }
  end

  let(:table) do
    Temping.create :directory do
      with_columns do |t|
        t.string :name
        t.string :email
        t.string :phone_number
        t.string :assistants
      end
    end
  end

  let(:current_directory_relation) do
    current_directory.each do |name, email, phone_number, assistants|
      table.create({
        name: name,
        email: email,
        phone_number: phone_number,
        assistants: assistants
      })
    end
    table.all
  end
end
