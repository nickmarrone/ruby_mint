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
  def initiate_account_refresh(sleep_time = 3, &block)
    agent.post("https://wwws.mint.com/refreshFILogins.xevent", { "token" => @token }, JSON_HEADERS)
    if block
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
  def transactions
    results = agent.get("https://wwws.mint.com/transactionDownload.event", JSON_HEADERS)
    raise RubyMintError.new("Unable to obtain transations.") if results.code != "200"
    raise RubyMintError.new("Non-CSV content returned.") if !results.header["content-type"].include?("text/csv")

    results.body
  end


  private

  def agent
    @agent ||= Mechanize.new { |agent|
        agent.user_agent_alias = 'Linux Firefox'
    }
  end
end
