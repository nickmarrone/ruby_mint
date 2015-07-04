require 'spec_helper'
require 'vcr'
require 'pry'

describe 'RubyMint' do

  let (:mint) { RubyMint.new('testuser@gmail.com', 'sekretpassword1') }

  before do
    VCR.insert_cassette("mintcom")
    # VCR.insert_cassette("mintcom", :record => :new_episodes)
  end

  after do
    VCR.eject_cassette
  end

  describe '#logged_in?' do
    describe 'when not logged in' do
      it { expect(mint.logged_in?).to eq(false) }
    end

    describe 'when logged in' do
      before { mint.login('fake token') }
      it { expect(mint.logged_in?).to eq(true) }
    end
  end

  it 'is unable to make calls when not logged in' do
    expect{ mint.accounts }.to raise_error(RubyMintError)
  end

  describe 'api calls' do
    before { mint.login }

    describe '#accounts' do
      let (:accounts) { mint.accounts }

      it 'has at least 1 account' do
        expect( accounts.count > 0 ).to eq(true)
      end

      it 'includes a bank account' do
        expect( accounts.map{|a| a['klass'] } ).to include('bank')
      end
    end

    describe '#transactions_csv' do
      let (:transactions) { mint.transactions_csv }

      it 'is a csv file' do
        expect( transactions.length > 0).to eq(true)
        expect(transactions).to include("\n")
        expect(transactions).to match(/(\".+\",\".+\")+/)
      end
    end

    describe '#transactions' do

      describe 'get all since June 1' do
        let (:transactions) { mint.transactions(Time.parse("2015-06-01"))}

        it 'has many transactions' do
          expect(transactions.count > 0).to eq(true)
        end

        it 'only has transactions on or after June 1' do
          start_date = Time.parse("2015-06-01")

          transactions.each do |t|
            expect(t['date']).to be >= start_date
          end
        end
      end

      describe 'with include_pending option' do
        describe 'turned on' do
          let (:transactions) { mint.transactions(Time.parse("2015-06-01"), Time.now, 'include_pending' => true)}

          it 'has at least 1 pending transaction' do
            expect(transactions.any?{ |t| t['isPending'] }).to eq(true)
          end
        end

        describe 'turned off' do
          let (:transactions) { mint.transactions(Time.parse("2015-06-01"), Time.now, 'include_pending' => false)}

          it 'has no pending transactions' do
            expect(transactions.any?{ |t| t['isPending'] }).to eq(false)
          end
        end
      end

      describe 'with a search_term' do
          let (:transactions) { mint.transactions(Time.parse("2015-06-01"), Time.now, 'search_term' => 'coffee')}

          it 'has a Starbucks transaction' do
            expect(transactions.any?{ |t| t['merchant'] == 'Starbucks' }).to eq(true)
          end

          it 'does not have an Amazon transaction' do
            expect(transactions.any?{ |t| t['merchant'] == 'Amazon' }).to eq(false)
          end
      end

      describe 'get those from June 1 to June 14' do
        let (:transactions) { mint.transactions(Time.parse("2015-06-01"), Time.parse("2015-06-14"))}

        it 'has many transactions' do
          expect(transactions.count > 0).to eq(true)
        end

        it 'only has transactions between June 1 and June 14' do
          start_date = Time.parse("2015-06-01")
          end_date = Time.parse("2015-06-14")

          transactions.each do |t|
            expect(t['date']).to be >= start_date
            expect(t['date']).to be <= end_date
          end
        end
      end
    end
  end
end
