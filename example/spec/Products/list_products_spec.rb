
require_relative "../../settings/general"

RSpec.describe Products, "#list_products" do
  before(:all) do
    @http = NiceHttp.new()
    @latitude = Helper.latitude(@http)
    @longitude = Helper.longitude(@http)
    @request = Products.list_products(@latitude, @longitude)
    @http.logger.info("\n#{"+" * 50} Before All ends #{"+" * 50}")
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
    resp = http.get(@request)
    expect(resp.code).to be_between("400", "499")
  end
  it "returns error if required parameter missing" do
    request = Products.list_products("", @longitude)
    resp = @http.get(request)
    expect(resp.code).to be_between("400", "499")

    request = Products.list_products(@latitude, "")
    resp = @http.get(request)
    expect(resp.code).to be_between("400", "499")
  end
end
