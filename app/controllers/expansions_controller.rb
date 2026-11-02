class ExpansionsController < ApplicationController
  before_action :authenticate_user!

  def index
    @query = params[:q].to_s.strip
    @expansions = Expansion.search_by_code(@query)
    # 1 画面に複数のサジェスト枠があるとき（代理通販の明細編集）、呼び出し側の turbo-frame id に返す
    @frame_id = params[:frame].presence || "expansion_suggestions"
    render :index, layout: false
  end
end
