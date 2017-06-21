# TwilioApiMock

This gem mocks the twilio-ruby gem functionality of [creating SMS messages](http://twilio-ruby.readthedocs.io/en/latest/usage/messages.html#sending-a-text-message) and [retrieving a filtered list of SMS messages](http://twilio-ruby.readthedocs.io/en/latest/usage/messages.html#filtering-your-messages). It's designed to act as a     stand-in for the twilio-ruby gem in non-production environments.

A created message is stored as a hash in Redis, and a composite index is used to enable lexicographical searching by phone number and date sent.

The `TwilioApiMock::Messages` class requires a redis instance to be passed in during initialization.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'twilio_api_mock'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install twilio_api_mock

## Usage

While the twilio-ruby create message method does not take `date_sent`, having the ability to set that parameter is useful since this gem is to designed for use during development.

```
messages = TwilioApiMock::Messages.new(redis_instance)

messages.create(
  to: "+13216851234",
  from: "+15555555555",
  body: "Hello!",
  date_sent: Time.new(2017, 6, 1, 15, 0, 10, '+00:00')
)

messages.list(
  to: "+15466758723",
  date_sent: "2017-06-01"
)
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/angelkbrown/twilio-api-mock. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

