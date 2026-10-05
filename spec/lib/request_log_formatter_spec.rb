require "rails_helper"

describe RequestLogFormatter do
  describe ".format" do
    it "returns a single-line JSON with all required fields" do
      time = Time.utc(2026, 10, 5, 1, 21, 0)
      result = described_class.format(
        time: time,
        request_id: "req-123",
        user_id: 42,
        method: "GET",
        path: "/events",
        controller: "EventsController",
        action: "index",
        status: 200,
        duration_ms: 12.34,
        params: { "page" => "2" }
      )

      expect(result).not_to include("\n")
      parsed = JSON.parse(result)
      expect(parsed).to have_key("time")
      expect(parsed).to have_key("request_id")
      expect(parsed).to have_key("user_id")
      expect(parsed).to have_key("method")
      expect(parsed).to have_key("path")
      expect(parsed).to have_key("controller")
      expect(parsed).to have_key("action")
      expect(parsed).to have_key("status")
      expect(parsed).to have_key("duration_ms")
      expect(parsed).to have_key("params")
      expect(parsed["time"]).to eq("2026-10-05T10:21:00.000+09:00")
      expect(parsed["request_id"]).to eq("req-123")
      expect(parsed["user_id"]).to eq(42)
      expect(parsed["method"]).to eq("GET")
      expect(parsed["path"]).to eq("/events")
      expect(parsed["controller"]).to eq("EventsController")
      expect(parsed["action"]).to eq("index")
      expect(parsed["status"]).to eq(200)
      expect(parsed["duration_ms"]).to eq(12.3)
      expect(parsed["params"]).to eq({ "page" => "2" })
    end

    it "filters password and token from params" do
      result = described_class.format(
        time: Time.current,
        request_id: "req-123",
        user_id: 1,
        method: "POST",
        path: "/login",
        controller: "SessionsController",
        action: "create",
        status: 200,
        duration_ms: 50.0,
        params: { "user" => { "password" => "secret123" }, "token" => "abc" }
      )

      parsed = JSON.parse(result)
      expect(parsed["params"]["user"]["password"]).to eq("[FILTERED]")
      expect(parsed["params"]["token"]).to eq("[FILTERED]")
      expect(result).not_to include("secret123")
      expect(result).not_to include("abc")
    end

    it "filters OAuth code, state, and oauth_verifier from params" do
      result = described_class.format(
        time: Time.current,
        request_id: "req-123",
        user_id: nil,
        method: "GET",
        path: "/auth/github/callback",
        controller: "AuthController",
        action: "callback",
        status: 302,
        duration_ms: 100.0,
        params: { "code" => "4/0AbCdEf", "state" => "xyz", "oauth_verifier" => "oauth_secret" }
      )

      parsed = JSON.parse(result)
      expect(parsed["params"]["code"]).to eq("[FILTERED]")
      expect(parsed["params"]["state"]).to eq("[FILTERED]")
      expect(parsed["params"]["oauth_verifier"]).to eq("[FILTERED]")
      expect(result).not_to include("4/0AbCdEf")
      expect(result).not_to include("xyz")
      expect(result).not_to include("oauth_secret")
    end

    it "does not filter unrelated keys containing 'code'" do
      result = described_class.format(
        time: Time.current,
        request_id: "req-123",
        user_id: 1,
        method: "GET",
        path: "/sets",
        controller: "SetsController",
        action: "index",
        status: 200,
        duration_ms: 50.0,
        params: { "scryfall_set_code" => "MH3" }
      )

      parsed = JSON.parse(result)
      expect(parsed["params"]["scryfall_set_code"]).to eq("MH3")
    end

    it "filters email from params" do
      result = described_class.format(
        time: Time.current,
        request_id: "req-123",
        user_id: 1,
        method: "POST",
        path: "/signup",
        controller: "UsersController",
        action: "create",
        status: 201,
        duration_ms: 75.0,
        params: { "email" => "foo@example.com" }
      )

      parsed = JSON.parse(result)
      expect(parsed["params"]["email"]).to eq("[FILTERED]")
      expect(result).not_to include("foo@example.com")
    end

    it "excludes controller and action from params" do
      result = described_class.format(
        time: Time.current,
        request_id: "req-123",
        user_id: 1,
        method: "GET",
        path: "/events",
        controller: "EventsController",
        action: "show",
        status: 200,
        duration_ms: 30.0,
        params: { "id" => "1", "controller" => "EventsController", "action" => "show" }
      )

      parsed = JSON.parse(result)
      expect(parsed["params"]).to have_key("id")
      expect(parsed["params"]).not_to have_key("controller")
      expect(parsed["params"]).not_to have_key("action")
    end

    it "rounds duration_ms to one decimal place" do
      result = described_class.format(
        time: Time.current,
        request_id: "req-123",
        user_id: 1,
        method: "GET",
        path: "/events",
        controller: "EventsController",
        action: "index",
        status: 200,
        duration_ms: 12.34567,
        params: {}
      )

      parsed = JSON.parse(result)
      expect(parsed["duration_ms"]).to eq(12.3)
    end

    it "handles nil duration_ms" do
      result = described_class.format(
        time: Time.current,
        request_id: "req-123",
        user_id: 1,
        method: "GET",
        path: "/events",
        controller: "EventsController",
        action: "index",
        status: 200,
        duration_ms: nil,
        params: {}
      )

      parsed = JSON.parse(result)
      expect(parsed["duration_ms"]).to be_nil
    end

    it "handles nil params" do
      result = described_class.format(
        time: Time.current,
        request_id: "req-123",
        user_id: 1,
        method: "GET",
        path: "/events",
        controller: "EventsController",
        action: "index",
        status: 200,
        duration_ms: 50.0,
        params: nil
      )

      parsed = JSON.parse(result)
      expect(parsed["params"]).to eq({})
    end
  end

  describe ".from_event" do
    it "extracts data from ActiveSupport Notifications event and formats it" do
      request_double = double("request", request_id: "req-456")
      payload = {
        request: request_double,
        user_id: 99,
        method: "POST",
        path: "/users",
        controller: "UsersController",
        action: "create",
        status: 201,
        params: { "name" => "John" }
      }
      event = ActiveSupport::Notifications::Event.new(
        "process_action.action_controller",
        Time.utc(2026, 10, 5, 2, 0, 0),
        Time.utc(2026, 10, 5, 2, 0, 0.125),
        "uuid",
        payload
      )

      result = described_class.from_event(event)
      parsed = JSON.parse(result)

      expect(parsed["request_id"]).to eq("req-456")
      expect(parsed["user_id"]).to eq(99)
      expect(parsed["method"]).to eq("POST")
      expect(parsed["path"]).to eq("/users")
      expect(parsed["controller"]).to eq("UsersController")
      expect(parsed["action"]).to eq("create")
      expect(parsed["status"]).to eq(201)
      expect(parsed["params"]).to eq({ "name" => "John" })
      expect(parsed).to have_key("duration_ms")
    end

    it "handles missing request object" do
      payload = {
        request: nil,
        user_id: 1,
        method: "GET",
        path: "/test",
        controller: "TestController",
        action: "index",
        status: 200,
        params: {}
      }
      event = ActiveSupport::Notifications::Event.new(
        "process_action.action_controller",
        Time.utc(2026, 10, 5, 2, 0, 0),
        Time.utc(2026, 10, 5, 2, 0, 0.1),
        "uuid",
        payload
      )

      result = described_class.from_event(event)
      parsed = JSON.parse(result)

      expect(parsed["request_id"]).to be_nil
      expect(parsed["user_id"]).to eq(1)
    end

    it "handles ActionController::Parameters for params" do
      request_double = double("request", request_id: "req-789")
      params = ActionController::Parameters.new(id: "123", name: "test")
      payload = {
        request: request_double,
        user_id: 1,
        method: "GET",
        path: "/items/123",
        controller: "ItemsController",
        action: "show",
        status: 200,
        params: params
      }
      event = ActiveSupport::Notifications::Event.new(
        "process_action.action_controller",
        Time.utc(2026, 10, 5, 2, 0, 0),
        Time.utc(2026, 10, 5, 2, 0, 0.1),
        "uuid",
        payload
      )

      result = described_class.from_event(event)
      parsed = JSON.parse(result)

      expect(parsed["params"]["id"]).to eq("123")
      expect(parsed["params"]["name"]).to eq("test")
    end
  end
end
