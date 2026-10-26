# frozen_string_literal: true

# Parts of the core features examples can be skipped like so:
#   it_behaves_like "having working core features", skip_examples: %i[login likes]
#
# List of keywords for skipping examples:
# login, likes, profile, topics, topics:read, topics:reply, topics:create,
# search, search:quick_search, search:full_page
#
# For more details, see https://meta.discourse.org/t/-/361381
RSpec.describe "Core features", type: :system do
  before do
    # The theme uploads Splide's css and js assets.
    SiteSetting.theme_authorized_extensions =
      "wasm|jpg|jpeg|png|woff|woff2|svg|eot|ttf|otf|gif|webp|avif|js|css"
    upload_theme_or_component
  end

  it_behaves_like "having working core features",
                  skip_examples: %i[
                    login
                    likes
                    profile
                    topics
                    topics:read
                    topics:reply
                    topics:create
                    search
                    search:quick_search
                    search:full_page
                  ]
end
