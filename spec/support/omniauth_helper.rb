module OmniAuthHelper
  def mock_google_auth(uid: "123456789", email: "user@example.com")
    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      provider: "google",
      uid: uid,
      info: {
        email: email,
        name: "Test User",
        image: "https://example.com/photo.jpg"
      },
      credentials: {
        token: "test_token",
        expires_at: 1.day.from_now.to_i
      }
    )
  end

  def mock_google_auth_with_nil_email(uid: "123456789")
    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      provider: "google",
      uid: uid,
      info: {
        email: nil,
        name: "Test User",
        image: "https://example.com/photo.jpg"
      },
      credentials: {
        token: "test_token",
        expires_at: 1.day.from_now.to_i
      }
    )
  end

  def mock_twitter_auth(uid: "987654321012345678", email: "user@example.com")
    OmniAuth.config.mock_auth[:twitter] = OmniAuth::AuthHash.new(
      provider: "twitter",
      uid: uid,
      info: {
        email: email,
        name: "Test User",
        nickname: "testuser"
      },
      credentials: {
        token: "test_token",
        secret: "test_secret",
        expires_at: 1.day.from_now.to_i
      }
    )
  end

  def mock_twitter_auth_with_nil_email(uid: "987654321012345678")
    OmniAuth.config.mock_auth[:twitter] = OmniAuth::AuthHash.new(
      provider: "twitter",
      uid: uid,
      info: {
        email: nil,
        name: "Test User",
        nickname: "testuser"
      },
      credentials: {
        token: "test_token",
        secret: "test_secret",
        expires_at: 1.day.from_now.to_i
      }
    )
  end

  def clear_omniauth_mocks
    OmniAuth.config.mock_auth.clear
  end
end

RSpec.configure do |config|
  config.include OmniAuthHelper, type: :request
end
