require "rails_helper"

RSpec.describe "Users::Profiles", type: :request do
  let(:user) { create(:user, username: "testuser", email: "test@example.com", password: "password123") }

  before do
    I18n.locale = :ja
  end

  after do
    I18n.locale = :en
  end

  describe "GET /mypage (show)" do
    context "when user is not logged in" do
      it "redirects to signin path" do
        get "/mypage"
        expect(response).to redirect_to(signin_path)
      end
    end

    context "when user is logged in" do
      before do
        post signin_path, params: { email: user.email, password: "password123" }
      end

      it "returns 200 OK" do
        get "/mypage"
        expect(response).to have_http_status(:ok)
      end

      it "displays user's username" do
        get "/mypage"
        expect(response.body).to include(user.username)
      end

      it "displays user's email" do
        get "/mypage"
        expect(response.body).to include(user.email)
      end

      it "displays user's registration date in Japanese format" do
        get "/mypage"
        expect(response.body).to include(user.created_at.strftime("%Y年%m月%d日"))
      end

      it "displays user's role" do
        get "/mypage"
        expect(response.body).to include("一般ユーザー")
      end

      it "displays edit link" do
        get "/mypage"
        expect(response.body).to include(edit_mypage_path)
      end

      context "when user has no email" do
        before do
          user.update(email: nil)
        end

        it "displays '未設定' for email" do
          get "/mypage"
          expect(response.body).to include("未設定")
        end
      end

      context "when user is admin" do
        before do
          user.update(role: :admin)
        end

        it "displays admin role" do
          get "/mypage"
          expect(response.body).to include("管理者")
        end
      end

      context "when user has Twitter identity" do
        let(:twitter_identity) { create(:twitter_identity, user: user, uid: "123456789") }

        before do
          twitter_identity
        end

        it "displays Twitter(X) account link" do
          get "/mypage"
          expect(response.body).to include("https://twitter.com/intent/user?user_id=123456789")
        end

        it "displays 'アカウントを表示' link text" do
          get "/mypage"
          expect(response.body).to include("アカウントを表示")
        end
      end

      context "when user has Google identity" do
        let(:google_identity) { create(:google_identity, user: user) }

        before do
          google_identity
        end

        it "displays Google" do
          get "/mypage"
          expect(response.body).to include("Google")
        end
      end

      context "when user has multiple identities" do
        let(:twitter_identity) { create(:twitter_identity, user: user, uid: "123456789") }
        let(:google_identity) { create(:google_identity, user: user) }

        before do
          twitter_identity
          google_identity
        end

        it "displays both identities" do
          get "/mypage"
          expect(response.body).to include("Google")
          expect(response.body).to include("Twitter(X)")
        end
      end
    end
  end

  describe "GET /mypage/edit (edit)" do
    context "when user is not logged in" do
      it "redirects to signin path" do
        get "/mypage/edit"
        expect(response).to redirect_to(signin_path)
      end
    end

    context "when user is logged in" do
      before do
        post signin_path, params: { email: user.email, password: "password123" }
      end

      it "returns 200 OK" do
        get "/mypage/edit"
        expect(response).to have_http_status(:ok)
      end

      it "displays edit form" do
        get "/mypage/edit"
        expect(response.body).to include('type="text"')
        expect(response.body).to include('type="email"')
        expect(response.body).to include('type="password"')
      end

      it "has username field populated with current username" do
        get "/mypage/edit"
        expect(response.body).to include('value="testuser"')
      end

      it "has email field populated with current email" do
        get "/mypage/edit"
        expect(response.body).to include('value="test@example.com"')
      end

      it "displays cancel link" do
        get "/mypage/edit"
        expect(response.body).to include("/mypage")
      end
    end
  end

  describe "PATCH /mypage (update)" do
    context "when user is not logged in" do
      it "redirects to signin path" do
        patch "/mypage", params: { user: { username: "newname" } }
        expect(response).to redirect_to(signin_path)
      end
    end

    context "when user is logged in" do
      before do
        post signin_path, params: { email: user.email, password: "password123" }
      end

      context "with valid parameters" do
        it "updates username successfully" do
          patch "/mypage", params: { user: { username: "newusername" } }
          expect(user.reload.username).to eq("newusername")
        end

        it "updates email successfully" do
          patch "/mypage", params: { user: { username: user.username, email: "newemail@example.com" } }
          expect(user.reload.email).to eq("newemail@example.com")
        end

        it "redirects to mypage path" do
          patch "/mypage", params: { user: { username: user.username } }
          expect(response).to redirect_to("/mypage")
        end

        it "displays success notice" do
          patch "/mypage", params: { user: { username: user.username } }
          follow_redirect!
          expect(response.body).to include("プロフィールが更新されました")
        end

        context "updating password" do
          context "with valid current_password" do
            it "updates password successfully" do
              patch "/mypage", params: {
                user: {
                  username: user.username,
                  current_password: "password123",
                  password: "newpassword123",
                  password_confirmation: "newpassword123"
                }
              }
              expect(user.reload.authenticate("newpassword123")).to be_truthy
            end

            it "redirects to mypage after password update" do
              patch "/mypage", params: {
                user: {
                  username: user.username,
                  current_password: "password123",
                  password: "newpassword123",
                  password_confirmation: "newpassword123"
                }
              }
              expect(response).to redirect_to("/mypage")
            end
          end

          context "with incorrect current_password" do
            it "does not update password" do
              original_password_digest = user.password_digest
              patch "/mypage", params: {
                user: {
                  username: user.username,
                  current_password: "wrongpassword",
                  password: "newpassword123",
                  password_confirmation: "newpassword123"
                }
              }
              expect(user.reload.password_digest).to eq(original_password_digest)
            end

            it "returns unprocessable_entity status" do
              patch "/mypage", params: {
                user: {
                  username: user.username,
                  current_password: "wrongpassword",
                  password: "newpassword123",
                  password_confirmation: "newpassword123"
                }
              }
              expect(response).to have_http_status(:unprocessable_entity)
            end

            it "displays error message about current_password" do
              patch "/mypage", params: {
                user: {
                  username: user.username,
                  current_password: "wrongpassword",
                  password: "newpassword123",
                  password_confirmation: "newpassword123"
                }
              }
              expect(response.body).to include("現在のパスワード")
              expect(response.body).to include("正しくありません")
            end
          end

          context "with blank current_password" do
            it "does not update password" do
              original_password_digest = user.password_digest
              patch "/mypage", params: {
                user: {
                  username: user.username,
                  current_password: "",
                  password: "newpassword123",
                  password_confirmation: "newpassword123"
                }
              }
              expect(user.reload.password_digest).to eq(original_password_digest)
            end

            it "returns unprocessable_entity status" do
              patch "/mypage", params: {
                user: {
                  username: user.username,
                  current_password: "",
                  password: "newpassword123",
                  password_confirmation: "newpassword123"
                }
              }
              expect(response).to have_http_status(:unprocessable_entity)
            end

            it "displays error message about current_password" do
              patch "/mypage", params: {
                user: {
                  username: user.username,
                  current_password: "",
                  password: "newpassword123",
                  password_confirmation: "newpassword123"
                }
              }
              expect(response.body).to include("現在のパスワード")
            end
          end

          context "without password change (username/email only)" do
            it "updates without requiring current_password" do
              patch "/mypage", params: {
                user: {
                  username: "newusername"
                }
              }
              expect(user.reload.username).to eq("newusername")
            end

            it "does not require current_password validation" do
              patch "/mypage", params: {
                user: {
                  username: "newusername",
                  email: "newemail@example.com"
                }
              }
              expect(response).to redirect_to("/mypage")
            end
          end
        end
      end

      context "with invalid parameters" do
        context "invalid username (too short)" do
          it "does not update username" do
            patch "/mypage", params: { user: { username: "ab" } }
            expect(user.reload.username).to eq("testuser")
          end

          it "returns unprocessable_entity status" do
            patch "/mypage", params: { user: { username: "ab" } }
            expect(response).to have_http_status(:unprocessable_entity)
          end

          it "displays error message" do
            patch "/mypage", params: { user: { username: "ab" } }
            expect(response.body).to include("エラーがあります")
          end
        end

        context "invalid email (duplicate)" do
          let(:other_user) { create(:user, email: "other@example.com") }

          before do
            other_user
          end

          it "does not update email" do
            patch "/mypage", params: {
              user: {
                username: user.username,
                email: "other@example.com"
              }
            }
            expect(user.reload.email).to eq("test@example.com")
          end

          it "returns unprocessable_entity status" do
            patch "/mypage", params: {
              user: {
                username: user.username,
                email: "other@example.com"
              }
            }
            expect(response).to have_http_status(:unprocessable_entity)
          end
        end

        context "password mismatch" do
          it "does not update user when password and confirmation do not match" do
            original_password_digest = user.password_digest
            patch "/mypage", params: {
              user: {
                username: user.username,
                password: "newpassword123",
                password_confirmation: "differentpassword"
              }
            }
            # Either password was not updated or user was not updated at all
            expect(user.reload.password_digest).to eq(original_password_digest)
          end

          it "returns unprocessable_entity status when password confirmation does not match" do
            patch "/mypage", params: {
              user: {
                username: user.username,
                password: "newpassword123",
                password_confirmation: "differentpassword"
              }
            }
            expect(response).to have_http_status(:unprocessable_entity)
          end
        end

        context "password too short" do
          it "does not update password" do
            patch "/mypage", params: {
              user: {
                username: user.username,
                password: "short",
                password_confirmation: "short"
              }
            }
            expect(user.reload.authenticate("password123")).to be_truthy
          end

          it "returns unprocessable_entity status" do
            patch "/mypage", params: {
              user: {
                username: user.username,
                password: "short",
                password_confirmation: "short"
              }
            }
            expect(response).to have_http_status(:unprocessable_entity)
          end
        end
      end

      context "clearing email" do
        it "allows email to be cleared" do
          patch "/mypage", params: {
            user: {
              username: user.username,
              email: ""
            }
          }
          expect(user.reload.email).to be_nil
        end
      end
    end
  end
end
