# DirectoryDiff

This microlibrary implements employee directory diffing between two versions. It generates a list of operations that need to be performed to transform the directory in version 1 to version 2.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'directory_diff'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install directory_diff

## Usage

```ruby
# Extract out current directory from the database into memory
# into a format that's similar to the incoming CSV, i.e.
# full name, email, phone number, assistant email
existing_directory = [
  ["Kamal Mahyuddin", "kamal@envoy.com", "415-555-1234", "adolfo@envoy.com"],
  ["Adolfo Builes", "adolfo@envoy.com", "415-666-9999", nil]
]

csv_data = [
  ["Kamal Mahyuddin", "kamal@envoy.com", "415-555-1234", "adolfo@envoy.com"],
  ["Adolfo Builes-Ramirez", "adolfo@envoy.com", "415-666-9999", "matthew@envoy.com"],
  ["Matthew Johnston", "matthew@envoy.com", "415-777-8888", nil]
]

operations = DirectoryDiff.transform(existing_directory).into(csv_data)
# => [
#      [:insert, "Matthew Johnston", "matthew@envoy.com", "415-777-8888", nil],
#      [:update, "Adolfo Builes-Ramirez", "adolfo@envoy.com", "415-666-9999", "matthew@envoy.com"],
#      [:noop, "Kamal Mahyuddin", "kamal@envoy.com", "415-555-1234", "adolfo@envoy.com"]
#    ]
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/envoy/directory_diff. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

