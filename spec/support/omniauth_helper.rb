module OmniAuthHelper
  def mock_google_auth(uid: "123456789", email: "user@example.com", name: "Test User")
    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      provider: "google",
      uid: uid,
      info: {
        email: email,
        name: name,
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

  def mock_discord_auth(uid: "80351110224678912", email: "user@example.com", name: "testuser", global_name: "Test User")
    OmniAuth.config.mock_auth[:discord] = OmniAuth::AuthHash.new(
      provider: "discord",
      uid: uid,
      info: {
        email: email,
        name: name,
        image: "https://cdn.discordapp.com/avatars/x.png"
      },
      credentials: {
        token: "test_token",
        expires_at: 1.day.from_now.to_i
      },
      extra: {
        raw_info: {
          global_name: global_name
        }
      }
    )
  end

  def mock_discord_auth_with_nil_email(uid: "80351110224678912")
    OmniAuth.config.mock_auth[:discord] = OmniAuth::AuthHash.new(
      provider: "discord",
      uid: uid,
      info: {
        email: nil,
        name: "testuser",
        image: "https://cdn.discordapp.com/avatars/x.png"
      },
      credentials: {
        token: "test_token",
        expires_at: 1.day.from_now.to_i
      },
      extra: {
        raw_info: {
          global_name: "Test User"
        }
      }
    )
  end

  def clear_omniauth_mocks
    OmniAuth.config.mock_auth.clear
  end

  def start_signup_with_invitation
    invitation = create(:invitation)
    token = invitation.generate_signup_token
    get "/signup", params: { token: token }
    invitation
  end
end

RSpec.configure do |config|
  config.include OmniAuthHelper, type: :request
end
