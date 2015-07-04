require "ruby_mint/version"
require "mechanize"
require "json"

class RubyMintError < StandardError; end

class RubyMint
  JSON_HEADERS = { "accept" => "application/json" }

  ACCOUNT_TYPES = [
    "BANK",
    "CREDIT",
    "INVESTMENT",
    "LOAN",
    "MORTGAGE",
    "OTHER_PROPERTY",
    "REAL_ESTATE",
    "VEHICLE",
    "UNCLASSIFIED",
  ]

  # Initialize RubyMint
  #
  # @param username [String] usually an email address
  # @param password [String]
  def initialize(username, password)
    @username = username
    @password = password
    @request_id = 34

    @token = nil
  end

  # Login retrieves a user token from Mint.com
  def login
    response = agent.get("https://wwws.mint.com/login.event?task=L")
    raise RubyMintError.new("Unable to GET Mint login page.") if response.code != "200"

    response = agent.post("https://wwws.mint.com/getUserPod.xevent", { "username" => @username }, JSON_HEADERS)
    raise RubyMintError.new("Unable to POST to getUserPod.") if response.code != "200"

    query = {
      "username" => @username,
      "password" => @password,
      "task" => "L",
      "browser" => "firefox",
      "browserVersion" => "27",
      "os" => "Linux",
    }

    response = agent.post("https://wwws.mint.com/loginUserSubmit.xevent", query, JSON_HEADERS)
    if response.code != "200" || !response.body.include?("token")
      raise RubyMintError.new("Mint.com login failed. Response code: #{response.code}")
    end

    login_body = JSON.load(response.body)
    if !login_body || !login_body["sUser"] || !login_body["sUser"]["token"]
      raise RubyMintError.new("Mint.com login failed (no token in login response body).")
    end

    @token = login_body["sUser"]["token"]
  end

  # Check if user is logged in already by the presence of a token.
  #
  # @return [Boolean]
  def logged_in?
    !@token.nil?
  end

  # Request that Mint.com refresh its account and transaction data
  #
  # @param sleep_time [Integer] Num of seconds to wait between calls to refreshing? when block is passed
  # @param block [Block] Code to execute upon completion of of refreshing
  def initiate_account_refresh(sleep_time = 3)
    agent.post("https://wwws.mint.com/refreshFILogins.xevent", { "token" => @token }, JSON_HEADERS)
    if block_given?
      loop{ sleep sleep_time; break if !refreshing? }
      yield
    end
  end

  # Is Mint.com in the process of refreshing its data?
  #
  # @return [Boolean]
  def refreshing?
    response = agent.get("https://wwws.mint.com/userStatus.xevent", JSON_HEADERS)
    if response.code != "200" || !response.body.include?("isRefreshing")
      raise RubyMintError.new("Unable to check if account is refreshing.")
    end

    JSON.parse(response.body)["isRefreshing"]
  end

  # Get account data
  #
  # @param account_types [Array<String>] Type of accounts to retrieve. Defaults to all types.
  # @return [Hash]
  def accounts(account_types = ACCOUNT_TYPES)
    # Use a new request_id
    @request_id += 1

    account_query = {
      "input" => JSON.dump([{
        "args" => { "types" => account_types },
        "id" => @request_id.to_s,
        "service" => "MintAccountService",
        "task" => "getAccountsSorted",
      }])}

    # Use token to get list of accounts
    results = agent.post("https://wwws.mint.com/bundledServiceController.xevent?legacy=false&token=#{@token}", account_query, JSON_HEADERS)
    raise RubyMintError.new("Unable to obtain account information. Response code: #{results.code}") if results.code != "200"

    account_body = JSON.load(results.body)
    if !account_body || !account_body["response"] || !account_body["response"][@request_id.to_s] || !account_body["response"][@request_id.to_s]["response"]
      raise RubyMintError.new("Unable to obtain account information (no account information in response).")
    end

    account_body["response"][@request_id.to_s]["response"]
  end

  # Get transactions from mint. They are returned as CSV and include ALL
  # the transactions available
  #
  # @return [String] CSV of all transactions
  def transactions_csv
    results = agent.get("https://wwws.mint.com/transactionDownload.event", JSON_HEADERS)
    raise RubyMintError.new("Unable to obtain transactions.") if results.code != "200"
    raise RubyMintError.new("Non-CSV content returned.") if !results.header["content-type"].include?("text/csv")

    results.body
  end

  # Get transactions from mint. Returned as JSON. Paginate
  #
  # Options:
  #   include_pending [Boolean] default false
  #   search_term     [String]  default ""
  #
  # @param start_date [Time] get all transactions on or after this date
  # @param end_date   [Time] get all transactions up to and including this date
  # @param options    [Hash] options hash
  # @returns          [Array<Hash>] array of transactions
  def transactions(start_date, end_date = Time.now, options = {})
    include_pending = options.fetch('include_pending', false)
    search_term     = options.fetch('search_term', '')
    offset = 0
    results = []

    # Convert start and end dates 
    start_date = Time.local(start_date.year, start_date.month, start_date.day)
    end_date = Time.local(end_date.year, end_date.month, end_date.day)

    loop do
      next_page = transaction_page(offset, search_term)
      break if next_page.empty?

      # Filter out pending transactions
      if !include_pending
        next_page.reject!{ |t| t['isPending'] }
      end

      results.concat next_page
      break if earliest_mint_date(next_page) < start_date

      offset += next_page.count
    end

    # Filter by date
    results.select do |t|
      t['date'] >= start_date && t['date'] <= end_date
    end
  end


  private

  def agent
    @agent ||= Mechanize.new { |agent|
        agent.user_agent_alias = 'Linux Firefox'
    }
  end

  # Get a single page of transaction data. Mint always returns 50 transactions per page.
  def transaction_page(offset, search_term)
    # Example query: https://wwws.mint.com/app/getJsonData.xevent?queryNew=&offset=0&filterType=cash&acctChanged=T&task=transactions&rnd=1436026512488
    base_url = "https://wwws.mint.com/app/getJsonData.xevent"
    search_query = "?queryNew=#{URI.encode(search_term)}"
    offset_query = "&offset=#{offset}"
    transaction_query = "&filterType=cash&comparableType=8&task=transactions&rnd=#{random_number}"

    json_results = agent.get("#{base_url}#{search_query}#{offset_query}#{transaction_query}", JSON_HEADERS)
    raise RubyMintError.new("Unable to obtain transactions.") if json_results.code != "200"
    raise RubyMintError.new("Non-JSON content returned.") if !json_results.header["content-type"].include?("text/json")

    transform_transaction_times JSON.parse(json_results.body)['set'][0]['data']
  end

  # Mint returns transactions in two formats: "Mar 8" for this year, "10/08/14" for previous years (month/day/year).
  # Transform dates into ruby time objects.
  #
  # NOTE: Mint only returns the date of the transaction, there is no time
  #
  # @param transactions [Array<Hash>] array of transactions
  def transform_transaction_times(transactions)
    transactions.map do |t|
      t['date'] = (t['date'] =~ /\d+\/\d+\/\d+/ ? Time.strptime(t['date'], "%D") : Time.parse(t['date']))
      t
    end
  end

  # Get the earliest date from this set of transactions. Assumes they are in reverse order.
  #
  # @params transactions [Array<Hash>]
  # @returns [Time]
  def earliest_mint_date(transactions)
    transactions.last['date']
  end

  # Queries require a 12-digit random number
  def random_number
    # They are starting with 14, so I won't break the mold. Get 10 more.
    nums = (0..9).to_a
    result = "14"
    10.times{ result << nums.sample.to_s }
    result
  end
end
