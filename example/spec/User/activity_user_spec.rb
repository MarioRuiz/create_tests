
require_relative "../../settings/general"

RSpec.describe User, "#activity_user" do
  before do |example|
    # create connection on default host and store the logs on the_name_of_file.rb.log
    @http = NiceHttp.new({log: "#{__FILE__}.log"})
    @http.logger.info("\n\n#{"=" * 100}\nTest: #{example.description}\n#{"-" * 100}")

    @request = User.activity_user()
  end
  it "has correct structure in succesful response" do
    resp = @http.get(@request)
    expect(resp.code).to eq 200
    expect(NiceHash.compare_structure(@request.responses._200.data, resp.data.json, true)).to be true
  end
  it 'doesn\'t retrieve data if not authenticated' do
    @http.headers = {}
    resp = @http.get(@request)
    expect(resp.code).to be_between("400", "499")
  end
end
