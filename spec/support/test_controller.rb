class TestErrorController < ApplicationController
  before_action :authenticate_user!

  def error
    raise RuntimeError, "boom"
  end
end
