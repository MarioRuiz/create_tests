
require_relative "../../settings/general"

RSpec.describe Estimates, "#price_estimates" do
  before(:all) do
    # create connection on default host and store the logs on the_name_of_file.rb.log
    @http = NiceHttp.new({log: "#{__FILE__}.log"})
    @start_latitude = Helper.start_latitude(@http)
    @start_longitude = Helper.start_longitude(@http)
    @end_latitude = Helper.end_latitude(@http)
    @end_longitude = Helper.end_longitude(@http)
    @request = Estimates.price_estimates(@start_latitude, @start_longitude, @end_latitude, @end_longitude)
  end
  before(:each) do |example|
    @http.logger.info("\n\n#{"=" * 100}\nTest: #{example.description}\n#{"-" * 100}")
  end
  it "has correct structure in succesful response" do
    resp = @http.get(@request)
    expect(resp.code).to eq 200
    expect(NiceHash.compare_structure(@request.responses._200.data, resp.data.json, true)).to be true
  end
  it 'doesn\'t retrieve data if not authenticated' do
    http = NiceHttp.new()
    http.logger = @http.logger
    http.headers = {}
    resp = @http.get(@request)
    expect(resp.code).to be_between("400", "499")
  end
  it "returns error if required parameter missing" do
    request = Estimates.price_estimates("", @start_longitude, @end_latitude, @end_longitude)
    resp = @http.get(request)
    expect(resp.code).to be_between("400", "499")

    request = Estimates.price_estimates(@start_latitude, "", @end_latitude, @end_longitude)
    resp = @http.get(request)
    expect(resp.code).to be_between("400", "499")

    request = Estimates.price_estimates(@start_latitude, @start_longitude, "", @end_longitude)
    resp = @http.get(request)
    expect(resp.code).to be_between("400", "499")

    request = Estimates.price_estimates(@start_latitude, @start_longitude, @end_latitude, "")
    resp = @http.get(request)
    expect(resp.code).to be_between("400", "499")
  end
end
