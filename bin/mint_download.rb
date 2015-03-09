require 'ruby_mint'
require 'csv'
require 'io/console'

def print_usage
    puts <<-USAGE
Usage: ruby #{__FILE__} <-a=account_output> <-t=transaction_output>
* -a=account_output:     CSV file to append account data to (default to mint_accounts.csv)
* -t=transaction_output: CSV file to write transaction data to (default to mint_transactions.csv)
    USAGE
    exit
end

def fail!(error_msg)
  puts "Error: #{error_msg}"
  print_usage
end

accounts_file = nil
transactions_file = nil

if ARGV.length == 0
  accounts_file = "mint_accounts.csv"
end

ARGV.each do |arg|
  command, filename = arg.split('=')
  case command
  when '-a'
    accounts_file = filename
  when '-t'
    transactions_file = filename
  else
    print_usage
    exit
  end
end

# Get username and password
print "Email: "
email = STDIN.gets.chomp

print "Password: "
password = STDIN.noecho(&:gets).chomp
print "\n"

ruby_mint = RubyMint.new(email, password)

puts "Logging in..."
ruby_mint.login

accounts = nil
transactions = nil
puts "Refreshing account..."

ruby_mint.initiate_account_refresh do
  if accounts_file
    puts "Downloading accounts..."
    accounts = ruby_mint.accounts
  end

  if transactions_file
    puts "Downloading transactions..."
    transactions = ruby_mint.transactions
  end
end

puts "Writing data..."
timestamp = Time.now.strftime("%Y-%m-%d-%H%M")

if accounts_file
  # Check if file already exists
  file_exists = File.file?(accounts_file)

  CSV.open(accounts_file, "a") do |csv|
    if !file_exists
      csv << ['id', 'timestamp', 'name', 'subName', 'class', 'value', 'currentBalance']
    end

    accounts.each do |account|
      csv << [
        account["id"],
        timestamp,
        account["fiName"],
        account["accountName"],
        account["klass"],
        account["value"],
        account["currentBalance"]]
    end
  end
end

if transactions_file
  # Write transactions to file
  File.open(transactions_file, "w") do |output|
    output.puts transactions
  end
end

puts "Complete!"
