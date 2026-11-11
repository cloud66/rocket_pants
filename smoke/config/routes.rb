# loaded by rails itself, so rails 8 draws these lazily on first use, as it does central's.
Rails.application.routes.draw do
  api :versions => [1, 2], :module => "smoke" do
    get "widgets/single",        :to => "widgets#single", :as => :single_widget
    get "widgets/list",          :to => "widgets#list"
    get "widgets/paged",         :to => "widgets#paged"
    get "widgets/with_metadata", :to => "widgets#with_metadata"
    get "widgets/missing",       :to => "widgets#missing"
    get "widgets/expired",       :to => "widgets#expired"
    get "widgets/boom",          :to => "widgets#boom"
    get "widgets/needs_param",   :to => "widgets#needs_param"
    get "widgets/nothing",       :to => "widgets#nothing"
    get "widgets/link",          :to => "widgets#link"
    get "widgets/request_id",    :to => "widgets#request_id"
    get "widgets/away",          :to => "widgets#away"
    get "widgets/secret",        :to => "widgets#secret"

    get "central/missing", :to => "central_style#missing"
    get "central/expired", :to => "central_style#expired"
  end
end
