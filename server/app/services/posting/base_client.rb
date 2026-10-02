module Posting
  class BaseClient
    def initialize(provider_account)
      @provider_account = provider_account
    end

    def post!(post, media_attachments: [], idempotency_key: nil)
      raise NotImplementedError
    end
  end
end
