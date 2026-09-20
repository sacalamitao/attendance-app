# Parses the *current* response body. Deliberately not a memoized `let`, so an
# example that makes several requests sees each response in turn.
module JsonResponse
  def json
    JSON.parse(response.body)
  end
end

RSpec.configure do |config|
  config.include JsonResponse, type: :request
end
