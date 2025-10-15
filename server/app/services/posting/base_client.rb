module Posting
  class BaseClient
    def initialize(provider_account)
      @provider_account = provider_account
    end

    def post!(post, media_attachments: [])
      raise NotImplementedError
    end
  end
end
