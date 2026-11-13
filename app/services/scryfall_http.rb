module ScryfallHttp
  USER_AGENT = "SaninLegacy/1.0".freeze
  ACCEPT = "application/json;q=0.9,*/*;q=0.8".freeze
  API_TIMEOUT_SECONDS = 30

  def self.get(url)
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = API_TIMEOUT_SECONDS
    http.open_timeout = API_TIMEOUT_SECONDS

    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = USER_AGENT
    request["Accept"] = ACCEPT

    http.request(request)
  end
end
