require_relative "../../settings/general"
if defined?(User) and defined?(User.profile_user)
  RSpec.describe User, "#profile_user" do
    before(:all) do
      @http = NiceHttp.new()
      @request = User.profile_user()
      @http.logger.info("\n#{"+" * 50} Before All ends #{"+" * 50}")
    end
    before(:each) do |example|
      @http.logger.info("\n\n#{"=" * 100}\nTest: #{example.description}\n#{"-" * 100}")
    end

    it "has correct structure in successful response" do
      resp = @http.get(@request)
      expect(resp.code).to eq 200
      result = NiceHttp.validate_response(resp, @request.responses._200.data, include_diff: true)
      expect(result[:ok]).to be(true), "Structure mismatch: #{result[:diff]}"
    end
    it 'doesn\'t retrieve data if not authenticated' do
      http = NiceHttp.new()
      http.headers = {}
      resp = http.get(@request)
      expect(resp.code).to be_between("400", "499")
    end
  end
end
