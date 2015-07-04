[![Gem Version](https://badge.fury.io/rb/ruby_mint.svg)](http://badge.fury.io/rb/ruby_mint)

# RubyMint

RubyMint is a gem to assist you with getting information from Mint.com's API.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ruby_mint'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ruby_mint

## Usage

# Initiate the Gem

RubyMint must be initiated using an email address and password. Prior to making
any calls to the API, you must also login.

```ruby
ruby_mint = RubyMint.new('myemail@foobar.com', 'mysecretpassword')
ruby_mint.login
```

# Refreshing Data

Mint.com does not keep financial data 100% up to date, so if you want to get the most recent
account and transaction data you must first refresh the data. Once a refresh has been
initiated, it takes at least a few seconds for Mint.com to complete. There is also a method
to check refresh status.

```ruby
ruby_mint.initiate_account_refresh
ruby_mint.refreshing?
```

For convenience, you can also include a block to execute once refreshing is complete. There is
an optional parameter to indicate how many seconds to wait between calls to check if the Mint.com
is still refreshing.

```ruby
ruby_mint.initiate_account_refresh(3) do
  # Get your mint data once refresh is complete
  puts "Refresh complete!"
end
```

# Account Data

Account data is returned as a hash.

```ruby
accounts = ruby_mint.accounts
```

# Transaction Data

Transactions can be obtained as either CSV or JSON data.

CSV is a list of all transactions as a CSV dump.

NOTE: Breaking change from v0.1 Old transactions method is now transactions_csv

```ruby
transactions_csv = ruby_mint.transactions_csv
```

JSON data must specify a date range and has the option to include pending transactions
or to include a search term. Mint only returns a transaction date without a time. Date
range is inclusive.

```ruby
# Get all transactions from May 1, 2015 until now
transactions = ruby_mint.transactions Time.parse("2015-05-01")

# Get all transactions for the month of May
transactions = ruby_mint.transactions Time.parse("2015-05-01"), Time.parse("2015-05-31")

# Include pending transactions
transactions = ruby_mint.transactions Time.parse("2015-05-01"), Time.parse("2015-05-31"), 'include_pending' => true

# Include a search term
transactions = ruby_mint.transactions Time.parse("2015-05-01"), Time.parse("2015-05-31"), 'search_term' => 'coffee'
```

## Contributing

1. Fork it ( https://github.com/nickmarrone/ruby_mint/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
