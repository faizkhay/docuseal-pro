# frozen_string_literal: true

RSpec.describe 'Newsletter' do
  let(:user) { create(:user, account: create(:account)) }
  let(:newsletter_url) { 'https://newsletter.example.com/subscribe' }

  before { sign_in(user) }

  context 'when a newsletter endpoint is configured' do
    before do
      stub_const('Docuseal::NEWSLETTER_URL', newsletter_url)
      stub_request(:post, newsletter_url).to_return(status: 200)

      visit newsletter_path
    end

    it 'shows the newsletter page' do
      expect(page).to have_content('Developer Newsletters')
      expect(page).to have_button('Submit')
      expect(page).to have_content('Skip')
      expect(page).to have_field('user[email]', with: user.email)
    end

    it 'submits the newsletter form' do
      click_button 'Submit'

      expect(a_request(:post, newsletter_url)).to have_been_made.once
    end

    it 'skips the newsletter form' do
      click_on 'Skip'

      expect(page).to have_current_path(root_path, ignore_query: true)
    end
  end

  # The default. Without a configured endpoint the address must not be sent
  # anywhere: it used to be posted to the upstream project's servers.
  context 'when no newsletter endpoint is configured' do
    before { visit newsletter_path }

    it 'still completes the form without posting the address anywhere' do
      click_button 'Submit'

      expect(page).to have_current_path(root_path, ignore_query: true)
      expect(WebMock).not_to have_requested(:post, /docuseal\.com/)
    end
  end
end
