
require_relative "../../settings/general"

RSpec.describe Estimates, "#time_estimates" do
  before(:all) do
    @http = NiceHttp.new()
    @start_latitude = Helper.start_latitude(@http)
    @start_longitude = Helper.start_longitude(@http)
    @request = Estimates.time_estimates(@start_latitude, @start_longitude)
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
    http.headers = {}
    resp = @http.get(@request)
    expect(resp.code).to be_between("400", "499")
  end
  it "returns error if required parameter missing" do
    request = Estimates.time_estimates("", @start_longitude)
    resp = @http.get(request)
    expect(resp.code).to be_between("400", "499")

    request = Estimates.time_estimates(@start_latitude, "")
    resp = @http.get(request)
    expect(resp.code).to be_between("400", "499")
  end
end
